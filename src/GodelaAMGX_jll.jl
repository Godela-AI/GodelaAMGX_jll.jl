# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule GodelaAMGX_jll
using Base
using Base: UUID
using LazyArtifacts
Base.include(@__MODULE__, joinpath("..", ".pkg", "platform_augmentation.jl"))
import JLLWrappers

JLLWrappers.@generate_main_file_header("GodelaAMGX")
JLLWrappers.@generate_main_file("GodelaAMGX", Base.UUID("36fe3f54-eb54-5a79-abae-b48804b7d78e"))
end  # module GodelaAMGX_jll
