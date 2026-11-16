        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_890:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_890
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
kl_891:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_892:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_893:
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
ul_894: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_894
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_894:
vl_895:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_895
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_895          ; last u, V==1: the bias tap
bi_895: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_895
bt_895: LDI  R4, 127
ag_895: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_895            ; w == 0: nothing to accumulate
        BPL  mp_895            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_895:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_895
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_895
        SUB  R3, R3, R5
mnc_895: SUB  R7, R7, R6
        BNE  mn_895
        JMP  mx_895
mp_895:  MOV  R7, R5            ; count = w
mpp_895: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_895
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_895
        ADD  R3, R3, R5
mpc_895: SUB  R7, R7, R6
        BNE  mpp_895
mx_895:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_895: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_895
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
        BNE  ul_894
        LDI  R7, 8
        LDI  R5, 0x80
rq_893:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_893
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_893: SHR  R3, R3
        BCC  rqb_893
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_893: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_893
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_893
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_893
        CMP  R2, R7
        BNE  rqm_893
        AND  R4, R1, R5
        BNE  rqm_893            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_893
rqm_893: LDI  R5, 127
        JMP  rqd_893
rqn_893: LDI  R5, 0              ; ReLU: negative -> 0
rqd_893:
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
        BNE  pl_893
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_892            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_892
po_892:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_892: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_892
        MOV  R1, R5
pa1_892: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_892
        MOV  R1, R5
pa2_892: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_892
        MOV  R1, R5
pa3_892: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_892
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_892: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_892
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
        BNE  kl_891
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
fc_897: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_896:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_896            ; w == 0: nothing to accumulate
        BPL  mp_896            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_896:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_896
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_896
        SUB  R3, R3, R5
mnc_896: SUB  R7, R7, R6
        BNE  mn_896
        JMP  mx_896
mp_896:  MOV  R7, R5            ; count = w
mpp_896: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_896
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_896
        ADD  R3, R3, R5
mpc_896: SUB  R7, R7, R6
        BNE  mpp_896
mx_896:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_896
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_898            ; w == 0: nothing to accumulate
        BPL  mp_898            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_898:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_898
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_898
        SUB  R3, R3, R5
mnc_898: SUB  R7, R7, R6
        BNE  mn_898
        JMP  mx_898
mp_898:  MOV  R7, R5            ; count = w
mpp_898: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_898
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_898
        ADD  R3, R3, R5
mpc_898: SUB  R7, R7, R6
        BNE  mpp_898
mx_898:
        LDI  R7, 8
        LDI  R5, 0x80
rq_899:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_899
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_899: SHR  R3, R3
        BCC  rqb_899
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_899: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_899
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_899
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_899
        CMP  R2, R7
        BNE  rqm_899
        AND  R4, R1, R5
        BNE  rqm_899            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_899
rqm_899: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_899
rqn_899: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_899            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_899
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_899            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_899:
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
        BNE  fc_897
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_900: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_900           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_900: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_900
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
