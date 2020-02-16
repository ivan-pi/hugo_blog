---
title: "Solution of a steady-state reaction-diffusion problem by the method of weighted residuals"
date: 2020-02-15T20:47:20+01:00
draft: true
markup: "mmark"
katex: true
---

## The method of weighted residuals
The method of weighted residuals (MWR) is used to find approximate solutions to differential equations by expanding the unknown solution into a known set of basis functions and determining a set of parameters which minimize the residual with respect to a given weight function. Several variants of the method exist, such as the collocation method, Galerkin method, least squares method and the subdomain method.

The method of weighted residuals was widely used among chemical engineers back in the days before computers were widespread. Approximations using only few terms in the expansion, which could be dealt with by hand (or with a trusty slide rule), proved sufficient for most calculation purposes. Today, the MWR has been mostly replaced by computerized solutions based on finite differences, finite volumes, or finite elements. The latter can be considered as a MWR using local basis functions that take on a non-zero value only over a small region. Spectral methods which are still in widespread use in physics and computational chemistry can also be seens as an advanced version of MWR.

## Steady-state reaction-diffusion equation

For demonstration purposes we will try and approximate the solution of the steady-state reaction-diffusion equation (RDE),

{{< neq 1 "D \frac{\partial^2 c}{\partial x^2} - k c = 0,">}}

where $$c$$ is the concentration of a given species, $$D$$ is the diffusivity, and $$k$$ is the reaction rate constant assuming a first-order reaction. This type of equation appears in the classic treatment of reaction-diffusion in a porous catalyst pellet.

Assume we are interested in calculating the concentration profile inside a porous catalyst slab of thickness $$2L$$. The boundary conditions (BC) for this problem are given by

{{< neq 2a "\frac{\partial c}{\partial x} = 0 \quad \mathrm{at}\; x = 0">}}
{{< neq 2b "c = c_0 \quad \mathrm{at}\;x = L">}}

where the origin of the coordinate system has been placed in the middle of the slab. Given that $$D$$ and $$k$$ are constants we expect the solution to be an even function, $$c(x) = c(-x)$$.

The equations above can be manipulated into dimensionless form, using the thickness $$L$$ and boundary concentration $$c_0$$ to define the following dimensionless variables:

$$ \theta = \frac{x}{L}, \quad u = \frac{c}{c_0}$$

Upon insertion of the new variables into (1) the RDE is transformed into

{{< neq 3 "\frac{\partial^2 u}{\partial^2 \theta} - \tau^2 u = 0">}}

where $$\tau = L \sqrt{k/D}$$ is known as the *Thiele* modulus and represents the ratio of reaction rate and diffusion rate. The boundary conditions are also transformed into

{{< neq 4a "\frac{\partial u}{\partial \theta} = 0 \quad \mathrm{at}\; \theta = 0" >}}

{{< neq 4b "u = 1 \quad \mathrm{at}\;\theta = 1" >}}

## Solution by MWR

We are now ready to find a solution of the (3) and the associated BCs (4) by expanding the unknown solution onto a set of basis functions. For simplicity we will work with the monomials $$\{\theta^k, k = 0,1,2,...\}$$. Limiting ourselves to a second-order expansion, the trial solution $$\tilde{u}$$ takes the form

{{< neq 5 "\tilde{u}(b_k,\theta) = \sum_{k = 0}^2 b_k \theta^k = b_0 + b_1 \theta + b_2 \theta^2," >}}

where $$b_k$$ are a set of unknown coefficients we would like to determine. Two of these can be eliminated by applying the BCs to $$\tilde{u}$$:

$$ \frac{\partial \tilde{u}}{\partial \theta} = b_1 + 2 b_2 \theta = 0 \;\rightarrow\; b_1 + 2b_2 \cdot 0 = 0 \;\rightarrow\; b_1 = 0$$

$$b_0 + b_1 + b_2 = 1$$

Using this knowledge the trial solution may be simplified as

{{< neq 6 "\tilde{u}(b_2,\theta) = (1 - b_2) + b_2 \theta^2 = 1 + b_2 \left(\theta^2 - 1\right)">}}

leaving only one unknown coefficient in the trial solution. This is also known as an *interior* weighted residual method, as the boundary conditions have been integrated into the trial solution beforehand, and only the coefficients controlling the behavior in the interior are to be determined. To determine the value of $$b_2$$ we will seek to minimize the residual of the approximation,

{{< neq 7 "R(b_2,\theta) = \frac{\partial^2 \tilde{u}}{\partial^2 \theta} - \tau^2 \tilde{u} = 2b_2 - \tau^2\left(1 + b_2 \left(\theta^2 - 1\right)\right)">}}

across the entire domain, multiplied by a chosen weight function $$w(\theta)$$:

{{< neq 8 "\int_0^1 w(\theta) R(b_2, \theta) d\theta= 0.">}}

This gives us an equation for the missing coefficient $$b_2$$, completing our trial solution $$\tilde{u}$$. The trial solution satisfies the original differential equation (3) only in the *weak* sense, meaning only the weighted average of the residual equals zero as specified by (8). Notice if $$\tilde{u}(\theta) = u(\theta)$$ was the exact solution, the residual would be zero everywhere, and the integral in (8) would be satisfied automatically.

The variants of MWR mentioned at the beginning correspond to different choices of the weight function $$w(\theta)$$, some leading to better approximate solutions than others. We will now investigate the most common choices.

## Subdomain method

In the subdomain method we force the residual to zero on a certain subregion $$\Gamma_j$$,

{{< neq 9 "w_k(\theta) = \begin{cases} 1, & \theta \in \Gamma_k \\ 0, & \mathrm{otherwise} \end{cases}">}}

The number of subregions should equal the number of unknown parameters. Since we have only one unknown in our reaction-diffusion problem we simply choose the entire interval of interest, $$\Gamma_2 = (0,1)$$. Equation (8) then becomes:

{{< neq 10 "\int_0^1 \left(2b_2 - \tau^2 + \tau^2 b_2 \theta^2 +b_2\tau^2\right)d\theta = 0.">}}
Upon finding the antiderivative of the expression in brackets, and using the fundamental theorem of calculus,[^1] we get the following expression

$$2b_2 - \tau^2 + \frac{\tau^2b_2}{3} + b_2 \tau^2 = 0$$

which can be solved for $$b_2$$, yielding.

{{< neq 11 "b_2 = \frac{3\tau^2}{6 + 4\tau^2}." >}}

For $$\tau = 1$$, the final solution is given by

{{< neq 12 "\tilde{u}(\theta) = 1 + \frac{3}{10}\left( \theta^2 - 1\right).">}}

## Collocation method

In the collocation method the residual is forced to zero at a fixed number of *collocation points* $$\theta_k$$. This corresponds to the choice of weight function

{{< neq 13 "w(\theta) = \delta(\theta - \theta_k)">}}

where $$\delta(x)$$ is the [Dirac delta function](https://en.wikipedia.org/wiki/Dirac_delta_function). Due to the *sampling property*, $$\int f(x)\delta(x-X) dx = f(X)$$, the collocation method simplifies integral expressions into simple evaluations at the collocation points. For the reaction-diffusion case we choose arbitrarily the single point $$\theta_2 = 1/2$$ leading to the expression

$$2b_2 - \tau^2\left(1 + b_2 \left(\left(\frac{1}{2}\right)^2 - 1\right)\right) = 0$$

which upon solving for $$b_2$$, yields

{{< neq 14 "b_2 = \frac{4\tau^2}{8 + 3\tau^2}.">}}

For $$\tau = 1$$, the final solution given by the collocation method is

{{< neq 15 "\tilde{u}(\theta) = 1 + \frac{4}{11}\left( \theta^2 - 1\right).">}}

## Galerkin method

In the Galerkin method the weights are the basis functions of the expansion itself, or more generally - the derivatives of the trial function with respect to the expansion coefficients,


{{< neq 16 "w_k(\theta) = \frac{\partial \tilde{u}}{\partial b_k}.">}}

For the RD at hand we find the following weight function:

$$
w_2(\theta) = \frac{\partial \tilde{u}}{\partial b_2}= \theta^2 - 1,
$$

which upon insertion into (8) becomes


{{< neq 17 "\int_0^1 \left(\theta^2 - 1\right)\left(2b_2 - \tau^2\left(1 + b_2 \left(\theta^2 - 1\right)\right)\right)d\theta = 0">}}

To avoid tedious algebra we can use SymPy to simplify the integral expression and solve the resulting equation for $$b_2$$,

```python
import sympy as sp
t, b2, tau = sp.symbols('theta b_2 tau')
w = (t**2 - 1)
R = (2*b2 - tau**2*(1 + b2*(t**2 - 1)))
eq = sp.integrate(integrand,(t,0,1))
b2_sol = sp.solve(eq,b2)
sp.latex(b2_sol)
```
The output of the code is

{{< neq 18 "b_2 = \frac{5 \tau^{2}}{2 \left(2 \tau^{2} + 5\right)}.">}}

For $$\tau = 1$$, the final solution given by the Galerkin method is

{{< neq 19 "\tilde{u}(\theta) = 1 + \frac{5}{14}\left( \theta^2 - 1\right).">}}

## Least-squares method

Last, but not least, we introduce the least-squares method.

$$
w(\theta) = \frac{\partial R(b_2,\tilde{u})}{\partial b_2} = 2 - \tau^2\left(\theta^2 - 1\right)
$$

$$
\int_0^1 \left(2 - \tau^2\left(\theta^2 - 1\right)\right)\left(2b_2 - \tau^2\left(1 + b_2 \left(\theta^2 - 1\right)\right)\right)d\theta = 0
$$

$$
b_2 = \frac{5 \tau^{2} \left(\tau^{2} + 3\right)}{2 \left(2 \tau^{4} + 10 \tau^{2} + 15\right)}
$$

{{< neq 0 "E=mc^2">}}



[^1]: $$\int_a^b f(x) dx = F(b) - F(a)$$