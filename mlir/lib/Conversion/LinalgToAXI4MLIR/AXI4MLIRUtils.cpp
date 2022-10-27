//===- AXI4MLIRUtils.cpp - Shared functions during conversions --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/LinalgToAXI4MLIR/AXI4MLIRUtils.h"

#include "mlir/Dialect/Linalg/Transforms/Transforms.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

using namespace mlir;
using namespace mlir::linalg;

const StringLiteral kLinalgTransformMarker = "__internal_linalg_transform__";

struct LinalgOpChangeFilterPattern : public OpInterfaceRewritePattern<LinalgOp> {
  LinalgOpChangeFilterPattern(
      MLIRContext *context,
      LinalgTransformationFilter f = LinalgTransformationFilter(),
      PatternBenefit benefit = 1)
      : OpInterfaceRewritePattern<LinalgOp>(context, benefit),
        filter(std::move(f)) {}

  LinalgOpChangeFilterPattern(
      StringRef opName, MLIRContext *context,
      LinalgTransformationFilter f = LinalgTransformationFilter(),
      PatternBenefit benefit = 1)
      : OpInterfaceRewritePattern<LinalgOp>(context, benefit),
        filter(f.addOpNameFilter(opName)) {}

  LogicalResult matchAndRewrite(LinalgOp op,
                                PatternRewriter &rewriter) const override {
    if (failed(filter.checkAndNotify(rewriter, op)))
      return failure();
    filter.replaceLinalgTransformationFilter(rewriter, op);
    return success();
  }

private:
  /// LinalgTransformMarker handles special attribute manipulations.
  LinalgTransformationFilter filter;
};

/// Apply tiling patterns to matmul operations with the correct attribute
void mlir::applyPatterns(FuncOp funcOp,
                         const AccelTransformationOptions &options) {
  MLIRContext *ctx = funcOp.getContext();
  RewritePatternSet patterns(ctx);

  // Perform loop interchange with GenericOpInterchangePattern
  if (options.loopPermutation.size() > 0) {
    patterns.add<GenericOpInterchangePattern>(
        ctx, options.loopPermutation,
        LinalgTransformationFilter(StringAttr::get(ctx, "INTERCHANGE"),
                                   StringAttr::get(ctx, "MEM")));
  } else {
    // add pattern to change attribute
    patterns.add<LinalgOpChangeFilterPattern>(
        MatmulOp::getOperationName(), ctx,
        LinalgTransformationFilter(StringAttr::get(ctx, "INTERCHANGE"),
                                   StringAttr::get(ctx, "MEM")));
  }

  // z7020 ARM A9 core specs
  // L1:  32KB 4-way set-associative (instruction and data caches independent
  // for each CPU)
  // L2: 512KB 8-way set-associative (shared between CPUs)

  // Pynq-z2
  // z7020 chip
  // 512MB DDR3 with 16-bit bus @ 1050Mbps

  // Pynq-z2
  // z7020 chip
  // 512 Mbyte DDR3

  //      M       N       K   ELEMSize   Total bytes    Total KB
  //  1,024   1,024   1,024      4        12,582,912   12,288.00
  //    512     512     512      4         3,145,728    3,072.00
  //    256     256     256      4           786,432      768.00
  //    128     128     128      4           196,608      192.00
  //     64      64      64      4            49,152       48.00
  //     32      32      32      4            12,288       12.00
  //     16      16      16      4             3,072        3.00
  //      8       8       8      4               768        0.75
  //      4       4       4      4               192        0.19
  //      2       2       2      4                48        0.05

  if (options.tileSizes.size() > 0) {

    unsigned tileIdx = 0;

    if (options.numberOfCaches == 3) {
      addTilingPatternToSet(
          patterns, ctx, "MEM", "L3", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;

      addTilingPatternToSet(
          patterns, ctx, "L3", "L2", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;

      addTilingPatternToSet(
          patterns, ctx, "L2", "L1", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;
    }

    if (options.numberOfCaches == 2) {
      addTilingPatternToSet(
          patterns, ctx, "MEM", "L2", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;

      addTilingPatternToSet(
          patterns, ctx, "L2", "L1", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;
    }

    if (options.numberOfCaches == 1) {
      addTilingPatternToSet(
          patterns, ctx, "MEM", "L1", options.tileSizes[tileIdx + 0],
          options.tileSizes[tileIdx + 1], options.tileSizes[tileIdx + 2]);
      tileIdx += 3;
    }

  } else {
    // If no tile sizes were selected
    addTilingPatternToSet(patterns, ctx, "MEM", "L1", 4096, 4096, 4096);
  }

  // At this point relevant operations will have the L1 marker
  // Only accelerator tiling is missing
  if (options.tileSize > 1) {
    patterns.add<LinalgTilingPattern>(
        MatmulOp::getOperationName(), ctx,
        LinalgTilingOptions().setTileSizes(
            {options.tileSize, options.tileSize, options.tileSize}),
        LinalgTransformationFilter(StringAttr::get(ctx, "L1"),
                                   StringAttr::get(ctx, "ACCEL")));

  } else {
    patterns.add<LinalgTilingPattern>(
        MatmulOp::getOperationName(), ctx,
        LinalgTilingOptions().setTileSizes({4, 4, 4}),
        LinalgTransformationFilter(StringAttr::get(ctx, "L1"),
                                   StringAttr::get(ctx, "ACCEL")));
  }

  (void)applyPatternsAndFoldGreedily(funcOp, std::move(patterns));
}

void mlir::addTilingPatternToSet(RewritePatternSet &patterns, MLIRContext *ctx,
                                 const StringRef &srcAttrName,
                                 const StringRef &dstAttrName,
                                 const unsigned &tsd0, const unsigned &tsd1,
                                 const unsigned &tsd2) {
  patterns.add<LinalgTilingPattern>(
      MatmulOp::getOperationName(), ctx,
      LinalgTilingOptions().setTileSizes({tsd0, tsd1, tsd2}),
      LinalgTransformationFilter(StringAttr::get(ctx, srcAttrName),
                                 StringAttr::get(ctx, dstAttrName)));
}

void AccelTransformationOptions::dump() const {
  llvm::errs() << "tileSize: " << tileSize << "\n"
               << "dmaAddress\t\t " << dmaAddress << "\n"
               << "dmaInputAddress\t\t " << dmaInputAddress << "\n"
               << "dmaInputBufferSize\t " << dmaInputBufferSize << "\n"
               << "dmaOutputAddress\t " << dmaOutputAddress << "\n"
               << "dmaOutputBufferSize\t " << dmaOutputBufferSize << "\n"
               << "flowCpuAcc\t\t " << flowCpuAcc << "\n"
               << "numberOfCaches\t\t " << numberOfCaches
               << "\n"
               // << "cacheSizes\t\t " << cacheSizes << "\n"
               // << "tileSizes\t\t " << tileSizes << "\n"
               << "elementSize\t\t " << elementSize
               << "\n"
               // << "loopPermutation\t\t " << loopPermutation << "\n"
               << "anchorFuncName\t\t " << anchorFuncName << "\n"
               << "anchorOpName\t\t " << anchorOpName << "\n"
               << "opcodeMap\t\t " << opcodeMap << "\n"
               << "initOpcodes\t\t " << initOpcodes << "\n"
               << "opcodeFlow\t\t " << opcodeFlow << "\n";
}