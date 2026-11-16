        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_1358:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_1358
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
kl_1359:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_1360:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_1361:
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
ul_1362: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_1362
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_1362:
vl_1363:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_1363
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_1363          ; last u, V==1: the bias tap
bi_1363: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_1363
bt_1363: LDI  R4, 127
ag_1363: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1363            ; w == 0: nothing to accumulate
        BPL  mp_1363            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1363:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1363
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1363
        SUB  R3, R3, R5
mnc_1363: SUB  R7, R7, R6
        BNE  mn_1363
        JMP  mx_1363
mp_1363:  MOV  R7, R5            ; count = w
mpp_1363: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1363
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1363
        ADD  R3, R3, R5
mpc_1363: SUB  R7, R7, R6
        BNE  mpp_1363
mx_1363:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_1363: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_1363
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
        BNE  ul_1362
        LDI  R7, 8
        LDI  R5, 0x80
rq_1361:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1361
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1361: SHR  R3, R3
        BCC  rqb_1361
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1361: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1361
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1361
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1361
        CMP  R2, R7
        BNE  rqm_1361
        AND  R4, R1, R5
        BNE  rqm_1361            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_1361
rqm_1361: LDI  R5, 127
        JMP  rqd_1361
rqn_1361: LDI  R5, 0              ; ReLU: negative -> 0
rqd_1361:
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
        BNE  pl_1361
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_1360            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_1360
po_1360:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_1360: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_1360
        MOV  R1, R5
pa1_1360: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_1360
        MOV  R1, R5
pa2_1360: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_1360
        MOV  R1, R5
pa3_1360: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_1360
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_1360: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_1360
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
        BNE  kl_1359
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
fc_1365: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_1364:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1364            ; w == 0: nothing to accumulate
        BPL  mp_1364            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1364:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1364
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1364
        SUB  R3, R3, R5
mnc_1364: SUB  R7, R7, R6
        BNE  mn_1364
        JMP  mx_1364
mp_1364:  MOV  R7, R5            ; count = w
mpp_1364: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1364
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1364
        ADD  R3, R3, R5
mpc_1364: SUB  R7, R7, R6
        BNE  mpp_1364
mx_1364:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_1364
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_1366            ; w == 0: nothing to accumulate
        BPL  mp_1366            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_1366:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_1366
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_1366
        SUB  R3, R3, R5
mnc_1366: SUB  R7, R7, R6
        BNE  mn_1366
        JMP  mx_1366
mp_1366:  MOV  R7, R5            ; count = w
mpp_1366: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_1366
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_1366
        ADD  R3, R3, R5
mpc_1366: SUB  R7, R7, R6
        BNE  mpp_1366
mx_1366:
        LDI  R7, 8
        LDI  R5, 0x80
rq_1367:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_1367
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_1367: SHR  R3, R3
        BCC  rqb_1367
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_1367: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_1367
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_1367
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_1367
        CMP  R2, R7
        BNE  rqm_1367
        AND  R4, R1, R5
        BNE  rqm_1367            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_1367
rqm_1367: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_1367
rqn_1367: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_1367            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_1367
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_1367            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_1367:
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
        BNE  fc_1365
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_1368: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_1368           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_1368: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_1368
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
