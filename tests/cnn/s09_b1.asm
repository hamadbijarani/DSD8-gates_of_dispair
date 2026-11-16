        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_339:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_339
        LDI  R0, 176
        LDI  R5, 64
        ST   [R0], R5
        LDI  R0, 188
        LDI  R5, 128
        ST   [R0], R5
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5
        LDI  R0, 189
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LDI  R5, 4
        ST   [R0], R5
        LDI  R0, 1
        OUT  0x02, R0          ; timing marker
        LDI  R6, 1
        LDI  R0, 178
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LDI  R5, 4
        ST   [R0], R5
kl_340:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_341:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_342:
        LDI  R7, 0
        LDI  R0, 181
        ST   [R0], R7
        LDI  R0, 182
        ST   [R0], R7
        LDI  R0, 183
        ST   [R0], R7
        LDI  R0, 176
        LD   R7, [R0]
        LDI  R0, 180
        ST   [R0], R7          ; w-ptr = kernel base (10 weights)
        LDI  R0, 178
        LD   R7, [R0]
        LDI  R0, 179
        ST   [R0], R7          ; a-ptr = row base
        LDI  R0, 193
        LDI  R7, 3
        ST   [R0], R7
ul_343: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_343
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_343:
vl_344:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_344
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_344          ; last u, V==1: the bias tap
bi_344: LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = *a_ptr
        JMP  ag_344
bt_344: LDI  R1, 127
ag_344: LDI  R0, 180
        LD   R7, [R0]
        LD   R2, [R7]          ; w = *w_ptr
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_344
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_344:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_344:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_344
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_344
mla_344: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_344: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_344
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_344
        ADD  R3, R3, R6        ; prod hi += 1
mlz_344: SUB  R5, R5, R6
        BNE  ml_344
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_344            ; w >= 0: acc += product
msa_344: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_344
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_344: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_344
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_344: JMP  msd_344
ma_344:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_344
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_344: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_344
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_344:
msd_344:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_344: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_344
        LDI  R0, 179
        LD   R7, [R0]
        LDI  R5, 5
        ADD  R7, R7, R5        ; skip to the next image row
        LDI  R0, 179
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  ul_343
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_342:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_342
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_342: SHR  R3, R3
        BCC  rqb_342
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_342: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_342
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_342
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_342
        CMP  R2, R7
        BNE  rqm_342
        AND  R4, R1, R5
        BNE  rqm_342            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_342
rqm_342: LDI  R5, 127
        JMP  rqd_342
rqn_342: LDI  R5, 0              ; ReLU: negative -> 0
rqd_342:
        LDI  R0, 177
        LD   R7, [R0]
        ST   [R7], R5          ; store conv+ReLU pixel
        ADD  R7, R7, R6
        LDI  R0, 177
        ST   [R0], R7
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next pixel's row base
        ST   [R0], R7
        LDI  R0, 185
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  pl_342
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_341            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_341
po_341:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_341: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_341
        MOV  R1, R5
pa1_341: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_341
        MOV  R1, R5
pa2_341: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_341
        MOV  R1, R5
pa3_341: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_341
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_341: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_341
        LDI  R0, 176
        LD   R7, [R0]
        LDI  R5, 10
        ADD  R7, R7, R5        ; next kernel's weight base
        ST   [R0], R7
        LDI  R0, 178
        LDI  R5, 0
        ST   [R0], R5
        LDI  R0, 187
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  kl_340
        LDI  R0, 190
        LDI  R5, 4
        ST   [R0], R5
        LDI  R0, 192
        LDI  R5, 168
        ST   [R0], R5
        LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5
        LDI  R6, 1
fc_346: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R7, 0
        LDI  R0, 181
        ST   [R0], R7
        LDI  R0, 182
        ST   [R0], R7
        LDI  R0, 183
        ST   [R0], R7
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_345:  LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = feature
        IN   R2, 0x46          ; w = next streamed weight
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_345
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_345:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_345:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_345
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_345
mla_345: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_345: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_345
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_345
        ADD  R3, R3, R6        ; prod hi += 1
mlz_345: SUB  R5, R5, R6
        BNE  ml_345
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_345            ; w >= 0: acc += product
msa_345: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_345
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_345: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_345
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_345: JMP  msd_345
ma_345:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_345
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_345: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_345
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_345:
msd_345:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_345
        LDI  R1, 127
        IN   R2, 0x46
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_347
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_347:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_347:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_347
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_347
mla_347: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_347: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_347
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_347
        ADD  R3, R3, R6        ; prod hi += 1
mlz_347: SUB  R5, R5, R6
        BNE  ml_347
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_347            ; w >= 0: acc += product
msa_347: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_347
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_347: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_347
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_347: JMP  msd_347
ma_347:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_347
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_347: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_347
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_347:
msd_347:
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_348:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_348
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_348: SHR  R3, R3
        BCC  rqb_348
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_348: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_348
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_348
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_348
        CMP  R2, R7
        BNE  rqm_348
        AND  R4, R1, R5
        BNE  rqm_348            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_348
rqm_348: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_348
rqn_348: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_348            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_348
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_348            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_348:
        LDI  R0, 192
        LD   R7, [R0]
        ST   [R7], R5          ; store logit
        ADD  R7, R7, R6
        LDI  R0, 192
        ST   [R0], R7
        LDI  R0, 190
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fc_346
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_349: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_349           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_349: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_349
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
