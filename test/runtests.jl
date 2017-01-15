using Base.Test
using QuickTest

import Base: ==
import QuickTest: generate_test_value, Element


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
  @testprop 10 100 -a > 0  a::Int < 0

  @testprop isa(a::Int,Float64) a != a
  
  @test_throws ArgumentError eval(macroexpand(:( @testprop -a::Int128 > 0  a::Int < 0 )))
  @test_throws ArgumentError eval(macroexpand(:( @testprop -a > 0  a::Int < 0  a::Int128 )))
end


type TestType
  a::Int
end
function generate_test_value(::Type{TestType}, size)
  TestType(generate_test_value(Int,size))
end

type ZZmod
  modulus::Int
end
type zz
  parent::ZZmod
  value::Int
end

==(a::ZZmod, b::ZZmod) = a.modulus == b.modulus
==(a::zz, b::zz) = a.parent == b.parent && a.value == b.value

generate_test_value(::Type{ZZmod}, gsize) = ZZmod(rand(1:gsize))
generate_test_value(a::ZZmod, gsize) = zz(a, rand(0:(a.modulus-1)))

@testset "custom types in test properties" begin
  @testprop isa(a::TestType,TestType)
  @testprop a == a  p::ZZmod a::Element{p}
  @testprop 1 isa(a,zz)  p::ZZmod a::Element{p}
  @testprop isa(a,Vector{zz})  p::ZZmod a::ElementVector{p}
end
