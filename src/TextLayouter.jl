module TextLayouter

export layout_text, display_solution

using DisjunctiveProgramming
using HiGHS
using JuMP
using Suppressor

function layout_text(text, row_width; print_summary=false)
  tokens = split(text, ' ') 
  N = length(tokens)
  widths = length.(tokens)
  gap_min = 1

  m = Model(HiGHS.Optimizer)
  @variable(m, 1 <= rows[1:N] <= N, Int)          # assign each word a row
  @variable(m, 1 <= cols[1:N] <= row_width, Int)  # assign each word a column
  @variable(m, 0 <= gaps[1:N] <= row_width, Int)  # assign each word a following gap
  @variable(m, 0 <= rows_max <= N, Int)           # upper bound and minimize rows
  @variable(m, 0 <= gaps_max <= row_width, Int)   # upper bound and minimize gaps
  # Note that the `gap_difference` increases solving time by a lot
  @variable(m, 0 <= gap_difference[1:N-1] <= row_width, Int)  # make gaps as equal as possible

  @constraint(m, rows .≤ rows_max)
  @constraint(m, gaps .≤ gaps_max)

  # try to have similar gaps adjacent to each other, not "a b     c".
  @constraint(m, diff(gaps) .≤ gap_difference)
  @constraint(m, .-diff(gaps) .≤ gap_difference)

  @constraint(m, cols[1] == 1)
  @constraint(m, rows[1] == 1)
  
  # tokens fit into line
  @constraint(m, cols .+ widths[:] .- 1 .≤ row_width)

  for i in 1:(N-1)
    @constraint(m, rows[i] ≤ rows[i+1])
    # token coordinates + gaps sum up between adjacent tokens
    @constraint(m,    rows[i  ]*row_width + cols[i  ] + widths[i] - 1 + gaps[i] + 1
                   == rows[i+1]*row_width + cols[i+1])
  end

  # we suppress warnings about converting == to >= && <=
  @suppress_err for i in 1:(N-1)
    # choice 1: tokens (i) and (i+1) on the same line
    c1 = @constraints(m,
      begin
        rows[i] == rows[i+1]
        gaps[i] ≥ gap_min
      end
    )
    # choice 2: token (i+1) is on the next line
    c2 = @constraints(m,
      begin
        rows[i] == rows[i+1] - 1
        gaps[i] == 0
        cols[i] == row_width - widths[i] + 1 
        cols[i+1] == 1
      end
      )
    add_disjunction!(m, c1, c2, reformulation=:hull, name=Symbol("Y$i"))
  end

  # recall that `rows_max` dominates all row assignments.
  # therefore we can minimize this and maintain a linear formulation,
  # instead of using the `max` operator. Same goes for `gaps_max`.
  @objective(m, Min, rows_max + gaps_max + sum(gap_difference)/(10*N))

  # set_optimizer_attribute(m, "parallel", "on")  # this doesn't seem to do anything...
  optimize!(m)
  cols = round.(Int, value.(cols))
  rows = round.(Int, value.(rows))
  gaps = round.(Int, value.(gaps))

  if print_summary
    println(solution_summary(m))
  end
  return tokens, rows, gaps
end

function display_solution(tokens, rows, gaps, row_width; print_width=false)
  if print_width
    println(repeat('-', row_width) * '|')
  end

  rows = round.(Int, value.(rows))
  gaps = round.(Int, value.(gaps))
  for r in 1:maximum(rows)
    idx = rows .== r
    gap_strs = [repeat(" ", g) for g in gaps[idx]]
      println(join(zip(tokens[idx], gap_strs) |> Iterators.flatten)*(print_width ? "|" : ""))
  end
end

"Uses a simple heuristic to find an initial solution.
This can be fed to speed up the algorithms, but currently that doesn't work."
function heuristic(tokens, row_width)
  N = length(tokens)
  widths = length.(tokens)
  gaps = repeat([1], N)
  cols = repeat([0], N)
  rows = repeat([0], N)
  Ys_1 = repeat([1], N)
  current_row = 1
  current_col = 1
  for (i, w) in enumerate(widths)
    if current_col + widths[i]+1 > row_width
      j = i-1
      Ys_1[j] = 0
      gaps[j] = 0
      col_prev = cols[j]
      cols[j] = row_width - widths[j] + 1
      gaps[j-1] = cols[j] - col_prev + 1
      current_row += 1
      current_col = 1
    end

    cols[i] = current_col
    rows[i] = current_row
    current_col += widths[i]+1
  end

  return rows, cols, gaps, Ys_1
end

"Sets the initial heuristic solution as a feasible solution in the model.
This should get a fast upper bound. Unfortunately, the solver doesn't seem to
use this. Perhaps this is because we don't set all the variables that get
generated from the `add_disjunct` function."
function set_initial_solution(m, tokens, row_width)
  rows_init, cols_init, gaps_init, Ys_1 = heuristic(tokens, row_width)
  set_start_value.(m[:rows], rows_init)
  set_start_value.(m[:cols], cols_init)
  set_start_value.(m[:gaps], gaps_init)
  set_start_value.(m[:rows_max], maximum(rows_init))
  set_start_value.(m[:gaps_max], maximum(gaps_init))
  set_start_value.(m[:gap_difference], abs.(diff(gaps_init)))
  for i in 1:(N-1)
    set_start_value(m[Symbol("Y$i")][1], Ys_1[i])
    set_start_value(m[Symbol("Y$i")][2], 1-Ys_1[i])
  end
end

end # module
