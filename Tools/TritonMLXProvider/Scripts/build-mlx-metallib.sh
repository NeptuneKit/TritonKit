#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-debug}"
package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout_root="$package_root/.build/checkouts/mlx-swift"
mlx_root="$checkout_root/Source/Cmlx/mlx"
kernel_root="$mlx_root/mlx/mlx/backend/metal/kernels"
build_root="$package_root/.build/mlx-metallib-manual"
binary_dir="$package_root/.build/arm64-apple-macosx/$configuration"

if [[ ! -d "$checkout_root" ]]; then
  echo "mlx-swift checkout not found at $checkout_root" >&2
  echo "Run: swift build --package-path $package_root -c $configuration --product triton-mlx-provider" >&2
  exit 1
fi

mkdir -p "$build_root" "$binary_dir"

kernels=(
  arg_reduce
  conv
  gemv
  layer_norm
  random
  rms_norm
  rope
  scaled_dot_product_attention
  arange
  binary
  binary_two
  copy
  fft
  reduce
  quantized
  fp_quantized
  scan
  softmax
  logsumexp
  sort
  ternary
  unary
  steel/conv/kernels/steel_conv
  steel/conv/kernels/steel_conv_3d
  steel/conv/kernels/steel_conv_general
  steel/gemm/kernels/steel_gemm_fused
  steel/gemm/kernels/steel_gemm_gather
  steel/gemm/kernels/steel_gemm_masked
  steel/gemm/kernels/steel_gemm_splitk
  steel/gemm/kernels/steel_gemm_segmented
  gemv_masked
  steel/attn/kernels/steel_attention
)

for kernel in "${kernels[@]}"; do
  source_file="$kernel_root/$kernel.metal"
  output_file="$build_root/$(basename "$kernel").air"
  if [[ -f "$output_file" ]]; then
    echo "skip $kernel"
    continue
  fi
  echo "metal $kernel"
  xcrun -sdk macosx metal \
    -x metal \
    -Wall \
    -Wextra \
    -fno-fast-math \
    -Wno-c++17-extensions \
    -Wno-c++20-extensions \
    -mmacosx-version-min=14.0 \
    -c "$source_file" \
    -I"$mlx_root" \
    -o "$output_file"
done

xcrun -sdk macosx metallib "$build_root"/*.air -o "$build_root/mlx.metallib"
cp "$build_root/mlx.metallib" "$binary_dir/mlx.metallib"
ls -lh "$binary_dir/mlx.metallib"
