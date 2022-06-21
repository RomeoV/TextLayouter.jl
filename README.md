# TextLayouter

A simple proof-of-concept tool for solving the [justification problem](https://en.wikipedia.org/wiki/Typographic_alignment) when laying out text on a page.
Unlike other popular approaches, this project models the problem as a Generalized Disjunctive Program, which is automatically rewritten as a Mixed-Integer Linear Program (or even a simple Integer Program) using [JuMP.jl](https://jump.dev/JuMP.jl/stable/) and [DisjunctiveProgramming.jl](https://github.com/hdavid16/DisjunctiveProgramming.jl), and finally solved using [HiGHS.jl](https://github.com/jump-dev/HiGHS.jl), although other solvers are possible.

Note that this code works for small to medium large paragraphs, but ends up being very slow and is therefore not really usable for actual applications.
For a more proper algorithm, consider looking at [1], written by Donald Knuth himself together with Michael Plass and using dynamic programming to accelerate the problem massively.

## Examples
Here are two simple texts, justified using the presented algorithm with a maximal with of 25 characters, and including the time to solve by the HiGHS solver.
Note the somewhat substantial time for the longer example.

```julia
julia> row_width = 25
julia> @time res1 = layout_text(text1, row_width; print_summary=true);
  1.146295 seconds (1.90 M allocations: 113.488 MiB, 1.86% gc time, 27.31% compilation

julia> display_solution(res1..., row_width; print_width=true)
-------------------------|
The quick brown fox jumps|
over the  lazy  dog. Over|
the  lazy  dog  jumps the|
quick brown fox. |

julia> @time res2 = layout_text(text1, row_width; print_summary=true);
 81.025225 seconds (12.67 M allocations: 860.274 MiB, 0.22% gc time)

julia> display_solution(res2..., row_width; print_width=true)
-------------------------|
For   most   users,   you|
should    install     the|
'Current stable release',|
and    whenever     Julia|
releases  a  new  version|
of  the   current  stable|
release,    you    should|
update  your  version  of|
Julia. Note that any code|
you write on one  version|
of   the  current  stable|
release   will   continue|
to work on all subsequent|
releases.|
```

Here is the same example with a maximum width of only 15.

``` julia
julia> row_width = 15
julia> @time res1 = layout_text(text1, row_width; print_summary=true);
  0.804713 seconds (1.18 M allocations: 75.204 MiB)

julia> display_solution(res1..., row_width; print_width=true)
---------------|
The quick brown|
fox jumps  over|
the  lazy  dog.|
Over  the  lazy|
dog  jumps  the|
quick     brown|
fox.|

julia> @time res2 = layout_text(text1, row_width; print_summary=true);
  3.774910 seconds (12.67 M allocations: 860.273 MiB, 5.93% gc time)

julia> display_solution(res2..., row_width; print_width=true)
---------------|
For most users,|
you      should|
install     the|
'Current stable|
release',   and|
whenever  Julia|
releases a  new|
version of  the|
current  stable|
release,    you|
should   update|
your    version|
of  Julia. Note|
that  any  code|
you  write   on|
one  version of|
the     current|
stable  release|
will   continue|
to   work    on|
all  subsequent|
releases.|
```

## The math
This is only a short overview over the mathematical approach. The full approach can be seen in the source code itself in [src/TextLayouter.jl](src/TextLayouter.jl).

The algorithm assigns each token (word) with width $width_i$ a row $row_i$ and column $col_i$.
In addition, a variable $gap_i$ for the length of the gap between two consecutive words is introduced.
The task is now to find good values for each $gap_i$, as well as decide where line breaks should occur (and the gap should be 0).

For this decision process, Disjunctive Programming is used and for each token a decision variable $Y_i$ is introduced, each with two choices:
$Y_i = \bot$, $row_i = row_{(i+1)}$, and $gap_i \geq gap_{\textrm min}$ **or** $Y_i = \top$, $row_i = row_{(i+1)} - 1$, $gap_i = 0$ $cols_i = width^{\textrm max} - width_i + 1$, and $cols_{(i+1)} = 1$.
By translating these variables into a Mixed-Integer form, we can employ regular MILP solvers to solve the resulting problem.

An additional problem that then needs to be solved is to minimize the total number of rows used and minimize the gaps in general.
Since the $\max$ operator is a non-linear operator, a proxy variable $rows^{\textrm max}$ and a set of additional constraints $row_i \leq rows^{\textrm max}$ are introduced, such that the term $rows^{\textrm max}$ can simply be included in the objective function. The same trick is employed for the gaps.

Finally, we also don't want the gaps to be too irregular, for example `a_b______c`.
A similar trick as before is introduced, this time for each token: $gap_i - gap_{(i+1)} \leq gap^{\textrm max}_i$ and $gap_{(i+1)} - gap_i \leq gap^{\textrm max}_i$.
Then, the sum of the gap differences is included in the objective function, with a discount term smaller than 1.

[1]: Knuth, Donald E., and Michael F. Plass. “Breaking Paragraphs into Lines.” Software: Practice and Experience 11, no. 11 (1981): 1119–84. https://doi.org/10.1002/spe.4380111102.
