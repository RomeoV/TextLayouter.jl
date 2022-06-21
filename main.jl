using JuMP
using HiGHS
using DisjunctiveProgramming

text = "The quick brown fox jumps over the lazy dog. Over the lazy dog jumps the quick brown fox."
text = "For most users, you should install the 'Current stable release', and whenever Julia releases a new version of the current stable release, you should update your version of Julia. Note that any code you write on one version of the current stable release will continue to work on all subsequent releases."
tokens = split(text, ' ') 
N = length(tokens)
widths = length.(tokens)
gap_min = 1
row_width = 25

m = Model()
@variable(m, 0 <= gaps[1:N] <= row_width, Int)
@variable(m, 1 <= rows[1:N] <= N, Int)
@variable(m, 1 <= cols[1:N] <= row_width, Int)
@variable(m, 0 <= gaps_max <= row_width, Int)
@variable(m, 0 <= rows_max <= N, Int)

@constraint(m, rows .≤ rows_max)
@constraint(m, gaps .≤ gaps_max)

@constraint(m, cols[1] == 1)
@constraint(m, rows[1] == 1)
@constraint(m, cols .+ widths[:] .- 1 .≤ row_width)

for i in 1:(N-1)
  @constraint(m, rows[i] ≤ rows[i+1])
  @constraint(m,   rows[i  ]*row_width + cols[i  ] + widths[i]-1 + gaps[i] +1
                 == rows[i+1]*row_width + cols[i+1])
end

for i in 1:(N-1)
  c1 = @constraints(m,
    begin
      rows[i] == rows[i+1]
      gaps[i] ≥ gap_min
    end
  )
  c2 = @constraints(m,
    begin
      rows[i] == rows[i+1] -1
      gaps[i] == 0
      cols[i] == row_width - widths[i] + 1 
      cols[i+1] == 1
    end
  )
  add_disjunction!(m, c1, c2, reformulation=:hull)
end

@objective(m, Min, rows_max + gaps_max)
set_optimizer(m, HiGHS.Optimizer)

optimize!(m)
println(solution_summary(m))

function display_solution(text, rows, gaps; print_width=true)
  if print_width
    println(repeat('-', 25) * '|')
  end

  rows = Int.(value.(rows))
  gaps = Int.(value.(gaps))
  for r in 1:maximum(rows)
    idx = rows .== r
    gap_strs = [repeat(" ", g) for g in gaps[idx]]
    println(join(zip(tokens[idx], gap_strs) |> Iterators.flatten)*"|")
  end
end
display_solution(text, rows, gaps)
