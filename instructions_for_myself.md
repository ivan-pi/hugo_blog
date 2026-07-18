# Instructions for myself — running this blog

Personal notes on how this website is built, how to add content, and how to
deploy it. The live site is <https://ivan-pi.github.io>; these are the
**sources** (rendered output is pushed to a separate repo — see *Deploying*).

- **Static site generator:** [Hugo](https://gohugo.io) (**≥ 0.146.0**, the
  *non-extended* build is enough — the theme sets `extended = false`).
- **Theme:** [`hugo-simple`](https://github.com/maolonglong/hugo-simple),
  vendored as a git submodule under `themes/hugo-simple`.
- **Config:** `config.toml`
- **Content:** `content/`
- **Local overrides of the theme:** `layouts/` (see *How the site is customised*).

---

## Quick start (the 30-second version)

```bash
# 1. Preview locally (includes drafts, live-reloads as you edit)
hugo server -D

# 2. Create a post — copy the template below into a new file:
#    content/posts/YYYYMMDD_short-slug.md   (and fill in the front matter!)

# 3. Publish
./deploy.sh "describe what changed"
```

The single most important rule is in the next section.

---

## ⚠️ The empty `0001-01-01` entries — what they were, and the rule

Earlier the blog list showed mystery entries dated **`0001-01-01`** with no
title. Those were **content files with no front matter.**

Every Markdown file in `content/posts/` becomes a page. If a file has no front
matter (the `--- … ---` block at the top), Hugo has no title and no date for
it, so it falls back to the *zero date* `0001-01-01` and an empty title — and
that empty page shows up in the list. In this repo the culprit was a rough
notes file (`maxloc_conformity.md`) that had been committed without any front
matter. It has since been given proper front matter and marked as a draft.

**The rule:** every file in `content/posts/` **must start with front matter
that includes at least a `title` and a `date`.** If something is just rough
notes, either mark it `draft: true` (below) or keep it out of `content/`
entirely (e.g. in a scratch folder that isn't published).

---

## ⚠️ Where to keep unfinished work — `content/` *is* the public website

Anything inside `content/` is fair game for publishing. There are two traps:

- **Loose non-Markdown files get copied out verbatim and ignore `draft`.** Drop
  a `notes.py`, `links.txt`, or `snippet.f90` into `content/posts/` and Hugo
  publishes it at e.g. `https://ivan-pi.github.io/posts/notes.py` — there is no
  draft switch for these. (This actually happened: `findloc.py`, `findloc.txt`,
  `nvidia_links.txt`, and `reduce_misuse/reduce_misuse.f90` all went live once.)
- **Stray `.md` files without front matter** re-create the `0001-01-01`
  placeholder from the section above; without `draft: true` they publish
  half-finished.

**Habits to avoid this:**

1. **Keep scratch material *outside* `content/`.** Hugo only reads `content/`,
   `static/`, `assets/`, `layouts/`, `i18n/`, `data/`. A sibling folder such as
   `notes/` or `drafts/` at the **repo root** is completely invisible to the
   build — park ideas, link dumps, and code snippets there, and move a file
   into `content/posts/` only once it's a real post with front matter.
2. **In-progress posts you want to preview in place →** use `draft: true`
   (works for `.md` only). `hugo server -D` shows them; `deploy.sh` omits them.
3. **A post that needs companion files** (code, data, images) **→** use a *page
   bundle*: a folder `content/posts/my-post/` with `index.md` plus the files.
   The files then belong to that post and only publish when it does.

**Safety net (belt and suspenders):** `config.toml` sets `ignoreFiles` to make
Hugo skip common scratch types (`.py`, `.txt`, `.c`, `.h`, `.cpp`, `.f`,
`.f90`, `.dat`, `.csv`, `.log`) wherever they appear in `content/`, so a
forgotten snippet can't leak onto the site. Intentionally *not* ignored:
`.pdf`, `.odt`, images (the CV and figures need them). If you ever genuinely
need to publish one of the ignored types, remove its pattern from `ignoreFiles`
(or rename the file).

---

## Writing a new blog post

1. **Create the file** under `content/posts/`. The naming convention here is:

   ```
   content/posts/YYYYMMDD_short-slug.md
   ```

   e.g. `content/posts/20260718_matrix_sizes.md`. The date prefix is only a
   convention to keep the folder sorted — Hugo does **not** use the filename
   for the URL or the date. The URL comes from the `permalinks` setting in
   `config.toml` (`/posts/:year/:month/:title/`), i.e. from the post's **date**
   and **title**.

2. **Start with front matter.** Copy this template and fill it in:

   ```markdown
   ---
   title: "A Clear, Human Title"
   date: 2026-07-18
   draft: true            # true = not published yet; set to false to go live
   tags: ["Fortran", "Performance"]
   katex: true            # only needed if the post contains math (see below)
   ---

   Your post content in Markdown starts here.
   ```

   - **`title`** and **`date`** are required (see the rule above).
   - **`date`** uses `YYYY-MM-DD`. It drives the post's URL and its position in
     the list (newest first).
   - Leave **`draft: true`** while writing; flip it to **`false`** (or delete
     the line) when it's ready to publish.
   - **`tags`** are optional; they generate `/tags/<tag>/` pages.

3. **Write the body** in Markdown below the front matter. Raw HTML is allowed
   (the config sets `markup.goldmark.renderer.unsafe = true`), which is how the
   Twitter embed in the findloc post works.

4. **Preview** with `hugo server -D` and open <http://localhost:1313>. The `-D`
   flag includes drafts so you can see work in progress.

5. **Publish** by setting `draft: false` and running `./deploy.sh`.

### Drafts

A post with `draft: true` is shown by `hugo server -D` locally but is **excluded
from the published site** (`deploy.sh` runs a plain `hugo`, which omits drafts).

Drafts currently in the repo (they will **not** appear on the live site until
you set `draft: false`):

| File | Status |
|------|--------|
| `content/posts/20251123_norm2.md` | draft — *the norm2 performance post*. It is live on the site right now from an earlier deploy, but it is marked `draft: true` here, so **the next deploy will remove it** unless you set `draft: false`. |
| `content/posts/20200215_method-of-weighted-residuals.md` | draft — MWR article |
| `content/posts/20251124_maxloc_conformity.md` | draft — rough notes on the maxloc/minloc zero-size-array issue |

> Note: there used to be a duplicate `20251123_norm2_v2.md` (identical to
> `20251123_norm2.md` apart from whitespace). It was removed to avoid confusion.

---

## Writing math (KaTeX)

Math is rendered in the browser by [KaTeX](https://katex.org). It is **off by
default** and loaded **only on pages that opt in** — add `katex: true` to the
front matter of any post that uses `$…$`, `$$…$$`, or the `neq` shortcode.
Pages without math don't pull in the KaTeX assets at all. (The site-wide
default lives under `[params]` in `config.toml` as `katex = false`.)

- Inline math: `$ ... $`  →  e.g. `the coefficient $b_2$` .
- Display math: `$$ ... $$` on its own.
- **Numbered display equation** — use the `neq` shortcode:

  ```markdown
  {{< neq 1 "L_n(x) = \sum_{k=0}^n \binom{n}{k} \frac{(-1)^k}{k!} x^k" >}}
  ```

  Argument `1` is the number shown as `(1)` on the right; the second argument
  is the TeX formula. (Referencing equation numbers is still manual.)

Dollar signs inside inline code or fenced code blocks are left alone, so shell
snippets like `` `$PATH` `` are safe.

> The old notes mentioned `markup: "mmark"` — that is obsolete. mmark was
> removed from Hugo years ago; everything now uses the default **goldmark**
> renderer plus KaTeX as described here.

## Other shortcodes

- **`notice`** (from the theme) — a callout box:
  ```markdown
  {{< notice >}}
  Text of the note.
  {{< /notice >}}
  ```

---

## Editing the fixed pages

These live directly in `content/` (not under `posts/`) and back the top menu:

| Page | File | Menu entry |
|------|------|-----------|
| Home | `content/_index.md` | `home` |
| Code | `content/code.md` | `code` |
| Diary | `content/diary.md` | `diary` |
| Now | `content/now.md` | `now` |

The menu itself and the footer links are defined under `[menu]` in
`config.toml`.

---

## How the site is customised (the `layouts/` folder)

The project's `layouts/` directory sits **on top of** the theme — any file here
overrides or supplements the theme's version. Two files live here:

- **`layouts/_shortcodes/neq.html`** — the numbered-equation shortcode. It lives
  in the project (not the theme) so it survives theme updates. Several posts use
  it, so **if this file goes missing the whole build fails** with
  `template for shortcode "neq" not found`.
- **`layouts/_partials/custom_head.html`** — injected into every page's
  `<head>`. It (1) loads KaTeX when math is enabled, and (2) loads any
  stylesheet listed under `custom_css` in `config.toml` (currently
  `static/css/address.css`, which adds 📧/📞 icons to the contact links on the
  home page). The theme does not read `custom_css` on its own, so this partial
  is what makes that config key work.

---

## Local preview

```bash
hugo server -D      # -D includes drafts; live-reloads on save
```

Then browse to <http://localhost:1313>. Use `hugo` (no server) to just render
into `./public`.

If Hugo isn't installed, grab a release ≥ 0.146.0 from
<https://github.com/gohugoio/hugo/releases> (the non-extended `hugo` build is
fine), or install via your package manager if it ships a recent enough version.

---

## Deploying

Publishing is one command:

```bash
./deploy.sh "optional commit message"
```

What it does:

1. Runs `hugo --gc --minify --cleanDestinationDir` to render the site into
   `./public` (drafts excluded). If the build fails, the script stops — a
   broken site is never pushed.
2. Commits everything in `./public` and force-pushes it to the GitHub Pages
   repository. The live site updates within a couple of minutes.

`--cleanDestinationDir` means anything you **remove** from the sources also
disappears from `./public` (and therefore the live site) on the next deploy —
so deleting a stray file actually un-publishes it, instead of leaving it
orphaned in the output. The clean preserves `./public/.git`, and
`static/.nojekyll` is regenerated every build (it tells GitHub Pages not to run
Jekyll over the output).

> If you ever switch to a **custom domain**, put its `CNAME` file in `static/`
> (not just in `public/`), otherwise `--cleanDestinationDir` will delete it on
> the next build.

### First-time deployment setup

`deploy.sh` expects **`./public` to itself be a clone of the GitHub Pages
repo** (the repo whose contents are served at <https://ivan-pi.github.io>). This
is the classic Hugo "user page" setup. On a fresh checkout, create it once:

```bash
# from the repo root, replace URL with the actual Pages repo
git clone git@github.com:ivan-pi/ivan-pi.github.io.git public
```

After that, `./deploy.sh` builds into `public/` and pushes from there. The
script refuses to run if `public/` is not a git repository, to avoid
accidentally committing the rendered site into this *sources* repo.

`./public`, the Hugo cache (`resources/_gen/`), and `.hugo_build.lock` are
listed in `.gitignore`, so build output never gets committed to the sources.

---

## Configuration notes (`config.toml`)

- **`baseURL = "https://ivan-pi.github.io/"`** — must be the real site URL.
  It was previously empty, which produced broken absolute links in the RSS
  feed and SEO/social tags. Internal navigation uses relative links, so it
  keeps working regardless, but RSS/sitemap/Open-Graph need this set.
- **`theme = "hugo-simple"`** — the active theme. The other folders under
  `themes/` (`simple-hugo-theme`, `hugo-primer`, `hugo-bearblog`) are old and
  unused; the site only uses `hugo-simple`.
- **`[permalinks] posts = "/posts/:year/:month/:title/"`** — post URLs are built
  from the date and title, not the filename.
- **`katex = false`** and **`custom_css = ["css/address.css"]`** under
  `[params]` — consumed by `layouts/_partials/custom_head.html` (above). KaTeX
  is off by default; a page opts in with `katex: true` in its front matter.
- **`ignoreFiles = [ … ]`** — the safety net that stops stray scratch files
  (`.py`, `.txt`, `.f90`, …) in `content/` from being published. See "Where to
  keep unfinished work" above.

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Build error: `template for shortcode "neq" not found` | `layouts/_shortcodes/neq.html` is missing. It must exist for any post using `{{< neq … >}}`. |
| A blog entry shows date **`0001-01-01`** and no title | That file has no front matter (or no `title`/`date`). Add front matter, or mark it `draft: true`, or move it out of `content/posts/`. |
| Math shows as raw `$$…$$` in the browser | KaTeX didn't load — it's off by default. Add `katex: true` to that page's front matter. |
| A finished post isn't on the live site | It's still `draft: true`. Set `draft: false` and redeploy. |
| A scratch file (`foo.py`, `notes.txt`) got published | It was loose inside `content/`. Move it to a `notes/`/`drafts/` folder at the repo root; add its extension to `ignoreFiles` if needed. `--cleanDestinationDir` removes it from the live site on the next deploy. |
| A deleted post/file is still live | Older Hugo left orphans in `public/`; the deploy now uses `--cleanDestinationDir`, so a redeploy removes it. |
| Fresh clone won't build | Initialise the theme submodule: `git submodule update --init themes/hugo-simple`. |
