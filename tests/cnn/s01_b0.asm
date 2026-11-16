        LDI  R4, 1
        LDI  R6, 0
        LDI  R7, 104
gi_62:  IN   R5, 0x45          ; next stream byte (0x45/0x46 share
                               ;  one pointer: 64 img + 40 convW)
        ST   [R6], R5
        ADD  R6, R6, R4
        SUB  R7, R7, R4
        BNE  gi_62
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
kl_63:  LDI  R0, 186
        LDI  R5, 6
        ST   [R0], R5
rl_64:  LDI  R0, 185
        LDI  R5, 6
        ST   [R0], R5
pl_65:
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
ul_66: LDI  R0, 194
        LDI  R7, 3
        ST   [R0], R7
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  vg_66
        LDI  R0, 194
        LDI  R7, 4
        ST   [R0], R7          ; last u: its 4th tap is the bias
vg_66:
vl_67:
        LDI  R0, 193
        LD   R7, [R0]
        CMP  R7, R6
        BNE  bi_67
        LDI  R0, 194
        LD   R7, [R0]
        CMP  R7, R6
        BEQ  bt_67          ; last u, V==1: the bias tap
bi_67: LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = *a_ptr
        JMP  ag_67
bt_67: LDI  R4, 127
ag_67: LDI  R0, 180
        LD   R7, [R0]
        LD   R5, [R7]          ; w = *w_ptr
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_67            ; w == 0: nothing to accumulate
        BPL  mp_67            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_67:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_67
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_67
        SUB  R3, R3, R5
mnc_67: SUB  R7, R7, R6
        BNE  mn_67
        JMP  mx_67
mp_67:  MOV  R7, R5            ; count = w
mpp_67: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_67
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_67
        ADD  R3, R3, R5
mpc_67: SUB  R7, R7, R6
        BNE  mpp_67
mx_67:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; both pointers advance on every tap
        ST   [R0], R7
aw_67: LDI  R0, 180
        LD   R7, [R0]
        ADD  R7, R7, R6
        ST   [R0], R7
        LDI  R0, 194
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  vl_67
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
        BNE  ul_66
        LDI  R7, 8
        LDI  R5, 0x80
rq_65:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_65
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_65: SHR  R3, R3
        BCC  rqb_65
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_65: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_65
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_65
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_65
        CMP  R2, R7
        BNE  rqm_65
        AND  R4, R1, R5
        BNE  rqm_65            ; lo >= 128
        MOV  R5, R1             ; 0..127 passes through
        JMP  rqd_65
rqm_65: LDI  R5, 127
        JMP  rqd_65
rqn_65: LDI  R5, 0              ; ReLU: negative -> 0
rqd_65:
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
        BNE  pl_65
        LDI  R4, 1
        LDI  R0, 189
        LD   R7, [R0]
        XOR  R7, R7, R6
        ST   [R0], R7
        BEQ  po_64            ; odd row done: pool the pair
        LDI  R0, 177
        LDI  R5, 118
        ST   [R0], R5          ; even row done: next row -> ROWB
        JMP  wr_64
po_64:
        LDI  R3, 112
        LDI  R7, 118
        LDI  R0, 188
        LD   R6, [R0]
        LDI  R2, 3
plp_64: LD   R1, [R3]
        ADD  R3, R3, R4
        LD   R5, [R3]
        CMP  R1, R5
        BCS  pa1_64
        MOV  R1, R5
pa1_64: LD   R5, [R7]
        CMP  R1, R5
        BCS  pa2_64
        MOV  R1, R5
pa2_64: ADD  R7, R7, R4
        LD   R5, [R7]
        CMP  R1, R5
        BCS  pa3_64
        MOV  R1, R5
pa3_64: ST   [R6], R1
        ADD  R6, R6, R4
        ADD  R3, R3, R4
        ADD  R7, R7, R4
        SUB  R2, R2, R4
        BNE  plp_64
        LDI  R0, 188
        ST   [R0], R6
        LDI  R0, 177
        LDI  R5, 112
        ST   [R0], R5          ; odd row done: next row -> ROWA
wr_64: LDI  R6, 1
        LDI  R0, 178
        LD   R7, [R0]
        ADD  R7, R7, R4
        ADD  R7, R7, R4        ; next row starts 2 bytes later
        ST   [R0], R7
        LDI  R0, 186
        LD   R7, [R0]
        SUB  R7, R7, R4
        ST   [R0], R7
        BNE  rl_64
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
        BNE  kl_63
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
fc_69: LDI  R0, 179
        LDI  R5, 128
        ST   [R0], R5          ; features restart for each class
        LDI  R1, 0
        LDI  R2, 0
        LDI  R3, 0
        LDI  R0, 191
        LDI  R5, 36
        ST   [R0], R5
fj_68:  LDI  R0, 179
        LD   R7, [R0]
        LD   R4, [R7]          ; a = feature
        IN   R5, 0x46          ; w = next streamed weight
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_68            ; w == 0: nothing to accumulate
        BPL  mp_68            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_68:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_68
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_68
        SUB  R3, R3, R5
mnc_68: SUB  R7, R7, R6
        BNE  mn_68
        JMP  mx_68
mp_68:  MOV  R7, R5            ; count = w
mpp_68: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_68
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_68
        ADD  R3, R3, R5
mpc_68: SUB  R7, R7, R6
        BNE  mpp_68
mx_68:
        LDI  R0, 179
        LD   R7, [R0]
        ADD  R7, R7, R6        ; next feature
        ST   [R0], R7
        LDI  R0, 191
        LD   R7, [R0]
        SUB  R7, R7, R6
        ST   [R0], R7
        BNE  fj_68
        LDI  R4, 127
        IN   R5, 0x46
        LDI  R0, 0
        CMP  R5, R0
        BEQ  mx_70            ; w == 0: nothing to accumulate
        BPL  mp_70            ; w > 0: add loop
        LDI  R0, 0xFF
        XOR  R5, R5, R0
        LDI  R0, 1
        ADD  R5, R5, R0        ; R5 = |w| >= 1
        MOV  R7, R5            ; count = |w|
mn_70:  SUB  R1, R1, R4        ; acc -= a
        BCS  mnc_70
        LDI  R5, 1
        SUB  R2, R2, R5
        BCS  mnc_70
        SUB  R3, R3, R5
mnc_70: SUB  R7, R7, R6
        BNE  mn_70
        JMP  mx_70
mp_70:  MOV  R7, R5            ; count = w
mpp_70: ADD  R1, R1, R4        ; acc += a
        BCC  mpc_70
        LDI  R5, 1
        ADD  R2, R2, R5
        BCC  mpc_70
        ADD  R3, R3, R5
mpc_70: SUB  R7, R7, R6
        BNE  mpp_70
mx_70:
        LDI  R7, 8
        LDI  R5, 0x80
rq_71:  AND  R4, R3, R5        ; keep sign bit of hi
        SHR  R1, R1
        SHR  R2, R2
        BCC  rqa_71
        OR   R1, R1, R5         ; mid bit 0 moves into lo bit 7
rqa_71: SHR  R3, R3
        BCC  rqb_71
        OR   R2, R2, R5         ; hi bit 0 moves into mid bit 7
rqb_71: OR   R3, R3, R4         ; refill the sign bit
        SUB  R7, R7, R6
        BNE  rq_71
        AND  R4, R3, R5         ; sign of the shifted value
        BNE  rqn_71
        CMP  R3, R7             ; hi == 0?
        BNE  rqm_71
        CMP  R2, R7
        BNE  rqm_71
        AND  R4, R1, R5
        BNE  rqm_71            ; lo >= 128
        OR   R5, R1, R5         ; 0..127 -> 128..255
        JMP  rqd_71
rqm_71: LDI  R5, 0xFF           ; +127 -> 0xFF
        JMP  rqd_71
rqn_71: LDI  R5, 0
        LDI  R4, 0xFF
        CMP  R3, R4
        BNE  rqd_71            ; < -256: 0x00 (-128)
        CMP  R2, R4
        BNE  rqd_71
        LDI  R4, 0x80
        AND  R4, R1, R4         ; mask in R4: R5 holds the result
        BEQ  rqd_71            ; -256..-129: keep 0x00
        XOR  R5, R1, R4         ; -128..-1 -> 0..127
rqd_71:
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
        BNE  fc_69
        LDI  R0, 2
        OUT  0x02, R0          ; timing marker
        LDI  R7, 168
        LD   R1, [R7]          ; best = logit 0
        LDI  R6, 0             ; best class
        LDI  R5, 1             ; candidate class
        LDI  R4, 1
am_72: ADD  R7, R7, R4
        LD   R2, [R7]
        CMP  R1, R2
        BCS  ask_72           ; ties keep the lower class
        MOV  R1, R2
        MOV  R6, R5
ask_72: ADD  R5, R5, R4
        LDI  R0, 4
        CMP  R5, R0
        BNE  am_72
        OUT  0x02, R6          ; LEDs = predicted class
        HLT
