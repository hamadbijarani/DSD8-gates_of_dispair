        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_1142:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_1142
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
kl_1143:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_1144:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_1145:
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
ul_1146: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_1146
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_1146:
vl_1147:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_1147
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_1147          ; last u, V==1: the bias tap
bi_1147: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_1147
bt_1147: LDI  R4, 127
ag_1147: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1147            ; w == 0: nothing to accumulate
        BPL  mp_1147            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1147:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1147
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1147
        SUB  R3, R3, R5
mnc_1147: SUB  R7, R7, R6
        BNE  mn_1147
        JMP  mx_1147
mp_1147:  MOV  R7, R5            ; count = w
mpp_1147: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1147
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1147
        ADD  R3, R3, R5
mpc_1147: SUB  R7, R7, R6
        BNE  mpp_1147
mx_1147:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_1147: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_1147
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
        BNE  ul_1146
        LDI  R7, 8
        LDI  R5, 0x80
rq_1145:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1145
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1145: SHR  R3, R3
        BCC  rqb_1145
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1145: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1145
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1145
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1145
        CMP  R2, R7
        BNE  rqm_1145
        AND  R4, R1, R5
        BNE  rqm_1145            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_1145
rqm_1145: LDI  R5, 127
        JMP  rqd_1145
rqn_1145: LDI  R5, 0              ; ReLU: negative -> 0
rqd_1145:
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
        BNE  pl_1145
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_1144            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_1144
po_1144:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_1144: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_1144
        MOV  R1, R5
pa1_1144: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_1144
        MOV  R1, R5
pa2_1144: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_1144
        MOV  R1, R5
pa3_1144: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_1144
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_1144: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_1144
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
        BNE  kl_1143
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
fc_1149: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_1148:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1148            ; w == 0: nothing to accumulate
        BPL  mp_1148            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1148:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1148
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1148
        SUB  R3, R3, R5
mnc_1148: SUB  R7, R7, R6
        BNE  mn_1148
        JMP  mx_1148
mp_1148:  MOV  R7, R5            ; count = w
mpp_1148: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1148
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1148
        ADD  R3, R3, R5
mpc_1148: SUB  R7, R7, R6
        BNE  mpp_1148
mx_1148:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_1148
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1150            ; w == 0: nothing to accumulate
        BPL  mp_1150            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1150:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1150
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1150
        SUB  R3, R3, R5
mnc_1150: SUB  R7, R7, R6
        BNE  mn_1150
        JMP  mx_1150
mp_1150:  MOV  R7, R5            ; count = w
mpp_1150: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1150
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1150
        ADD  R3, R3, R5
mpc_1150: SUB  R7, R7, R6
        BNE  mpp_1150
mx_1150:
        LDI  R7, 8
        LDI  R5, 0x80
rq_1151:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1151
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1151: SHR  R3, R3
        BCC  rqb_1151
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1151: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1151
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1151
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1151
        CMP  R2, R7
        BNE  rqm_1151
        AND  R4, R1, R5
        BNE  rqm_1151            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_1151
rqm_1151: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_1151
rqn_1151: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_1151            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_1151
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_1151            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_1151:
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
        BNE  fc_1149
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_1152: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_1152           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_1152: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_1152
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
