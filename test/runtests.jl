using Base.Test
using QuickTest

@testprop a::Int == a
@testprop a::Int == a && b::Int == b
@testprop a::Int == a && b::Float64 == b
@testprop a == a a::Int
@testprop a::Int == a a::Int
@testprop a::Int == a b::Float64
@testprop 10 a::Int == a

@test_throws ArgumentError eval(macroexpand(:( @testprop a::Int == a::Int128 )))
@test_throws ArgumentError eval(macroexpand(:( @testprop a::Int == a a::Int128 )))

@testprop -(a::Int) > 0  a < 0
@testprop -a > 0  a::Int < 0
@testprop -a > 0  a < 0  a::Int
@testprop -a > 0  a::Int < 0  a::Int
@testprop -a > 0  a::Int < 0  b::Float64
@testprop 10 -a > 0  a::Int < 0

@test_throws ArgumentError eval(macroexpand(:( @testprop -a::Int128 > 0  a::Int < 0 )))
@test_throws ArgumentError eval(macroexpand(:( @testprop -a > 0  a::Int < 0  a::Int128 )))


@testset "generate_test_value" begin
  @testset for T in [Int, UInt, Float64, String, Vector{Int}, Array{Int,2}]
    @test length( QuickTest.test_values(5, (T,)) ) == 5
    @test length( QuickTest.test_values(5, (T,Tuple{Int,T})) ) == 5
  end
end
@testprop 10 length(QuickTest.test_values(n, (Int,))) == n::Int n >= 0
