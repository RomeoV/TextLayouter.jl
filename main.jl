using JuMP
using GLPK
using DisjunctiveProgramming

text = "The quick brown fox jumps over the lazy dog. Over the lazy dog jumps the quick brown fox."
tokens = split(text, ' ') 
N = length(tokens)
widths = length.(tokens)
width_min = 1
row_width = 80

m = Model()
@variable(m, 0 <= gaps[1:N] <= 80, Int)
@variable(m, 1 <= rows[1:N] <= N, Int)

for i in 2:N
  @constraint(m, rows[i] ≥ rows[i-1])
end

for i in 1:(N-1)
  c1 = @constraints(m,
    begin
      rows[i] == rows[i+1]
      gaps[i] ≥ width_min
    end
  )
  c2 = @constraints(m,
    begin
      rows[i]+1 ≤ rows[i+1]
      gaps[i] == 0
    end
  )
  add_disjunction!(m, c1, c2, reformulation=:hull)
end

add_disjunction!(m,
@constraint(m, rows[1] == 1),
@constraint(m, rows[1] ≥ 0),
reformulation=:big_m,
name=:Y11,
)

for i in 1:N
  @constraint(m, sum((widths[j] + gaps[j])*Y11[1] for j in 1:N) == row_width)
end

@objective(m, Min, sum(rows[i] for i in 1:N))
set_optimizer(m, GLPK.Optimizer)

optimize!(m)
solution_summary(m)
