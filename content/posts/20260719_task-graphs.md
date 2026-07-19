---
title: "Sketching a Task Graph in Fortran"
date: 2026-07-19
draft: true
tags: ["Fortran", "OpenMP", "parallelism"]
katex: true
---

Frameworks like [Intel oneTBB](https://uxlfoundation.github.io/oneTBB/) (flow
graph), [CUDA Graphs](https://developer.nvidia.com/blog/cuda-graphs/), and
[Taskflow](https://taskflow.github.io/) all revolve around the same idea: you
describe a computation as a *graph of actions* up front — launch this kernel,
then do this halo exchange, then that kernel — and hand the whole thing to a
runtime that walks it, possibly asynchronously, possibly many times.

For the codes I care about the motivating example is a time-stepping loop with
halo exchanges, e.g. an FDTD solver:

```text
update H → exchange H halos → update E → exchange E halos → (repeat)
```

Today the loop body is usually written as straight-line calls. But the moment
you want to overlap the E-field work with the H-field communication, or replay
the same sequence every time step without re-deciding anything, an explicit
task graph starts to look attractive. C++ programmers have TBB; for Fortran
there is next to no material on what works and what doesn't. So this post is an
exploration, not a recipe: I'll build the simplest thing that could work, poke
at it until it breaks, and try a few alternatives. All experiments were run
with gfortran 13.3 on Linux.

## Attempt 1: a chain with value semantics

The simplest task graph is a linked list of nodes, each carrying a procedure
pointer to the action it performs:

```fortran
module chain_mod
implicit none
public
abstract interface
    subroutine eval(data)
        class(*), intent(inout), optional :: data
    end subroutine
end interface
type :: chain_node
    procedure(eval), pointer, nopass :: f
    class(*), pointer :: data => null()
    type(chain_node), allocatable :: next
end type

contains
    recursive subroutine launch(node)
        type(chain_node), intent(inout) :: node
        if (associated(node%f)) call node%f(node%data)
        if (allocated(node%next)) call launch(node%next)
    end subroutine

    recursive function populate(nodes) result(chain)
        type(chain_node), intent(in) :: nodes(:)
        type(chain_node) :: chain
        chain = nodes(1)
        if (size(nodes) > 1) then
            chain%next = populate(nodes(2:))
        end if
    end function

end module
```

The interesting choice here is `type(chain_node), allocatable :: next` — a
*recursive allocatable component*. Because `next` is allocatable rather than a
pointer, the whole chain behaves like a value: assignment deep-copies it,
and when a chain goes out of scope the compiler tears the entire thing down
for us. No `target` attributes, no ownership questions, no leaks.

It also allows a construction style I find genuinely pretty. Since a structure
constructor can take another structure constructor as the value for `next`,
the whole pipeline can be written as one nested literal:

```fortran
program demo
use chain_mod, node => chain_node
implicit none

type(node) :: graph

graph = node(f=update_h,next=&
       node(f=mpi_exchange_h,next=&
       node(f=update_e,next=&
       node(f=mpi_exchange_e))))

call launch(graph)

graph = populate([[node(update_h), node(mpi_exchange_h)], &
                 [node(update_e), node(mpi_exchange_e)]])
write(*,*)
call launch(graph)

contains

    subroutine update_h(data)
        class(*), intent(inout), optional :: data
        print *, "update h"
    end subroutine

    ! ... mpi_exchange_h, update_e, mpi_exchange_e analogous ...

end program
```

The `populate` variant builds the same chain from a flat array of nodes, which
composes nicely: `[[chain a], [chain b]]` concatenates two sub-pipelines. Both
variants compile and print the expected sequence with gfortran 13.3:

```text
 update h
 mpi exchange h
 update e
 mpi exchange e
```

So far so good. Now the poking.

### Portability: this is a Fortran 2008 feature

Recursive *pointer* components have been legal since Fortran 90 — they are how
linked lists were always written. Recursive *allocatable* components only
arrived in Fortran 2008, and compiler support lagged badly. gfortran in
particular rejected or miscompiled patterns like this one for years; the
feature only became usable in relatively recent releases. If you need to
support older compilers, this design is off the table from the start —
which is presumably why you almost never see it in the wild.

### Cost: value semantics means copies, everywhere

Every one of those pretty constructors is an *expression*, and its value gets
deep-copied into the enclosing constructor, then copied again on assignment to
`graph`. The `populate` function is worse: at each recursion level,
`chain%next = populate(nodes(2:))` deep-copies the entire remaining tail, so
building an $n$-node chain does $\mathcal{O}(n^2)$ node copies. For a
four-node demo, who cares. For a graph rebuilt every time step, this is real
overhead — and each copy also shallow-copies the `data` pointer, which is a
quiet aliasing decision you may not have intended to make.

### The stack bomb hiding in `deallocate`

The recursive `launch` is easy to rewrite as a loop. What you *cannot* easily
rewrite is the destruction of the chain. When `graph` is deallocated — or
merely *reassigned*, since intrinsic assignment first tears down the old value
— the compiler must free `next`, which frees `next%next`, and so on. gfortran
implements this with a compiler-generated recursive helper. Watch what happens
with a chain of $10^5$ do-nothing nodes and the default 8 MiB stack:

```text
$ ./deep
Segmentation fault (core dumped)
```

A backtrace shows tens of thousands of frames of the same generated procedure
before the crash, called from the line containing `deallocate(head)`:

```text
#74815 0x00005555555552ad in chain_mod::__deallocate_chain_mod_Chain_node (...)
#74816 0x00005555555552ad in chain_mod::__deallocate_chain_mod_Chain_node (...)
#74817 0x0000555555555b39 in deep () at deep.f90:40
```

In my experiments the crash appears somewhere between $10^4$ nodes (fine) and
$10^5$ nodes (segfault). A task graph for a real solver won't have $10^5$
nodes in a single chain — but a *queue* that nodes keep appending to (see
below) very well might, and "your program crashes inside compiler-generated
cleanup code" is a miserable failure mode to debug. There is no standard
knob to control this; the recursion is an implementation detail of the
compiler.

So attempt 1 is a lovely notation resting on a fragile foundation: late-
arriving compiler support, hidden quadratic copies, and destruction that can
blow the stack. Time to try the boring alternative.

## Attempt 2: pointers and an owning queue

The classic Fortran 90 answer is pointer components. Pointers give up value
semantics — and that's mostly a *relief* here, because a task graph is exactly
the kind of object you don't want silently deep-copied. The price is that
somebody must own the nodes and free them. So let's make the ownership
explicit with a queue type:

```fortran
type :: task_node
    procedure(eval), pointer, nopass :: f => null()
    class(*), pointer :: data => null()
    type(task_node), pointer :: next => null()
end type

type :: task_queue
    type(task_node), pointer :: head => null()
    type(task_node), pointer :: tail => null()
contains
    procedure :: enqueue
    procedure :: launch
    procedure :: clear
    final :: finalize
end type
```

Construction is no longer a nested literal but an imperative sequence — less
cute, but it reads fine and it's $\mathcal{O}(1)$ per node with zero copies:

```fortran
call q%enqueue(update_h)
call q%enqueue(mpi_exchange_h)
call q%enqueue(update_e)
call q%enqueue(mpi_exchange_e)
call q%launch()
```

`launch` and `clear` are plain loops, so the stack bomb is gone by
construction:

```fortran
subroutine launch(self)
    class(task_queue), intent(inout) :: self
    type(task_node), pointer :: p
    p => self%head
    do while (associated(p))
        if (associated(p%f)) call p%f(p%data)
        p => p%next   ! a task may have appended nodes; we will see them
    end do
end subroutine

subroutine clear(self)
    class(task_queue), intent(inout) :: self
    type(task_node), pointer :: p, dead
    p => self%head
    do while (associated(p))
        dead => p
        p => p%next
        deallocate(dead)
    end do
    nullify(self%head, self%tail)
end subroutine
```

A `final` procedure that calls `clear` gives back most of the automatic
cleanup we lost. What we can't get back is copy safety: if someone assigns one
`task_queue` to another, both copies point at the same nodes and `clear`-ing
both is a double free. (An `assignment(=)` binding that either deep-copies or
poisons the copy would close that hole; I've left it out of the sketch.)

My tentative conclusion: **pointers to heap nodes, wrapped in an owning
container, are the right substrate** for this kind of structure in today's
Fortran. The allocatable-component version is the more elegant abstraction,
but the elegance lives at exactly the layer — copying and destruction — where
its costs and fragility live too.

## Dispatch: procedure pointers, integer tags, or `select type`?

So far every node holds a bare procedure pointer, and the runtime treats all
nodes identically. A real graph runtime wants to *distinguish* kinds of nodes
— a kernel launch is retried differently than an MPI exchange, a barrier node
has no action at all, and an accelerator runtime might map node kinds onto
different streams. I see three ways to encode the kind:

1. **Procedure pointer only** (what we have). The runtime is maximally dumb;
   all policy lives in the user procedures. Simple, but the runtime can't make
   scheduling decisions because it can't tell nodes apart.
2. **An integer tag** on the node plus a `select case` in the runtime. Fast
   and simple, and tags travel well through C interop or OpenMP clauses. But
   nothing stops a tag/payload mismatch, and every new node kind means
   touching the central `select case`.
3. **A type hierarchy** with `select type` dispatch. Each node kind is an
   extended type carrying exactly the payload it needs, and the compiler
   checks the payload/kind association for us.

Option 3 is the most Fortran-y, so let's sketch it. One wrinkle: if nodes are
polymorphic (`class(node)`), the links between them need somewhere
non-polymorphic to live. A small box type does the trick:

```fortran
type, abstract :: node
    type(node_box), pointer :: next => null()
    integer :: stream = 1     ! nodes in the same stream run in order
end type

type :: node_box
    class(node), allocatable :: item
end type

type, extends(node) :: kernel_node
    procedure(eval), pointer, nopass :: f => null()
    class(*), pointer :: data => null()
end type

type, extends(node) :: halo_node
    ! could carry MPI requests, neighbour ranks, buffers, ...
    procedure(eval), pointer, nopass :: f => null()
    class(*), pointer :: data => null()
end type
```

and the runtime dispatches on the concrete type:

```fortran
subroutine dispatch(n)
    class(node), intent(inout) :: n
    select type (n)
    type is (kernel_node)
        if (associated(n%f)) call n%f(n%data)
    type is (halo_node)
        ! post receives, wait on requests, ...
        if (associated(n%f)) call n%f(n%data)
    class default
        error stop "unknown node type"
    end select
end subroutine
```

An OO purist would replace `select type` with a deferred type-bound `run`
procedure, and for user-extensible node kinds that is clearly better — a
`select type` in the runtime can only name types the runtime knows about.
But for a *closed* set of node kinds the central `select type` has a virtue
the textbooks undersell: the whole scheduling policy is in one place where
you can read it, instead of smeared across type-bound procedures in five
modules. It's the same trade-off as tags, with compiler-checked payloads.

## Launching asynchronously with OpenMP tasks

Here is where the node metadata starts to pay off. Give each node a `stream`
number — nodes in the same stream must run in order, different streams are
independent — and the launch loop can spawn one OpenMP task per node, using
`depend` on a per-stream sentinel to serialize within a stream:

```fortran
subroutine run_tasks(g)
    type(graph), intent(inout) :: g
    type(node_box), pointer :: p
    integer, target :: streams(8)   ! dependency sentinels, one per stream
    !$omp parallel
    !$omp single
    p => g%head
    do while (associated(p))
        block
            type(node_box), pointer :: cur
            integer :: s
            cur => p
            s = cur%item%stream
            !$omp task depend(inout: streams(s)) firstprivate(cur)
            call dispatch(cur%item)
            !$omp end task
        end block
        p => p%item%next
    end do
    !$omp end single
    !$omp end parallel
end subroutine
```

The `streams` array holds no data; its elements exist purely so their
*addresses* can serve as dependency tags — OpenMP `depend` clauses match on
storage location. Putting the H-update chain in stream 1 and the E-update
chain in stream 2 and running twice with four threads:

```text
 -- tasks --            -- tasks --
 update h               update h
 mpi exchange h         update e
 update e               mpi exchange e
 mpi exchange e         mpi exchange h
```

The second run shows genuine overlap: the E-stream ran ahead of the H-halo
exchange, while order *within* each stream was preserved. That is precisely
the communication/computation overlap we wanted, and we got it without
touching the node actions — only the launcher changed. (In a real code the
depend clauses would express cross-stream edges too — `update_e` typically
*does* depend on `exchange_h` — which is exactly what `depend(in:
streams(1))` on the E-tasks would encode. The plumbing is already there.)

Two caveats worth recording. First, OpenMP task dependencies only order
*sibling* tasks created in the same task region, so the whole graph must be
spawned from one `single` region as above. Second, if a task action blocks
inside `MPI_Wait`, that OpenMP thread is gone for the duration — doing this
properly needs `MPI_THREAD_MULTIPLE`, nonblocking waits with `taskyield`, or
OpenMP detached tasks. That is a whole follow-up post.

## Nodes that enqueue nodes

The pointer-based queue has one more trick. Because `launch` just follows
`next` pointers until it runs out, a node's action may *append to the very
queue being drained* — the loop will pick the new nodes up. That turns the
time loop itself into a task: seed the queue with one `next_step` node whose
action enqueues the step's work and then re-enqueues itself.

To do that, the action needs access to the queue and the step counter, which
is what the `class(*), pointer :: data` payload is for:

```fortran
type :: sim_state
    type(task_queue) :: q
    integer :: step = 0
    integer :: nsteps = 3
end type
```

```fortran
subroutine next_step(data)
    class(*), intent(inout), optional :: data
    select type (data)
    type is (sim_state)
        data%step = data%step + 1
        if (data%step > data%nsteps) return
        print '(a,i0)', "scheduling step ", data%step
        block
            class(*), pointer :: ctx
            ctx => data
            call data%q%enqueue(update_h, ctx)
            call data%q%enqueue(mpi_exchange_h, ctx)
            call data%q%enqueue(update_e, ctx)
            call data%q%enqueue(mpi_exchange_e, ctx)
            call data%q%enqueue(next_step, ctx)   ! the loop closes here
        end block
    end select
end subroutine
```

Seeding and draining:

```fortran
type(sim_state), target :: sim
class(*), pointer :: ctx

ctx => sim
call sim%q%enqueue(next_step, ctx)
call sim%q%launch()
```

```text
scheduling step 1
   update h
   mpi exchange h
   update e
   mpi exchange e
scheduling step 2
   ...
scheduling step 3
   ...
```

This works, and it's the point where the design stops being a static pipeline
and becomes a small runtime: nodes are continuations, and the queue is an
event loop. It is also the point where the earlier engineering choices bite
or don't: with this queue, three time steps leave $3 \times 5$ dead nodes on
the list until `clear` — with attempt 1's allocatable chain, a long run would
have marched straight into the recursive-deallocation stack bomb. (gfortran
issues a spurious warning that `next_step` "is possibly calling itself
recursively" — it never calls itself, it only takes its own address; since
Fortran 2018 procedures are recursive by default anyway.)

TBB users will recognize all of this: `flow::graph` nodes hold callables, a
node can spawn work, and the runtime drains a work queue. What Fortran lacks
is not the language machinery — procedure pointers, unlimited polymorphics,
type extension, and OpenMP tasks got us surprisingly far — but the ecosystem:
there is no battle-tested library, and barely any written record of which
patterns survive contact with real compilers.

## Where this could go

Open threads I'd like to pull on, in roughly increasing order of ambition:

- **True DAGs, not chains.** A node with *multiple* successors and a
  predecessor count, drained with a ready-queue (Kahn's algorithm), would be
  a modest extension of the pointer design. The OpenMP `depend`-sentinel
  trick already handles DAG edges if you assign sentinels per *edge* rather
  than per stream.
- **Graph replay.** CUDA-graph-style: build once, `launch` every time step
  with zero per-step allocation. The queue version is close; it mainly needs
  a non-destructive iteration mode and reusable state in the nodes.
- **Detached tasks for MPI.** OpenMP 5.0 `detach` clauses plus
  `MPI_Request`-polling would let halo-exchange nodes complete without
  parking a thread.
- **Compiler coverage.** Everything here is gfortran 13.3. I'd like to table
  the same experiments for ifx and flang — especially the recursive
  allocatable teardown, where implementations are free to differ.

If you have tried something similar — or know of prior art for task graphs in
Fortran beyond hand-rolled event loops — I would genuinely like to hear about
it.

## Appendix: reproducing the stack overflow

```fortran
program deep
use chain_mod   ! chain_node with allocatable next, as in attempt 1
implicit none
type(chain_node), allocatable, target :: head
type(chain_node), pointer :: tail
integer :: i, n

n = 100000
allocate(head)
tail => head
do i = 1, n - 1
    allocate(tail%next)
    tail => tail%next
end do
deallocate(head)   ! recursive teardown; segfaults at this depth
end program
```

Note that construction is iterative and perfectly happy at this size; only
the teardown recurses. With `n = 10000` the program runs to completion.
