// RUN: mlir-opt -test-linalg-to-axi4mlir="flow-cpu-accumulation" \
// RUN:  -convert-linalg-to-loops -lower-affine -convert-scf-to-cf \
// RUN:  -convert-vector-to-llvm -convert-memref-to-llvm -convert-std-to-llvm \
// RUN:  -reconcile-unrealized-casts %s | \
// RUN: mlir-cpu-runner \
// RUN:  -O0 -e main -entry-point-result=void \
// RUN:  -shared-libs=%mlir_runner_utils_dir/libmlir_mockaxi_runner_utils%shlibext \
// RUN:  -shared-libs=%mlir_runner_utils_dir/libmlir_runner_utils%shlibext | \
// RUN: FileCheck %s

// MLIR Runner
func private @print_memref_f32(memref<*xf32>)


// This is the only code that gets modified by the -test-linalg-to-axi4mlir pass
func @matmul_call(%A: memref<16x8xf32>, %B: memref<8x32xf32>, %C: memref<16x32xf32>) {
  linalg.matmul {__internal_linalg_transform__="L1"}
   ins(%A, %B: memref<16x8xf32>, memref<8x32xf32>)
   outs(%C: memref<16x32xf32>)
  return
}

//CHECK: dma_init

// This is a repeating pattern. Only check the first 2 iterations.
//CHECK: dma_start_send
//CHECK: dma_wait_send
//CHECK: dma_start_recv
//
//CHECK: dma_start_send
//CHECK: dma_wait_send
//CHECK: dma_start_recv

// Many more will happen

//CHECK: dma_free

// All functions below are only part of the driver code
func @alloc_2d_filled_f32(%s1 : index, %s2 : index, %f : f32) -> memref<?x?xf32> {
  %buf = memref.alloc(%s1, %s2) : memref<?x?xf32>
  linalg.fill(%f, %buf) : f32, memref<?x?xf32>
  return %buf : memref<?x?xf32>
}

func @alloc_2d_filled_inc_f32(%arg0: index, %arg1: index, %arg2: f32) -> memref<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 1.000000e+02 : f32
  %0 = memref.alloc(%arg0, %arg1) : memref<?x?xf32>
  linalg.fill(%arg2, %0) : f32, memref<?x?xf32>
  scf.for %arg3 = %c0 to %arg0 step %c1 {
    scf.for %arg4 = %c0 to %arg1 step %c1 {
      %1 = arith.index_cast %arg3 : index to i32
      %2 = arith.index_cast %arg4 : index to i32
      %3 = arith.sitofp %1 : i32 to f32
      %4 = arith.sitofp %2 : i32 to f32
      %5 = arith.mulf %3, %cst : f32
      %6 = arith.addf %4, %5 : f32
      memref.store %6, %0[%arg3, %arg4] : memref<?x?xf32>
    }
  }
  return %0 : memref<?x?xf32>
}

#id_2d = affine_map<(i, j) -> (i, j)>
#pointwise_2d_trait = {
  indexing_maps = [#id_2d, #id_2d],
  iterator_types = ["parallel", "parallel"]
}

func @main() {
  %c2 = arith.constant 2 : index
  %c4 = arith.constant 4 : index
  %c0 = arith.constant 0 : index
  %c8 = arith.constant 8 : index
  %c16 = arith.constant 16 : index
  %c32 = arith.constant 32 : index
  %c1000 = arith.constant 1000 : index

  %c1_0 = arith.constant 1 : i64
  %cst_1 = arith.constant 1.000000e+00 : f32
  %cst_0 = arith.constant 0.000000e+00 : f32

  // Initializes the DMA
  %idx = arith.constant 0 : index

  %A = call @alloc_2d_filled_inc_f32(%c16, %c8, %cst_1) : (index, index, f32) -> (memref<?x?xf32>)
  %B = call @alloc_2d_filled_f32(%c8, %c32, %cst_1) : (index, index, f32) -> (memref<?x?xf32>)
  %C = call @alloc_2d_filled_f32(%c16, %c32, %cst_0) : (index, index, f32) -> (memref<?x?xf32>)
  %Ctmp = call @alloc_2d_filled_f32(%c16, %c32, %cst_0) : (index, index, f32) -> (memref<?x?xf32>)

  %A_typed = memref.cast %A: memref<?x?xf32> to memref<16x8xf32>
  %B_typed = memref.cast %B: memref<?x?xf32> to memref<8x32xf32>
  %C_typed = memref.cast %C: memref<?x?xf32> to memref<16x32xf32>
  %Ctmp_typed = memref.cast %Ctmp: memref<?x?xf32> to memref<16x32xf32>
  
  %in1 = memref.cast %A_typed: memref<16x8xf32> to memref<*xf32>
  %in2 = memref.cast %B_typed: memref<8x32xf32> to memref<*xf32>
  %out1 = memref.cast %C_typed: memref<16x32xf32> to memref<*xf32>
  %outtmp = memref.cast %Ctmp_typed: memref<16x32xf32> to memref<*xf32>

  call @print_memref_f32(%in1) : (memref<*xf32>) -> ()
  call @print_memref_f32(%in2) : (memref<*xf32>) -> ()

  call @matmul_call(%A_typed, %B_typed, %C_typed) : (memref<16x8xf32>, memref<8x32xf32>, memref<16x32xf32>) ->()

  call @print_memref_f32(%out1) : (memref<*xf32>) -> ()
  return
}

