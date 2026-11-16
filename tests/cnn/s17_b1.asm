        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_627:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_627
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
kl_628:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_629:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_630:
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
ul_631: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_631
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_631:
vl_632:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_632
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_632          ; last u, V==1: the bias tap
bi_632: LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = *a_ptr
        JMP  ag_632
bt_632: LDI  R1, 127
ag_632: LDI  R0, 180
        LD   R7, [R0]
        LD   R2, [R7]          ; w = *w_ptr
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_632
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_632:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_632:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_632
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_632
mla_632: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_632: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_632
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_632
        ADD  R3, R3, R6        ; prod hi += 1
mlz_632: SUB  R5, R5, R6
        BNE  ml_632
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_632            ; w >= 0: acc += product
msa_632: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_632
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_632: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_632
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_632: JMP  msd_632
ma_632:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_632
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_632: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_632
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_632:
msd_632:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_632: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_632
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
        BNE  ul_631
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_630:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_630
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_630: SHR  R3, R3
        BCC  rqb_630
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_630: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_630
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_630
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_630
        CMP  R2, R7
        BNE  rqm_630
        AND  R4, R1, R5
        BNE  rqm_630            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_630
rqm_630: LDI  R5, 127
        JMP  rqd_630
rqn_630: LDI  R5, 0              ; ReLU: negative -> 0
rqd_630:
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
        BNE  pl_630
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_629            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_629
po_629:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_629: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_629
        MOV  R1, R5
pa1_629: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_629
        MOV  R1, R5
pa2_629: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_629
        MOV  R1, R5
pa3_629: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_629
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_629: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_629
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
        BNE  kl_628
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
fc_634: LDI  R0, 179
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
fj_633:  LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = feature
        IN   R2, 0x46          ; w = next streamed weight
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_633
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_633:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_633:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_633
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_633
mla_633: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_633: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_633
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_633
        ADD  R3, R3, R6        ; prod hi += 1
mlz_633: SUB  R5, R5, R6
        BNE  ml_633
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_633            ; w >= 0: acc += product
msa_633: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_633
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_633: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_633
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_633: JMP  msd_633
ma_633:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_633
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_633: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_633
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_633:
msd_633:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_633
        LDI  R1, 127
        IN   R2, 0x46
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_635
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_635:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_635:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_635
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_635
mla_635: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_635: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_635
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_635
        ADD  R3, R3, R6        ; prod hi += 1
mlz_635: SUB  R5, R5, R6
        BNE  ml_635
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_635            ; w >= 0: acc += product
msa_635: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_635
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_635: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_635
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_635: JMP  msd_635
ma_635:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_635
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_635: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_635
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_635:
msd_635:
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_636:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_636
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_636: SHR  R3, R3
        BCC  rqb_636
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_636: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_636
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_636
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_636
        CMP  R2, R7
        BNE  rqm_636
        AND  R4, R1, R5
        BNE  rqm_636            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_636
rqm_636: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_636
rqn_636: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_636            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_636
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_636            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_636:
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
        BNE  fc_634
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_637: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_637           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_637: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_637
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
