        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_134:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_134
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
kl_135:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_136:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_137:
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
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
ul_138: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_138
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_138:
vl_139:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_139
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_139          ; last u, V==1: the bias tap
bi_139: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_139
bt_139: LDI  R4, 127
ag_139: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_139            ; w == 0: nothing to accumulate
        BPL  mp_139            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_139:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_139
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_139
        SUB  R3, R3, R5
mnc_139: SUB  R7, R7, R6
        BNE  mn_139
        JMP  mx_139
mp_139:  MOV  R7, R5            ; count = w
mpp_139: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_139
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_139
        ADD  R3, R3, R5
mpc_139: SUB  R7, R7, R6
        BNE  mpp_139
mx_139:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_139: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_139
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
        BNE  ul_138
        LDI  R7, 8
        LDI  R5, 0x80
rq_137:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_137
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_137: SHR  R3, R3
        BCC  rqb_137
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_137: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_137
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_137
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_137
        CMP  R2, R7
        BNE  rqm_137
        AND  R4, R1, R5
        BNE  rqm_137            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_137
rqm_137: LDI  R5, 127
        JMP  rqd_137
rqn_137: LDI  R5, 0              ; ReLU: negative -> 0
rqd_137:
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
        BNE  pl_137
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_136            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_136
po_136:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_136: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_136
        MOV  R1, R5
pa1_136: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_136
        MOV  R1, R5
pa2_136: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_136
        MOV  R1, R5
pa3_136: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_136
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_136: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_136
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
        BNE  kl_135
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
fc_141: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_140:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_140            ; w == 0: nothing to accumulate
        BPL  mp_140            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_140:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_140
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_140
        SUB  R3, R3, R5
mnc_140: SUB  R7, R7, R6
        BNE  mn_140
        JMP  mx_140
mp_140:  MOV  R7, R5            ; count = w
mpp_140: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_140
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_140
        ADD  R3, R3, R5
mpc_140: SUB  R7, R7, R6
        BNE  mpp_140
mx_140:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_140
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_142            ; w == 0: nothing to accumulate
        BPL  mp_142            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_142:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_142
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_142
        SUB  R3, R3, R5
mnc_142: SUB  R7, R7, R6
        BNE  mn_142
        JMP  mx_142
mp_142:  MOV  R7, R5            ; count = w
mpp_142: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_142
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_142
        ADD  R3, R3, R5
mpc_142: SUB  R7, R7, R6
        BNE  mpp_142
mx_142:
        LDI  R7, 8
        LDI  R5, 0x80
rq_143:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_143
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_143: SHR  R3, R3
        BCC  rqb_143
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_143: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_143
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_143
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_143
        CMP  R2, R7
        BNE  rqm_143
        AND  R4, R1, R5
        BNE  rqm_143            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_143
rqm_143: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_143
rqn_143: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_143            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_143
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_143            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_143:
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
        BNE  fc_141
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_144: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_144           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_144: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_144
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
