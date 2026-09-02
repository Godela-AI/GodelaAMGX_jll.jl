# GodelaAMGX_jll.jl

Godela-owned binary wrapper (JLL) for [NVIDIA AMGX](https://github.com/NVIDIA/AMGX), built from `main` at
commit `91a8413ef267b1c32aff4014c02820e1c5897ac2` (v2.5.0 plus the CUDA 13.3 CCCL fix from PR #374, which has
no upstream release yet) with [BinaryBuilder](https://github.com/JuliaPackaging/BinaryBuilder.jl).

Why this exists: the registered `AMGX_jll` 2.4.0 ships artifacts for CUDA 11.4–12.6 only, so it cannot run on a
CUDA 13 toolkit, and AMGX 2.5.0's tag does not compile against CUDA 13.3. This package is not intended
for Yggdrasil.

| Platform | Compiled with | SASS | PTX |
|---|---|---|---|
| `x86_64-linux-gnu-cuda+13.3` | nvcc 13.3.73, GCC 9.1 | sm_75, sm_80, sm_90, sm_100, sm_120 | compute_75 |
| `x86_64-linux-gnu-cuda+12.9` | nvcc 12.9.86, GCC 9.1 | sm_70, sm_75, sm_80, sm_90, sm_100, sm_120 | compute_75 |

The artifact is selected by the CUDA toolkit that `CUDA_Runtime_jll` resolves (same matcher as `AMGX_jll`:
same major, artifact minor ≤ host minor), so a `LocalPreferences.toml` pinning `CUDA_Runtime_jll` /
`CUDA_Compiler_jll` to `"12.9"` selects the 12.9 build and `"13.3"` the 13.3 build. Bundled patches disable
NVTX ranges and skip the example executables; the C API is a strict superset of AMGX 2.4.0
(`AMGX_matrix_check_diag_dominant` added). The recipe and its two patches are in `recipe/` (a
Yggdrasil-style `build_tarballs.jl`: drop it at `<Yggdrasil>/A/GodelaAMGX/` for its helper includes and
build one platform per invocation, as its header explains); the per-platform build logs are attached to
the release as `GodelaAMGX-logs.*.tar.gz`.

```julia
using GodelaAMGX_jll
GodelaAMGX_jll.is_available() && GodelaAMGX_jll.libamgxsh
```
