        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_206:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_206
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
kl_207:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_208:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_209:
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
ul_210: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_210
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_210:
vl_211:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_211
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_211          ; last u, V==1: the bias tap
bi_211: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_211
bt_211: LDI  R4, 127
ag_211: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_211            ; w == 0: nothing to accumulate
        BPL  mp_211            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_211:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_211
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_211
        SUB  R3, R3, R5
mnc_211: SUB  R7, R7, R6
        BNE  mn_211
        JMP  mx_211
mp_211:  MOV  R7, R5            ; count = w
mpp_211: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_211
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_211
        ADD  R3, R3, R5
mpc_211: SUB  R7, R7, R6
        BNE  mpp_211
mx_211:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_211: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_211
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
        BNE  ul_210
        LDI  R7, 8
        LDI  R5, 0x80
rq_209:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_209
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_209: SHR  R3, R3
        BCC  rqb_209
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_209: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_209
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_209
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_209
        CMP  R2, R7
        BNE  rqm_209
        AND  R4, R1, R5
        BNE  rqm_209            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_209
rqm_209: LDI  R5, 127
        JMP  rqd_209
rqn_209: LDI  R5, 0              ; ReLU: negative -> 0
rqd_209:
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
        BNE  pl_209
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_208            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_208
po_208:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_208: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_208
        MOV  R1, R5
pa1_208: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_208
        MOV  R1, R5
pa2_208: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_208
        MOV  R1, R5
pa3_208: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_208
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_208: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_208
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
        BNE  kl_207
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
fc_213: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_212:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_212            ; w == 0: nothing to accumulate
        BPL  mp_212            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_212:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_212
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_212
        SUB  R3, R3, R5
mnc_212: SUB  R7, R7, R6
        BNE  mn_212
        JMP  mx_212
mp_212:  MOV  R7, R5            ; count = w
mpp_212: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_212
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_212
        ADD  R3, R3, R5
mpc_212: SUB  R7, R7, R6
        BNE  mpp_212
mx_212:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_212
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_214            ; w == 0: nothing to accumulate
        BPL  mp_214            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_214:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_214
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_214
        SUB  R3, R3, R5
mnc_214: SUB  R7, R7, R6
        BNE  mn_214
        JMP  mx_214
mp_214:  MOV  R7, R5            ; count = w
mpp_214: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_214
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_214
        ADD  R3, R3, R5
mpc_214: SUB  R7, R7, R6
        BNE  mpp_214
mx_214:
        LDI  R7, 8
        LDI  R5, 0x80
rq_215:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_215
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_215: SHR  R3, R3
        BCC  rqb_215
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_215: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_215
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_215
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_215
        CMP  R2, R7
        BNE  rqm_215
        AND  R4, R1, R5
        BNE  rqm_215            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_215
rqm_215: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_215
rqn_215: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_215            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_215
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_215            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_215:
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
        BNE  fc_213
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_216: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_216           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_216: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_216
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
