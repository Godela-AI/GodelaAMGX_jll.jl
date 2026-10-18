using Test
using CheckConcreteStructs: all_concrete
using GodelaAMGX_jll

@testset "Concrete struct fields" begin
    modules = Module[GodelaAMGX_jll]
    seen = Set{Module}()
    for M in modules
        M in seen && continue
        push!(seen, M)
        @testset "$(M)" begin
            @test all_concrete(M; verbose=true)
        end
        for name in names(M; all=true, imported=false)
            isdefined(M, name) || continue
            Base.isdeprecated(M, name) && continue
            child = getglobal(M, name)
            child isa Module && child !== M && parentmodule(child) === M && push!(modules, child)
        end
    end
end
