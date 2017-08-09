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

include("GenerateTestValue.jl")
include("TestProp.jl")

end
