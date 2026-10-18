using Test
using Aqua
using GodelaAMGX_jll

@testset "Aqua.jl" begin
    Aqua.test_all(GodelaAMGX_jll)
end
