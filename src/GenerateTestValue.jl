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
