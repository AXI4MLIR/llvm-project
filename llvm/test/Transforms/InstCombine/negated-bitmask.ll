; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=instcombine -S | FileCheck %s

; PR53610 - sub(0,and(lshr(X,C1),1)) --> ashr(shl(X,(BW-1)-C1),BW-1)
; PR53610 - sub(C2,and(lshr(X,C1),1)) --> add(ashr(shl(X,(BW-1)-C1),BW-1),C2)

define i8 @neg_mask1_lshr(i8 %a0) {
; CHECK-LABEL: @neg_mask1_lshr(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr i8 [[A0:%.*]], 3
; CHECK-NEXT:    [[MASK:%.*]] = and i8 [[SHIFT]], 1
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw i8 0, [[MASK]]
; CHECK-NEXT:    ret i8 [[NEG]]
;
  %shift = lshr i8 %a0, 3
  %mask = and i8 %shift, 1
  %neg = sub i8 0, %mask
  ret i8 %neg
}

define i8 @sub_mask1_lshr(i8 %a0) {
; CHECK-LABEL: @sub_mask1_lshr(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr i8 [[A0:%.*]], 1
; CHECK-NEXT:    [[MASK:%.*]] = and i8 [[SHIFT]], 1
; CHECK-NEXT:    [[NEG:%.*]] = sub nuw nsw i8 10, [[MASK]]
; CHECK-NEXT:    ret i8 [[NEG]]
;
  %shift = lshr i8 %a0, 1
  %mask = and i8 %shift, 1
  %neg = sub i8 10, %mask
  ret i8 %neg
}

define <4 x i32> @neg_mask1_lshr_vector_uniform(<4 x i32> %a0) {
; CHECK-LABEL: @neg_mask1_lshr_vector_uniform(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr <4 x i32> [[A0:%.*]], <i32 3, i32 3, i32 3, i32 3>
; CHECK-NEXT:    [[MASK:%.*]] = and <4 x i32> [[SHIFT]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw <4 x i32> zeroinitializer, [[MASK]]
; CHECK-NEXT:    ret <4 x i32> [[NEG]]
;
  %shift = lshr <4 x i32> %a0, <i32 3, i32 3, i32 3, i32 3>
  %mask = and <4 x i32> %shift, <i32 1, i32 1, i32 1, i32 1>
  %neg = sub <4 x i32> zeroinitializer, %mask
  ret <4 x i32> %neg
}

define <4 x i32> @neg_mask1_lshr_vector_nonuniform(<4 x i32> %a0) {
; CHECK-LABEL: @neg_mask1_lshr_vector_nonuniform(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr <4 x i32> [[A0:%.*]], <i32 3, i32 4, i32 5, i32 6>
; CHECK-NEXT:    [[MASK:%.*]] = and <4 x i32> [[SHIFT]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw <4 x i32> zeroinitializer, [[MASK]]
; CHECK-NEXT:    ret <4 x i32> [[NEG]]
;
  %shift = lshr <4 x i32> %a0, <i32 3, i32 4, i32 5, i32 6>
  %mask = and <4 x i32> %shift, <i32 1, i32 1, i32 1, i32 1>
  %neg = sub <4 x i32> zeroinitializer, %mask
  ret <4 x i32> %neg
}

define <4 x i32> @sub_mask1_lshr_vector_nonuniform(<4 x i32> %a0) {
; CHECK-LABEL: @sub_mask1_lshr_vector_nonuniform(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr <4 x i32> [[A0:%.*]], <i32 3, i32 4, i32 5, i32 6>
; CHECK-NEXT:    [[MASK:%.*]] = and <4 x i32> [[SHIFT]], <i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw <4 x i32> <i32 5, i32 0, i32 -1, i32 65556>, [[MASK]]
; CHECK-NEXT:    ret <4 x i32> [[NEG]]
;
  %shift = lshr <4 x i32> %a0, <i32 3, i32 4, i32 5, i32 6>
  %mask = and <4 x i32> %shift, <i32 1, i32 1, i32 1, i32 1>
  %neg = sub <4 x i32> <i32 5, i32 0, i32 -1, i32 65556>, %mask
  ret <4 x i32> %neg
}

; Negative Test - wrong mask
define i8 @neg_mask2_lshr(i8 %a0) {
; CHECK-LABEL: @neg_mask2_lshr(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr i8 [[A0:%.*]], 3
; CHECK-NEXT:    [[MASK:%.*]] = and i8 [[SHIFT]], 2
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw i8 0, [[MASK]]
; CHECK-NEXT:    ret i8 [[NEG]]
;
  %shift = lshr i8 %a0, 3
  %mask = and i8 %shift, 2
  %neg = sub i8 0, %mask
  ret i8 %neg
}

; Negative Test - bad shift amount
define i8 @neg_mask2_lshr_outofbounds(i8 %a0) {
; CHECK-LABEL: @neg_mask2_lshr_outofbounds(
; CHECK-NEXT:    ret i8 poison
;
  %shift = lshr i8 %a0, 8
  %mask = and i8 %shift, 2
  %neg = sub i8 0, %mask
  ret i8 %neg
}

; Negative Test - non-constant shift amount
define <2 x i32> @neg_mask1_lshr_vector_var(<2 x i32> %a0, <2 x i32> %a1) {
; CHECK-LABEL: @neg_mask1_lshr_vector_var(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr <2 x i32> [[A0:%.*]], [[A1:%.*]]
; CHECK-NEXT:    [[MASK:%.*]] = and <2 x i32> [[SHIFT]], <i32 1, i32 1>
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw <2 x i32> zeroinitializer, [[MASK]]
; CHECK-NEXT:    ret <2 x i32> [[NEG]]
;
  %shift = lshr <2 x i32> %a0, %a1
  %mask = and <2 x i32> %shift, <i32 1, i32 1>
  %neg = sub <2 x i32> zeroinitializer, %mask
  ret <2 x i32> %neg
}

; Extra Use - mask
define i8 @neg_mask1_lshr_extrause_mask(i8 %a0) {
; CHECK-LABEL: @neg_mask1_lshr_extrause_mask(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr i8 [[A0:%.*]], 3
; CHECK-NEXT:    [[MASK:%.*]] = and i8 [[SHIFT]], 1
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw i8 0, [[MASK]]
; CHECK-NEXT:    call void @usei8(i8 [[MASK]])
; CHECK-NEXT:    ret i8 [[NEG]]
;
  %shift = lshr i8 %a0, 3
  %mask = and i8 %shift, 1
  %neg = sub i8 0, %mask
  call void @usei8(i8 %mask)
  ret i8 %neg
}

; Extra Use - shift
define <2 x i32> @neg_mask1_lshr_extrause_lshr(<2 x i32> %a0) {
; CHECK-LABEL: @neg_mask1_lshr_extrause_lshr(
; CHECK-NEXT:    [[SHIFT:%.*]] = lshr <2 x i32> [[A0:%.*]], <i32 3, i32 3>
; CHECK-NEXT:    [[MASK:%.*]] = and <2 x i32> [[SHIFT]], <i32 1, i32 1>
; CHECK-NEXT:    [[NEG:%.*]] = sub nsw <2 x i32> zeroinitializer, [[MASK]]
; CHECK-NEXT:    call void @usev2i32(<2 x i32> [[SHIFT]])
; CHECK-NEXT:    ret <2 x i32> [[NEG]]
;
  %shift = lshr <2 x i32> %a0, <i32 3, i32 3>
  %mask = and <2 x i32> %shift, <i32 1, i32 1>
  %neg = sub <2 x i32> zeroinitializer, %mask
  call void @usev2i32(<2 x i32> %shift)
  ret <2 x i32> %neg
}

declare void @usei8(i8)
declare void @usev2i32(<2 x i32>)
