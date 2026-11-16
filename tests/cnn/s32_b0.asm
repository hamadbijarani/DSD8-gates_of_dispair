        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_1178:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_1178
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
kl_1179:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_1180:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_1181:
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
ul_1182: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_1182
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_1182:
vl_1183:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_1183
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_1183          ; last u, V==1: the bias tap
bi_1183: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_1183
bt_1183: LDI  R4, 127
ag_1183: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1183            ; w == 0: nothing to accumulate
        BPL  mp_1183            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1183:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1183
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1183
        SUB  R3, R3, R5
mnc_1183: SUB  R7, R7, R6
        BNE  mn_1183
        JMP  mx_1183
mp_1183:  MOV  R7, R5            ; count = w
mpp_1183: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1183
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1183
        ADD  R3, R3, R5
mpc_1183: SUB  R7, R7, R6
        BNE  mpp_1183
mx_1183:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_1183: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_1183
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
        BNE  ul_1182
        LDI  R7, 8
        LDI  R5, 0x80
rq_1181:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1181
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1181: SHR  R3, R3
        BCC  rqb_1181
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1181: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1181
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1181
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1181
        CMP  R2, R7
        BNE  rqm_1181
        AND  R4, R1, R5
        BNE  rqm_1181            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_1181
rqm_1181: LDI  R5, 127
        JMP  rqd_1181
rqn_1181: LDI  R5, 0              ; ReLU: negative -> 0
rqd_1181:
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
        BNE  pl_1181
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_1180            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_1180
po_1180:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_1180: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_1180
        MOV  R1, R5
pa1_1180: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_1180
        MOV  R1, R5
pa2_1180: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_1180
        MOV  R1, R5
pa3_1180: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_1180
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_1180: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_1180
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
        BNE  kl_1179
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
fc_1185: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_1184:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1184            ; w == 0: nothing to accumulate
        BPL  mp_1184            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1184:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1184
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1184
        SUB  R3, R3, R5
mnc_1184: SUB  R7, R7, R6
        BNE  mn_1184
        JMP  mx_1184
mp_1184:  MOV  R7, R5            ; count = w
mpp_1184: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1184
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1184
        ADD  R3, R3, R5
mpc_1184: SUB  R7, R7, R6
        BNE  mpp_1184
mx_1184:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_1184
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1186            ; w == 0: nothing to accumulate
        BPL  mp_1186            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1186:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1186
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1186
        SUB  R3, R3, R5
mnc_1186: SUB  R7, R7, R6
        BNE  mn_1186
        JMP  mx_1186
mp_1186:  MOV  R7, R5            ; count = w
mpp_1186: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1186
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1186
        ADD  R3, R3, R5
mpc_1186: SUB  R7, R7, R6
        BNE  mpp_1186
mx_1186:
        LDI  R7, 8
        LDI  R5, 0x80
rq_1187:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1187
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1187: SHR  R3, R3
        BCC  rqb_1187
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1187: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1187
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1187
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1187
        CMP  R2, R7
        BNE  rqm_1187
        AND  R4, R1, R5
        BNE  rqm_1187            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_1187
rqm_1187: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_1187
rqn_1187: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_1187            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_1187
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_1187            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_1187:
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
        BNE  fc_1185
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_1188: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_1188           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_1188: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_1188
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
