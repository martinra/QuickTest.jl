using Base.Test
using QuickTest

import QuickTest: generate_test_value, @maketestvalues


@testset "unconditioned property test" begin
  @testprop a::Int == a
  @testprop a::Int == a && b::Int == b
  @testprop a::Int == a && b::Float64 == b
  @testprop a == a a::Int
  @testprop a::Int == a a::Int
  @testprop a::Int == a b::Float64
  @testprop 10 a::Int == a

  @test_throws ArgumentError eval(macroexpand(:( @testprop a::Int == a::Int128 )))
  @test_throws ArgumentError eval(macroexpand(:( @testprop a::Int == a a::Int128 )))
end

@testset "conditioned property test" begin
  @testprop -(a::Int) > 0  a < 0
  @testprop -a > 0  a::Int < 0
  @testprop -a > 0  a < 0  a::Int
  @testprop -a > 0  a::Int < 0  a::Int
  @testprop -a > 0  a::Int < 0  b::Float64
  @testprop 10 -a > 0  a::Int < 0
  
  @test_throws ArgumentError eval(macroexpand(:( @testprop -a::Int128 > 0  a::Int < 0 )))
  @test_throws ArgumentError eval(macroexpand(:( @testprop -a > 0  a::Int < 0  a::Int128 )))
end

@testset "maketestvalues" begin
  eval_maketestvalues(n,t) = eval( Expr(:macrocall,
                                      Expr(:(.), :QuickTest, QuoteNode(Symbol("@maketestvalues"))),
                                      n, t) )
  @testset for T in [:Int, :UInt, :Float64, :String, :(Vector{Int}), :(Array{Int,2})]
    @test length( eval_maketestvalues(5, (T,)) ) == 5
    @test length( eval_maketestvalues(5, (Int,T,)) ) == 5
  end
  @testprop 10 length( eval_maketestvalues(n, (Int,)) ) == n::Int  n >= 0
end


type TestType
  a::Int
end
function generate_test_value(::Type{TestType}, size)
  TestType(generate_test_value(Int,size))
end

@testset "custom types in test properties" begin
  @testprop isa(a::TestType,TestType)
end
