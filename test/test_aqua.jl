using Test
using Aqua
using GodelaAMGX_jll

@info "Aqua test dependency" version=Base.pkgversion(Aqua) path=pathof(Aqua)

@testset "Aqua.jl" begin
    Aqua.test_all(GodelaAMGX_jll)
end
