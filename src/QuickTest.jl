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
using Base.Test: AbstractTestSet, DefaultTestSet
using LightGraphs

import Base.Test: record, finish

export @testprop, QuickTestSet


const ntests_default = 100::Int
const maxntries_default_factor = 4::Int


abstract type Element{P} end
abstract type ElementVector{P} end
abstract type Expression{P} end


type QuickTestSet <: AbstractTestSet
  testset::DefaultTestSet
  function QuickTestSet(desc; var_vals=Tuple{String,Symbol}[])
    for (s,v) in var_vals
      desc = string(desc, "  $s = $v")
    end
    new(DefaultTestSet(desc))
  end
end

record(ts::QuickTestSet,r) = record(ts.testset,r)
finish(ts::QuickTestSet) = finish(ts.testset)


function testprop_(ntests::Int, prop::Expr, type_asserts::Vector{Expr})
  if isempty(type_asserts) 
    description = string(prop) 
  else
    description = string(prop, " | ", [string(ta, " ") for ta in type_asserts]...)
  end

  types = extract_types_from_expression(prop)
  extract_types_from_asserts!(types, type_asserts)
  types = topological_sort_types(types)

  Expr(:for, Expr(:(=), :testsize, Expr(:(:), 1, ntests)),
       Expr(:block,
            init_test(:testsize, types)...,
            Expr(:macrocall, Symbol("@testset"),
                 esc(:QuickTestSet),
                 Expr(:(=), esc(:var_vals), esc(var_vals(types))),
                 string(description, ": case"),
                 Expr(:block, Expr(:macrocall, Symbol("@test"), esc(prop)))
                )
           )
      )
end

function testcondprop_(ntests::Int, maxntries::Int, prop::Expr, cond::Expr, type_asserts::Vector{Expr})
  if isempty(type_asserts) 
    description = string(prop, " | ", cond)
  else
    description = string(prop, " | ", cond, " ; ",
                         [string(ta, " ") for ta in type_asserts]...)
  end

  types = extract_types_from_expression(prop)
  extract_types_from_expression!(types, cond)
  extract_types_from_asserts!(types, type_asserts)
  types = topological_sort_types(types)

  Expr(:block,
       Expr(:(=), :testsize, 1),
       Expr(:(=), :curtest, 1),
       Expr(:for, Expr(:(=), :xtry, Expr(:(:), 1, maxntries)),
            Expr(:block,
                 Expr(:if, Expr(:call, :(>), :xtry, Expr(:call, :(*), :maxntries_default_factor, :testsize)),
                      Expr(:(+=), :testsize, 1),
                     ),
                 init_test(:testsize, types)...,
                 Expr(:(||), esc(cond), :(continue)),
                 Expr(:macrocall, Symbol("@testset"),
                      esc(:QuickTestSet),
                      Expr(:(=), esc(:var_vals), esc(var_vals(types))),
                      string(description, ": case"),
                      Expr(:block, Expr(:macrocall, Symbol("@test"), esc(prop)))
                     ),
                 Expr(:(+=), :testsize, 1),
                 Expr(:(+=), :curtest, 1),
                 Expr(:if, Expr(:call, :(>), :curtest, ntests),
                      Expr(:break)
                )
           )
       ),
       Expr(:if, Expr(:call, :(<=), :curtest, ntests),
            Expr(:call, :warn, string("Did not exhaust number of test cases for ", description))
           )
      )
end

function topological_sort_types(types)
  g = DiGraph()
  symbol_labels = Dict{Symbol,Int}()
  symbol_list = Symbol[]
  for (s,t) in types
    add_vertex!(g)
    symbol_labels[s] = nv(g)
    push!(symbol_list,s)
  end
  for (s,t) in types
    if t.head == :curly && t.args[1] in [:Element, :ElementVector]
      add_edge!(g, symbol_labels[t.args[2]], symbol_labels[s])
    elseif t.head == :call && t.args[1].head == :curly && t.args[1].args[1] == :Expression
      for ts in t.args[1].args[2:end]
        add_edge!(g, symbol_labels[ts], symbol_labels[s])
      end
    end
  end

  sorted_types = Tuple{Symbol,Expr}[]
  for sx in topological_sort_by_dfs(g)
    s = symbol_list[sx]
    push!(sorted_types, (s, types[s]))
  end
  return sorted_types
end

function init_test(size_symbol, types)
  exprs = Expr[]
  for (s,t) in types
    if t.head == :curly && t.args[1] == :Element
      push!(exprs, Expr(:(=), esc(s), Expr(:call, generate_test_value, esc(t.args[2]), size_symbol)))
    elseif t.head == :curly && t.args[1] == :ElementVector
      push!(exprs, Expr(:(=), esc(s), Expr(:call, generate_test_vector, esc(t.args[2]), size_symbol)))
    elseif t.head == :call && t.args[1].head == :curly && t.args[1].args[1] == :Expression
      push!(exprs, Expr(:(=), esc(s), esc(t.args[2])))
    else
      push!(exprs, Expr(:(=), esc(s), Expr(:call, generate_test_value, esc(t), size_symbol)))
    end
  end
  return exprs
end

function var_vals(types)
  return Expr(:vect, [Expr(:tuple, string(s), esc(s)) for (s,t) in types]...)
end


macro testprop(prop::Expr, cond_and_type_asserts...)
  cond_and_type_asserts = Vector{Expr}(collect(cond_and_type_asserts))

  if !isempty(cond_and_type_asserts) && cond_and_type_asserts[1].head != :(::)
    ntests = ntests_default
    maxntries = maxntries_default_factor * ntests
    cond = cond_and_type_asserts[1]
    type_asserts = cond_and_type_asserts[2:length(cond_and_type_asserts)]
    return testcondprop_(ntests, maxntries, prop, cond, type_asserts)
  else
    ntests = ntests_default
    type_asserts = cond_and_type_asserts
    return testprop_(ntests, prop, type_asserts)
  end
end

macro testprop(ntests::Int, prop::Expr, cond_and_type_asserts...)
  cond_and_type_asserts = Vector{Expr}(collect(cond_and_type_asserts))

  if !isempty(cond_and_type_asserts) && cond_and_type_asserts[1].head != :(::)
    maxntries = maxntries_default_factor * ntests
    cond = cond_and_type_asserts[1]
    type_asserts = cond_and_type_asserts[2:length(cond_and_type_asserts)]
    return testcondprop_(ntests, maxntries, prop, cond, type_asserts)
  else
    type_asserts = cond_and_type_asserts
    return testprop_(ntests, prop, type_asserts)
  end
end

macro testprop(ntests::Int, maxntries::Int, prop::Expr, cond_and_type_asserts...)
  cond_and_type_asserts = Vector{Expr}(collect(cond_and_type_asserts))

  if !isempty(cond_and_type_asserts) && cond_and_type_asserts[1].head != :(::)
    cond = cond_and_type_asserts[1]
    type_asserts = cond_and_type_asserts[2:length(cond_and_type_asserts)]
    return testcondprop_(ntests, maxntries, prop, cond, type_asserts)
  else
    error("maximum number of tries given, but no test condition present")
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
  array_size = size
  for n = 1:d
    a = rand(1:array_size)
    array_size = max(1,div(array_size,a))
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

## in more complex situations, types do not encode the full parametricity of a parent
## in this case we need 

function generate_test_vector{A}(parent::A, size)
  vsize = rand(1:size)
  [generate_test_value(parent,size) for x in 1:vsize]
end

function generate_test_matrix{A}(parent::A, size)
  rsize = rand(1:size)
  csize = rand(1:max(1,div(size,rsize)))
  dims = [rsize, csize]
  reshape([generate_test_value(T,size) for x in 1:prod(dims)], dims...)
end

function generate_test_tuple{A}(parentA::A, size)
  (generate_test_vector(parentA,size),)
end
function generate_test_tuple{A,B}(parentA::A, parentB::B, size)
  (generate_test_vector(parentA,size),generate_test_vector(parentB,size))
end

function generate_test_tuple{A,B,C}(parentA::A, parentB::B, parentC::C, size)
  (generate_test_vector(parentA,size),generate_test_vector(parentB,size),
   generate_test_vector(parentC,size))
end

function generate_test_tuple{A,B,C,D}(parentA::A, parentB::B, parentC::C, parentD::D, size)
  (generate_test_vector(parentA,size),generate_test_vector(parentB,size),
   generate_test_vector(parentC,size),generate_test_vector(parentD,size))
end

end
