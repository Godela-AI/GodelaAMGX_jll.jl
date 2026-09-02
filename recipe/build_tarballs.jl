# GodelaAMGX_jll -- a Godela-owned JLL of NVIDIA AMGX, built from AMGX *main* at
# 91a8413ef267b1c32aff4014c02820e1c5897ac2 (2026-07-09), NOT from a release tag.
#
# Why this exists (and why it is not the registered AMGX_jll):
#   * The registered AMGX_jll (2.4.0) ships CUDA 12 artifacts only; there is no
#     cuda+13 artifact, so it cannot be used on a CUDA 13.x runtime.
#   * The latest AMGX release tag (v2.5.0, cc1cebd) does not compile against
#     CUDA 13.3: CCCL 3.3 no longer pulls in <thrust/tuple.h> transitively and
#     amgx::thrust::tuple/get vanish.  The fix is upstream commit 91a8413ef
#     "Fix CUDA 13 tuple compatibility" (PR #374), which is unreleased.
#   * The build recipe below is therefore Yggdrasil-*style* (it reuses
#     Yggdrasil's fancy_toys.jl / platforms/cuda.jl helpers) but is a Godela-
#     owned package (GodelaAMGX_jll, own UUID) hosted at
#     github.com/Godela-AI/GodelaAMGX_jll.jl; it is NOT intended for
#     submission to Yggdrasil.  The version number v2.5.0 is kept because
#     the shipped C ABI is that of AMGX 2.5.0 (plus AMGX_matrix_check_diag_dominant).
#
# Build with (docker runner; unprivileged user namespaces are disabled here),
# ONE PLATFORM PER INVOCATION, all into the same --deploy=local target
# (BinaryBuilder merges the Artifacts.toml entries and wrapper files):
#   BINARYBUILDER_RUNNER=docker BINARYBUILDER_STORAGE_DIR=<private dir> \
#     julia --project=<env> build_tarballs.jl --verbose --deploy=local x86_64-linux-gnu-cuda+13.3
#   BINARYBUILDER_RUNNER=docker BINARYBUILDER_STORAGE_DIR=<private dir> \
#     julia --project=<env> build_tarballs.jl --verbose --deploy=local x86_64-linux-gnu-cuda+12.9
# Do NOT pass several platforms at once: `build_tarballs` replaces the
# `[platform]` this loop hands it with `split(ARGS[1], ",")`, so every loop
# iteration would build *every* listed platform with that iteration's
# CUDA_SDK_jll version and CUDA_ARCHS list (e.g. a tarball labelled cuda+13.3
# compiled against the 12.9 SDK). Two space-separated platform arguments build
# nothing at all (should_build_platform returns false). Yggdrasil's CI never
# hits this because it always invokes one platform at a time.
# BINARYBUILDER_STORAGE_DIR keeps BinaryBuilderBase's source/clone cache out of
# ~/.julia/scratchspaces, where a concurrent `pkg> gc --all` deletes it mid-build.
using BinaryBuilder, Pkg, BinaryBuilderBase

const YGGDRASIL_DIR = "../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "cuda.jl"))

# TODO: Ship nvToolsExt.h with NVTX_jll and use here instead of patching it out

name = "GodelaAMGX"
version = v"2.5.0"

# Collection of sources required to complete build
#
# We build main at 91a8413ef (committed 2026-07-09) rather than the v2.5.0 tag
# (cc1cebd, 2025-12-21). The tag does not compile against the CCCL 3.3 that ships
# with CUDA 13.3 (`amgx::thrust::tuple`/`get` are gone once <thrust/tuple.h> is no
# longer pulled in transitively); the fix is upstream commit 91a8413ef "Fix CUDA
# 13 tuple compatibility" (PR #374). The other five post-tag commits are the
# C++17-for-CUDA-13.1+ CMake logic (03e5b7e58, 2f9597f44, 3188dce5b), a missing
# AMGX_API export on AMGX_matrix_check_diag_dominant (801814c72) and a stale-enum
# fix in examples/amgx_capi.h (71d64a141). Relative to the tag, include/amgx_c.h
# differs only by that AMGX_API macro (no ABI change on Linux; -fvisibility=default
# already exports it) and include/amgx_config.h is identical.
sources = [
    GitSource("https://github.com/NVIDIA/AMGX.git",
              "91a8413ef267b1c32aff4014c02820e1c5897ac2"),
    DirectorySource("./bundled")
]

# Bash recipe for building across all platforms
script = raw"""
# nvcc writes to /tmp, which is a small tmpfs in our sandbox.
# make it use the workspace instead
export TMPDIR=${WORKSPACE}/tmpdir
mkdir ${TMPDIR}

# use CMake_jll (Alpine's cmake 3.21 predates CUDA 13)
apk del cmake

# nvcc looks for lib64/, the SDK artifact ships lib/ (same hedge as C/cuPDLPx)
[ -e ${prefix}/cuda/lib64 ] || ln -s lib ${prefix}/cuda/lib64

cd ${WORKSPACE}/srcdir/AMGX*
# NOTE: AMGX >= 2.5.0 has no git submodules any more (the vendored Thrust was
# dropped in favour of the toolkit's CCCL), so no `git submodule update` here.

# Apply all our patches
if [ -d $WORKSPACE/srcdir/patches ]; then
for f in $WORKSPACE/srcdir/patches/*.patch; do
    echo "Applying patch ${f}"
    atomic_patch -p1 ${f}
done
fi

install_license LICENSES/BSD-3-Clause.txt

mkdir build
cd build
# - C++17: the CCCL 3.x bundled with CUDA 13.x dropped C++11/14 (13.0's CCCL
#   already hard-errors below C++17), and our host compiler (GCC 9) defaults to
#   gnu++14. Upstream only forces C++17 for CUDA >= 13.1; we do it
#   unconditionally (harmless on CUDA 12).
# - CMAKE_CUDA_ARCHITECTURES must be set explicitly; AMGX's own default is
#   "90;100;120" which would drop every pre-Hopper GPU.
cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TARGET_TOOLCHAIN}" \
      -DCMAKE_INSTALL_PREFIX=${prefix} \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_STANDARD_REQUIRED=ON \
      -DCMAKE_CUDA_STANDARD=17 \
      -DCMAKE_CUDA_STANDARD_REQUIRED=ON \
      -DCMAKE_CUDA_COMPILER=$prefix/cuda/bin/nvcc \
      -DCMAKE_CUDA_FLAGS="-L${prefix}/cuda/lib" \
      -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
      -DCMAKE_NO_MPI=ON \
      -Wno-dev \
      ..

# only the library targets: the unit-test launcher (src/CMakeLists.txt) and the
# examples (patched out) are not shipped; configs/*.json are still installed
# as FILES by src/CMakeLists.txt, so lib/configs matches the 2.4.0 artifact
cmake --build . --parallel ${nproc} --target amgx amgxsh
cmake --install .

# clean-up
## unneeded static libraries
rm ${libdir}/*.a
## the lib64 hedge above is a symlink we created inside the CUDA_SDK_jll tree;
## BinaryBuilder only unsymlinks the dependency's own files, so without this it
## would be shipped as a dangling `cuda/lib64 -> lib` symlink in the artifact
rm -f ${prefix}/cuda/lib64
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line.
# AMGX >= 2.5.0 requires CUDA 12.0 (find_package(CUDAToolkit 12.0 REQUIRED) and a
# FATAL_ERROR for older toolkits), so CUDA 11.x can no longer be built.
# -> 13 x86_64 platforms: cuda+12.0-12.6, 12.8, 12.9, 13.0-13.3.
platforms = CUDA.supported_platforms(; min_version=v"12")
filter!(p -> arch(p) == "x86_64", platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libamgxsh", :libamgxsh),
]

dependencies = [
    HostBuildDependency(PackageSpec(; name="CMake_jll")),
]

# Build for all supported CUDA toolkits
for platform in platforms
    should_build_platform(triplet(platform)) || continue

    cuda_deps = CUDA.required_dependencies(platform; static_sdk=true)

    # GPU architectures. SASS for one representative of every compute-capability
    # major (cubins are binary-compatible within a major: sm_80 SASS runs on
    # sm_86/sm_89, sm_100 on sm_103, sm_120 on sm_121), plus compute_75 PTX as the
    # forward-compatibility fallback for unknown future GPUs. Keeping the SASS list
    # short matters: every entry is a full device compilation of ~160 kernels.
    # CUDA 13 removed offline compilation for Maxwell/Pascal/Volta (< sm_75);
    # sm_100/sm_120 need CUDA >= 12.8; CUDA 12.x still compiles sm_70, and
    # compute_75 PTX cannot JIT backwards to Volta, so keep 70-real on 12.x.
    cuda_ver = VersionNumber(platform["cuda"])
    cuda_archs = if cuda_ver >= v"13"
        "75;80-real;90-real;100-real;120-real"
    elseif cuda_ver >= v"12.8"
        "70-real;75;80-real;90-real;100-real;120-real"
    else
        "70-real;75;80-real;90-real"
    end
    arch_line = "export CUDA_ARCHS=\"$cuda_archs\"\n"
    platform_script = arch_line * script

    build_tarballs(ARGS, name, version, sources, platform_script, [platform],
                   products, [dependencies; cuda_deps]; lazy_artifacts=true,
                   julia_compat="1.6", augment_platform_block=CUDA.augment,
                   dont_dlopen=true, preferred_gcc_version=v"9")
end
