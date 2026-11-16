        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_87:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_87
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
kl_88:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_89:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_90:
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
ul_91: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_91
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_91:
vl_92:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_92
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_92          ; last u, V==1: the bias tap
bi_92: LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = *a_ptr
        JMP  ag_92
bt_92: LDI  R1, 127
ag_92: LDI  R0, 180
        LD   R7, [R0]
        LD   R2, [R7]          ; w = *w_ptr
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_92
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_92:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_92:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_92
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_92
mla_92: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_92: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_92
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_92
        ADD  R3, R3, R6        ; prod hi += 1
mlz_92: SUB  R5, R5, R6
        BNE  ml_92
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_92            ; w >= 0: acc += product
msa_92: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_92
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_92: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_92
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_92: JMP  msd_92
ma_92:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_92
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_92: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_92
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_92:
msd_92:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_92: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_92
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
        BNE  ul_91
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_90:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_90
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_90: SHR  R3, R3
        BCC  rqb_90
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_90: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_90
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_90
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_90
        CMP  R2, R7
        BNE  rqm_90
        AND  R4, R1, R5
        BNE  rqm_90            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_90
rqm_90: LDI  R5, 127
        JMP  rqd_90
rqn_90: LDI  R5, 0              ; ReLU: negative -> 0
rqd_90:
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
        BNE  pl_90
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_89            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_89
po_89:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_89: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_89
        MOV  R1, R5
pa1_89: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_89
        MOV  R1, R5
pa2_89: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_89
        MOV  R1, R5
pa3_89: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_89
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_89: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_89
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
        BNE  kl_88
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
fc_94: LDI  R0, 179
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
fj_93:  LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = feature
        IN   R2, 0x46          ; w = next streamed weight
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_93
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_93:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_93:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_93
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_93
mla_93: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_93: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_93
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_93
        ADD  R3, R3, R6        ; prod hi += 1
mlz_93: SUB  R5, R5, R6
        BNE  ml_93
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_93            ; w >= 0: acc += product
msa_93: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_93
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_93: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_93
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_93: JMP  msd_93
ma_93:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_93
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_93: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_93
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_93:
msd_93:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_93
        LDI  R1, 127
        IN   R2, 0x46
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_95
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_95:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_95:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_95
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_95
mla_95: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_95: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_95
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_95
        ADD  R3, R3, R6        ; prod hi += 1
mlz_95: SUB  R5, R5, R6
        BNE  ml_95
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_95            ; w >= 0: acc += product
msa_95: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_95
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_95: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_95
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_95: JMP  msd_95
ma_95:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_95
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_95: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_95
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_95:
msd_95:
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_96:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_96
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_96: SHR  R3, R3
        BCC  rqb_96
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_96: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_96
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_96
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_96
        CMP  R2, R7
        BNE  rqm_96
        AND  R4, R1, R5
        BNE  rqm_96            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_96
rqm_96: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_96
rqn_96: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_96            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_96
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_96            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_96:
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
        BNE  fc_94
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_97: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_97           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_97: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_97
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
