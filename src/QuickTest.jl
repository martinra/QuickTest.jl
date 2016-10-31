################################################################################
# QuickTest
#
# A Julia implementation of QuickCheck, a specification-based tester
#
# QuickCheck was originally written for Haskell by Koen Claessen and John Hughes
# http://www.cse.chalmers.se/~rjmh/QuickCheck/
#
################################################################################

module QuickTest

using Base.Test

export @testprop


const ntests_default = 100::Int


function testprop_(ntests::Int, prop::Expr, type_asserts::Vector{Expr})
  if isempty(type_asserts) 
    description = string(prop) 
  else
    description = string(prop, " | ", [string(ta, " ") for ta in type_asserts]...)
  end

  types = extract_types_from_expression(prop)
  extract_types_from_asserts!(types, type_asserts)
  symbols_ord, types_ord = collect(zip([[s,t] for (s,t) in types]...))

  symbols_expr = Expr(:tuple)
  symbols_expr.args = [esc(s) for s in symbols_ord]

  types_expr = Expr(:tuple)
  types_expr.args = [esc(t) for t in types_ord]

  Expr(:macrocall, Symbol("@testset"), description,
       Expr(:block,
            Expr(:macrocall, Symbol("@testset"),
                 Expr(:for, Expr(:(=), symbols_expr,
                                 Expr(:macrocall, Symbol("@maketestvalues"), ntests, types_ord)),
                      Expr(:macrocall, Symbol("@test"), esc(prop))
                     )
                )
           )
      )
end

function testcondprop_(ntests::Int, prop::Expr, cond::Expr, type_asserts::Vector{Expr})
  if isempty(type_asserts) 
    description = string(prop, " | ", cond)
  else
    description = string(prop, " | ", cond, " ; ",
                         [string(ta, " ") for ta in type_asserts]...)
  end

  types = extract_types_from_expression(prop)
  extract_types_from_expression!(types, cond)
  extract_types_from_asserts!(types, type_asserts)
  symbols_ord, types_ord = collect(zip([[s,t] for (s,t) in types]...))

  symbols_expr = Expr(:tuple)
  symbols_expr.args = [esc(s) for s in symbols_ord]

  Expr(:macrocall, Symbol("@testset"), description,
       Expr(:block,
            Expr(:macrocall, Symbol("@testset"),
                 Expr(:for, Expr(:(=), symbols_expr,
                                 Expr(:macrocall, Symbol("@maketestvalues"), ntests, types_ord)),
                      Expr(:macrocall, Symbol("@test"),
                           Expr(:(||), Expr(:call, :(!), esc(cond)), esc(prop))
                          )
                     )
                )
           )
      )
end

macro testprop(prop::Expr, cond_and_type_asserts...)
  cond_and_type_asserts = Vector{Expr}(collect(cond_and_type_asserts))

  if !isempty(cond_and_type_asserts) && cond_and_type_asserts[1].head != :(::)
    ntests = ntests_default
    cond = cond_and_type_asserts[1]
    type_asserts = cond_and_type_asserts[2:length(cond_and_type_asserts)]
    return testcondprop_(ntests, prop, cond, type_asserts)
  else
    ntests = ntests_default
    type_asserts = cond_and_type_asserts
    return testprop_(ntests, prop, type_asserts)
  end
end

macro testprop(ntests::Int, prop::Expr, cond_and_type_asserts...)
  cond_and_type_asserts = Vector{Expr}(collect(cond_and_type_asserts))

  if !isempty(cond_and_type_asserts) && cond_and_type_asserts[1].head != :(::)
    cond = cond_and_type_asserts[1]
    type_asserts = cond_and_type_asserts[2:length(cond_and_type_asserts)]
    return testcondprop_(ntests, prop, cond, type_asserts)
  else
    type_asserts = cond_and_type_asserts
    return testprop_(ntests, prop, type_asserts)
  end
end


function extract_types_from_expression(e::Expr)
  types = Dict{Symbol,Expr}()
  extract_types_from_expression!(types, e)
  return types
end

function extract_types_from_expression!(types::Dict{Symbol,Expr}, e::Expr)
  stack = [e]
  while !isempty(stack)
    e = pop!(stack)
    if isa(e.args, Array)
      append!(stack, filter((f) -> isa(f,Expr), e.args))
    end

    if e.head == :(::)
      add_type_to_dict!(types, e)
    end
  end
end

function extract_types_from_asserts!(types::Dict{Symbol,Expr}, es::Array{Expr,1})
  for e in es
    if e.head != :(::)
      throw( ArgumentError(string("Type assertions must be of the form ",
                                  "symbol::type; ",
                                  "found instread: ", string(e))) )
    end

    add_type_to_dict!(types, e)
  end
end

function add_type_to_dict!(types::Dict{Symbol,Expr}, e::Expr)
  if isa(e.args[2], Symbol)
    t = Expr(:block, e.args[2])
  else
    t = e.args[2]
  end
  add_type_to_dict!(types, e.args[1], t)
end

function add_type_to_dict!(types::Dict{Symbol,Expr}, s::Symbol, t::Expr)
  if haskey(types, s)
    if types[s] != t
      throw( ArgumentError(string("Incompatible type symbols ", types[s], " and ", t,
                                  " specified for symbol ", s)) )
    end
  else
    types[s] = t
  end
end


macro maketestvalues(ntests::Int, types::Tuple)
  quote
    collect(zip([ [ generate_test_value($(esc(:eval))(t), rand((div(n,2) + 1):(div(n,2) + 3)))
                    for n = 1:$ntests ]
                  for t in $types ]...))
  end
end


function generate_test_value{T<:Signed}(::Type{T}, size)
  convert(T, rand(-size:size))
end

function generate_test_value{T<:Unsigned}(::Type{T}, size)
  convert(T, rand(0:size))
end

function generate_test_value{T<:AbstractFloat}(::Type{T}, size)
  convert(T, (rand(T) - .5) * size)
end

function generate_test_value{T<:String}(::Type{T}, size)
  convert(T, randstring(size))
end


function generate_test_value{T,d}(::Type{Array{T,d}}, size)
  dims = []
  for n = 1:d
    a = rand(1:size)
    size = min(1,div(size,a))
    append!(dims,a)
  end
  reshape([generate_test_value(T,size) for x in 1:prod(dims)], dims...)
end

function generate_test_value{A}(::Type{Tuple{A}}, size)
  (generate_test_value(A, size),)
end

function generate_test_value{A,B}(::Type{Tuple{A,B}}, size)
  (generate_test_value(A, size),generate_test_value(B, size))
end

function generate_test_value{A,B,C}(::Type{Tuple{A,B,C}}, size)
  (generate_test_value(A, size), generate_test_value(B, size),
   generate_test_value(C, size))
end

function generate_test_value{A,B,C,D}(::Type{Tuple{A,B,C,D}}, size)
  (generate_test_value(A, size), generate_test_value(B, size),
   generate_test_value(C, size), generate_test_value(D, size))
end


end
