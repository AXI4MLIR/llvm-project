; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+sse4.1 | FileCheck %s --check-prefix=SSE
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+avx | FileCheck %s --check-prefixes=AVX,AVX1
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+avx2 | FileCheck %s --check-prefixes=AVX,AVX2

declare <16 x i8> @llvm.x86.sse2.pavg.b(<16 x i8>, <16 x i8>) nounwind readnone
declare <8 x i16> @llvm.x86.sse2.pavg.w(<8 x i16>, <8 x i16>) nounwind readnone

; TODO: AVG(X,X) -> X
define <16 x i8> @combine_pavgb_self(<16 x i8> %a0) {
; SSE-LABEL: combine_pavgb_self:
; SSE:       # %bb.0:
; SSE-NEXT:    pavgb %xmm0, %xmm0
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_pavgb_self:
; AVX:       # %bb.0:
; AVX-NEXT:    vpavgb %xmm0, %xmm0, %xmm0
; AVX-NEXT:    retq
  %1 = call <16 x i8> @llvm.x86.sse2.pavg.b(<16 x i8> %a0, <16 x i8> %a0)
  ret <16 x i8> %1
}

; TODO: Failure to remove masks as we know the upper bits are zero
define <16 x i8> @combine_pavgw_knownbits(<8 x i16> %a0, <8 x i16> %a1, <8 x i16> %a2, <8 x i16> %a3) {
; SSE-LABEL: combine_pavgw_knownbits:
; SSE:       # %bb.0:
; SSE-NEXT:    movdqa {{.*#+}} xmm4 = [31,31,31,31,31,31,31,31]
; SSE-NEXT:    pand %xmm4, %xmm0
; SSE-NEXT:    pand %xmm4, %xmm1
; SSE-NEXT:    pavgw %xmm1, %xmm0
; SSE-NEXT:    pand %xmm4, %xmm2
; SSE-NEXT:    pand %xmm4, %xmm3
; SSE-NEXT:    pavgw %xmm2, %xmm3
; SSE-NEXT:    movdqa {{.*#+}} xmm1 = [255,0,255,0,255,0,255,0,255,0,255,0,255,0,255,0]
; SSE-NEXT:    pand %xmm1, %xmm3
; SSE-NEXT:    pand %xmm1, %xmm0
; SSE-NEXT:    packuswb %xmm3, %xmm0
; SSE-NEXT:    retq
;
; AVX1-LABEL: combine_pavgw_knownbits:
; AVX1:       # %bb.0:
; AVX1-NEXT:    vmovdqa {{.*#+}} xmm4 = [31,31,31,31,31,31,31,31]
; AVX1-NEXT:    vpand %xmm4, %xmm0, %xmm0
; AVX1-NEXT:    vpand %xmm4, %xmm1, %xmm1
; AVX1-NEXT:    vpavgw %xmm1, %xmm0, %xmm0
; AVX1-NEXT:    vpand %xmm4, %xmm2, %xmm1
; AVX1-NEXT:    vpand %xmm4, %xmm3, %xmm2
; AVX1-NEXT:    vpavgw %xmm2, %xmm1, %xmm1
; AVX1-NEXT:    vmovdqa {{.*#+}} xmm2 = [255,0,255,0,255,0,255,0,255,0,255,0,255,0,255,0]
; AVX1-NEXT:    vpand %xmm2, %xmm1, %xmm1
; AVX1-NEXT:    vpand %xmm2, %xmm0, %xmm0
; AVX1-NEXT:    vpackuswb %xmm1, %xmm0, %xmm0
; AVX1-NEXT:    retq
;
; AVX2-LABEL: combine_pavgw_knownbits:
; AVX2:       # %bb.0:
; AVX2-NEXT:    vmovdqa {{.*#+}} xmm4 = [31,31,31,31,31,31,31,31]
; AVX2-NEXT:    vpand %xmm4, %xmm0, %xmm0
; AVX2-NEXT:    vpand %xmm4, %xmm1, %xmm1
; AVX2-NEXT:    vpavgw %xmm1, %xmm0, %xmm0
; AVX2-NEXT:    vpand %xmm4, %xmm2, %xmm1
; AVX2-NEXT:    vpand %xmm4, %xmm3, %xmm2
; AVX2-NEXT:    vpavgw %xmm2, %xmm1, %xmm1
; AVX2-NEXT:    vpbroadcastw {{.*#+}} xmm2 = [255,255,255,255,255,255,255,255]
; AVX2-NEXT:    vpand %xmm2, %xmm1, %xmm1
; AVX2-NEXT:    vpand %xmm2, %xmm0, %xmm0
; AVX2-NEXT:    vpackuswb %xmm1, %xmm0, %xmm0
; AVX2-NEXT:    retq
  %m0 = and <8 x i16> %a0, <i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31>
  %m1 = and <8 x i16> %a1, <i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31>
  %m2 = and <8 x i16> %a2, <i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31>
  %m3 = and <8 x i16> %a3, <i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31, i16 31>
  %avg01 = tail call <8 x i16> @llvm.x86.sse2.pavg.w(<8 x i16> %m0, <8 x i16> %m1)
  %avg23 = tail call <8 x i16> @llvm.x86.sse2.pavg.w(<8 x i16> %m2, <8 x i16> %m3)
  %shuffle = shufflevector <8 x i16> %avg01, <8 x i16> %avg23, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
  %trunc = trunc <16 x i16> %shuffle to <16 x i8>
  ret <16 x i8> %trunc
}
