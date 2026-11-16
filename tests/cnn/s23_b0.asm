        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_854:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_854
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
kl_855:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_856:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_857:
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
ul_858: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_858
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_858:
vl_859:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_859
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_859          ; last u, V==1: the bias tap
bi_859: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_859
bt_859: LDI  R4, 127
ag_859: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_859            ; w == 0: nothing to accumulate
        BPL  mp_859            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_859:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_859
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_859
        SUB  R3, R3, R5
mnc_859: SUB  R7, R7, R6
        BNE  mn_859
        JMP  mx_859
mp_859:  MOV  R7, R5            ; count = w
mpp_859: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_859
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_859
        ADD  R3, R3, R5
mpc_859: SUB  R7, R7, R6
        BNE  mpp_859
mx_859:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_859: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_859
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
        BNE  ul_858
        LDI  R7, 8
        LDI  R5, 0x80
rq_857:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_857
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_857: SHR  R3, R3
        BCC  rqb_857
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_857: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_857
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_857
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_857
        CMP  R2, R7
        BNE  rqm_857
        AND  R4, R1, R5
        BNE  rqm_857            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_857
rqm_857: LDI  R5, 127
        JMP  rqd_857
rqn_857: LDI  R5, 0              ; ReLU: negative -> 0
rqd_857:
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
        BNE  pl_857
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_856            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_856
po_856:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_856: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_856
        MOV  R1, R5
pa1_856: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_856
        MOV  R1, R5
pa2_856: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_856
        MOV  R1, R5
pa3_856: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_856
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_856: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_856
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
        BNE  kl_855
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
fc_861: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_860:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_860            ; w == 0: nothing to accumulate
        BPL  mp_860            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_860:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_860
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_860
        SUB  R3, R3, R5
mnc_860: SUB  R7, R7, R6
        BNE  mn_860
        JMP  mx_860
mp_860:  MOV  R7, R5            ; count = w
mpp_860: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_860
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_860
        ADD  R3, R3, R5
mpc_860: SUB  R7, R7, R6
        BNE  mpp_860
mx_860:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_860
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_862            ; w == 0: nothing to accumulate
        BPL  mp_862            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_862:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_862
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_862
        SUB  R3, R3, R5
mnc_862: SUB  R7, R7, R6
        BNE  mn_862
        JMP  mx_862
mp_862:  MOV  R7, R5            ; count = w
mpp_862: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_862
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_862
        ADD  R3, R3, R5
mpc_862: SUB  R7, R7, R6
        BNE  mpp_862
mx_862:
        LDI  R7, 8
        LDI  R5, 0x80
rq_863:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_863
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_863: SHR  R3, R3
        BCC  rqb_863
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_863: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_863
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_863
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_863
        CMP  R2, R7
        BNE  rqm_863
        AND  R4, R1, R5
        BNE  rqm_863            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_863
rqm_863: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_863
rqn_863: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_863            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_863
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_863            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_863:
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
        BNE  fc_861
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_864: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_864           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_864: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_864
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
