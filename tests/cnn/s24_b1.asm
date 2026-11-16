        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_879:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_879
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
kl_880:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_881:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_882:
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
ul_883: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_883
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_883:
vl_884:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_884
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_884          ; last u, V==1: the bias tap
bi_884: LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = *a_ptr
        JMP  ag_884
bt_884: LDI  R1, 127
ag_884: LDI  R0, 180
        LD   R7, [R0]
        LD   R2, [R7]          ; w = *w_ptr
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_884
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_884:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_884:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_884
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_884
mla_884: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_884: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_884
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_884
        ADD  R3, R3, R6        ; prod hi += 1
mlz_884: SUB  R5, R5, R6
        BNE  ml_884
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_884            ; w >= 0: acc += product
msa_884: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_884
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_884: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_884
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_884: JMP  msd_884
ma_884:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_884
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_884: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_884
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_884:
msd_884:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_884: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_884
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
        BNE  ul_883
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_882:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_882
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_882: SHR  R3, R3
        BCC  rqb_882
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_882: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_882
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_882
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_882
        CMP  R2, R7
        BNE  rqm_882
        AND  R4, R1, R5
        BNE  rqm_882            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_882
rqm_882: LDI  R5, 127
        JMP  rqd_882
rqn_882: LDI  R5, 0              ; ReLU: negative -> 0
rqd_882:
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
        BNE  pl_882
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_881            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_881
po_881:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_881: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_881
        MOV  R1, R5
pa1_881: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_881
        MOV  R1, R5
pa2_881: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_881
        MOV  R1, R5
pa3_881: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_881
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_881: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_881
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
        BNE  kl_880
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
fc_886: LDI  R0, 179
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
fj_885:  LDI  R0, 179
        LD   R7, [R0]
        LD   R1, [R7]          ; a = feature
        IN   R2, 0x46          ; w = next streamed weight
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_885
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_885:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_885:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_885
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_885
mla_885: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_885: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_885
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_885
        ADD  R3, R3, R6        ; prod hi += 1
mlz_885: SUB  R5, R5, R6
        BNE  ml_885
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_885            ; w >= 0: acc += product
msa_885: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_885
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_885: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_885
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_885: JMP  msd_885
ma_885:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_885
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_885: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_885
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_885:
msd_885:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_885
        LDI  R1, 127
        IN   R2, 0x46
        LDI  R0, 184
        ST   [R0], R2          ; remember w
        LDI  R5, 0
        CMP  R2, R5
        BPL  ms_887
        LDI  R5, 0xFF
        XOR  R2, R2, R5
        LDI  R5, 1
        ADD  R2, R2, R5        ; R2 = |w|
ms_887:  LDI  R3, 0
        LDI  R4, 0             ; product = 0
        LDI  R5, 8
ml_887:  SHL  R4, R4            ; C = old product lo bit 7
        BCC  mla_887
        SHL  R3, R3
        OR   R3, R3, R6        ; hi |= 1
        JMP  mlb_887
mla_887: SHL  R3, R3            ; C discarded (product < 2^15)
mlb_887: SHL  R2, R2            ; next multiplier bit -> C
        BCC  mlz_887
        ADD  R4, R4, R1        ; prod lo += a
        BCC  mlz_887
        ADD  R3, R3, R6        ; prod hi += 1
mlz_887: SUB  R5, R5, R6
        BNE  ml_887
        LDI  R0, 184
        LD   R7, [R0]
        LDI  R5, 0x80
        AND  R7, R7, R5
        BEQ  ma_887            ; w >= 0: acc += product
msa_887: LDI  R0, 181
        LD   R7, [R0]
        SUB  R7, R7, R4        ; acc lo -= prod lo (C=1: no borrow)
        ST   [R0], R7
        BCS  nmd_887
        ADD  R3, R3, R6        ; fold the lo borrow into prod hi
nmd_887: LDI  R0, 182
        LD   R7, [R0]
        SUB  R7, R7, R3        ; acc mid -= prod hi
        ST   [R0], R7
        BCS  nhi_887
        LDI  R0, 183
        LD   R7, [R0]
        SUB  R7, R7, R6        ; acc hi -= borrow
        ST   [R0], R7
nhi_887: JMP  msd_887
ma_887:  LDI  R0, 181
        LD   R7, [R0]
        ADD  R7, R7, R4        ; acc lo += prod lo (C=1: carry)
        ST   [R0], R7
        BCC  pmd_887
        ADD  R3, R3, R6        ; fold the lo carry into prod hi
pmd_887: LDI  R0, 182
        LD   R7, [R0]
        ADD  R7, R7, R3        ; acc mid += prod hi
        ST   [R0], R7
        BCC  phi_887
        LDI  R0, 183
        LD   R7, [R0]
        ADD  R7, R7, R6        ; acc hi += carry
        ST   [R0], R7
phi_887:
msd_887:
        LDI  R0, 181
        LD   R1, [R0]         ; shift-mul keeps the acc in DMEM
        LDI  R0, 182
        LD   R2, [R0]
        LDI  R0, 183
        LD   R3, [R0]
        LDI  R7, 8
        LDI  R5, 0x80
rq_888:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_888
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_888: SHR  R3, R3
        BCC  rqb_888
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_888: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_888
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_888
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_888
        CMP  R2, R7
        BNE  rqm_888
        AND  R4, R1, R5
        BNE  rqm_888            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_888
rqm_888: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_888
rqn_888: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_888            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_888
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_888            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_888:
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
        BNE  fc_886
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_889: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_889           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_889: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_889
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
