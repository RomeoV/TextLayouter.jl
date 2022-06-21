using JuMP
using GLPK
using DisjunctiveProgramming

text = "The quick brown fox jumps over the lazy dog. Over the lazy dog jumps the quick brown fox. X"
text = "For most users, you should install the 'Current stable release', and whenever Julia releases a new version of the current stable release, you should update your version of Julia. Note that any code you write on one version of the current stable release will continue to work on all subsequent releases."
tokens = split(text, ' ') 
N = length(tokens)
widths = length.(tokens)
gap_min = 1
row_width = 25

m = Model()
@variable(m, gap_min <= gaps[1:N] <= row_width, Int)
@variable(m, 1 <= rows[1:N] <= N, Int)
@variable(m, 1 <= cols[1:N] <= row_width, Int)
@variable(m, 0 <= gaps_max <= row_width, Int)
@variable(m, 0 <= rows_max <= N, Int)

for i in 1:(N-1)
  @constraint(m, gaps[i] .≤ gaps_max)
end
@constraint(m, rows .≤ rows_max)

for i in 1:(N-1)
  @constraint(m, rows[i] ≤ rows[i+1])
  @constraint(m,   rows[i  ]*2*row_width + cols[i  ] + widths[i]-1 + gaps[i] + 1
                 ≤ rows[i+1]*2*row_width + cols[i+1])
end

for i in 1:N
  @constraint(m, cols[i] + widths[i]-1 ≤ row_width)
end

# @objective(m, Min, 1.1*gaps_max + 2*N*rows_max - sum(gaps) - 1.1*sum(cols))
# @objective(m, Max, 2*sum(cols) + sum(gaps))  #1.1*gaps_max + 2*N*rows_max - sum(gaps) - 1.1*sum(cols))
@objective(m, Max, sum(gaps) - 100*rows_max - sqrt(N)*gaps_max - sum(cols)/row_width)
set_optimizer(m, GLPK.Optimizer)

optimize!(m)
solution_summary(m)

rows = Int.(value.(rows))
gaps = Int.(value.(gaps))
for r in 1:maximum(rows)
  idx = rows .== r
  gap_strs = [repeat(" ", g) for g in gaps[idx]]
  println(join(zip(tokens[idx], gap_strs) |> Iterators.flatten)*"|")
end
