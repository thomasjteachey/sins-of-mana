; Sin of Mana add-on: faster main menu (and field reload) transitions.
;
; Opening the main menu took ~2.8 s and closing it ~2.1 s (Mesen, user's save).
; Most of that is the game unpacking graphics with slow decoders, plus 16-step
; fades and a 16-frame pause on a black screen. This patch:
;  * fades in 8 steps instead of 15/16 (brightness +-2 per frame),
;  * pauses 2 frames on black before loading the menu instead of 16,
;  * replaces three graphics decoders with versions that leave exactly the same
;    memory, direct page and registers behind, only faster:
;      $E8:C484  tiles: zero runs, then each row XORed with the row above
;      $E8:C480  1bpp mask -> bitplanes with every pixel doubled
;      $C2:3B87  field graphics: literal bytes or "same as 2 bytes back"
;    Other screens that use them (field reloads, other menus) load faster too.
;  * speeds up the menu text engine (the translation's, bank $C0) the same way:
;    copying a character into the shift buffer, and drawing its shadowed rows
;    into tiles, give the same bytes in about half the time,
;  * lets menus draw more than one line of text per frame (each finished line is
;    uploaded from its own heap block instead of waiting for the one buffer),
;  * slides submenu pages in 16 steps instead of 32, and stops waiting a frame
;    after every icon (with the icon uploads queued in a safe order).
; See NOTES.md ("Menu speed").

exhirom

!ForceExact ?= 0             ; test builds: 1 = always take the byte-by-byte paths

; ---- fades (menu task: A/X/Y 16-bit, D = the menu's direct page) ----
FadeOutStep = $C4922E        ; top of the fade-out loop (wait a frame, queue $2100)
org $C4923F                  ; fade-out loop: brightness -2 per frame (was -1)
	LDA $3C
	DEC A
	DEC A
	STA $3C
	STA $0004,X
	JSL $C00588
	LDA $3C
	BNE FadeOutStep          ; 16, 14, ... 0: reaches 0 exactly
	NOP
	NOP
assert pc() == $C49252       ; the RTS stays

org $C491F6                  ; fade-in: brightness 1, 3, ... 15 (was 1, 2, ... 15)
	JSL FadeIn
	RTS

org $C48CB7                  ; pause on black before the menu loads: 2 frames (was 16)
	dw $0002

; ---- decoders ----
org $E8C480
	JML FastStretch          ; was JSR $C41C : RTL
org $E8C484
	JML FastTiles            ; was JSR $C48B : JSR $C4D1 : RTL
org $C23B87
	JSL FastField            ; was the decoder itself (ends in RTS)
	RTS

; ---- menu text (bank $C0, DB = $7E) ----
TextLoadDone = $C0ED78       ; after the copy loop
org $C0ED4D
	JSL TextLoad             ; was the loop copying the character into the shift buffer
	BRA TextLoadDone
org $C0F07A
	JSL TextRows             ; was the loop drawing 8 rows with their shadow (non-style, overwrite)
	RTS

; ---- menu text upload ($C4:9840, after each line): the original queued the line's tiles
; from the one render buffer ($7E:3400) with a "tell me when done" DMA job and waited for
; it, so menus drew at most one line per frame. Now the line is copied to its own heap
; block and queued with "free the block when done" (as the icon code does); drawing goes
; on at once. No free block: the original way.
org $C49840
	JSL TextUpload
	RTS

; ---- submenu page slide (main menu grid): 16 steps of 16 px instead of 32 of 8 ----
; $E8:CD14/CD1D/CD2A/CD33 set the speed in $00, the loop at $E8:CD97 counts the steps.
; Scroll, sliding sprites ($E8:CF49/CEB2: +-speed) and the cursor nudge ($E8:CFCA:
; speed/8 every other step) all still add up to the same totals.
org $E8CD19
	dw $0010                 ; was $0008
org $E8CD22
	dw $FFF0                 ; was $FFF8
org $E8CD2F
	dw $0010
org $E8CD38
	dw $FFF0
org $E8CD98
	dw $0010                 ; steps (was $0020)

; ---- menu icons ($C4:4D77): after each icon the menu waited a whole frame. Instead,
; only wait if the next icon's 4 uploads would not fit in this frame's DMA budget
; ($E8:CCF7, the same check the text printer uses; it keeps A and X). X was not used
; after the wait ($E8:C18F loads its own).
org $C44DA6
	LDA.w #$0958             ; 4 x (32 bytes + $36 per job) + the text printer's $800 margin
	JSL $E8CCF7
	NOP
	NOP
	NOP
assert pc() == $C44DB0

; The graphics task ($C1:D96A) unpacks an icon into a heap buffer and queues its quarters
; as DMA jobs. Only the first job had the "free source" flag ($08): if an NMI came between
; queuing the jobs, the buffer was freed after the first quarter while the others still
; waited, and the next icon could reuse it (seen as half of one icon showing another).
; The per-icon frame wait hid that. Now the job from the buffer's start, which carries the
; free, is queued last.
org $C1D9DF                  ; 32x32 icons: 4 jobs of 32 bytes
	JSL IconJobs4
	SEP #$20
	RTS
org $C1DA8D                  ; the other icon size: 2 jobs of 64 bytes
	JSL IconJobs2
	SEP #$20
	RTS


org $CBF500                  ; free space in a FastROM bank (bars.asm stops before this)

; Fade-in, called from $C4:91F6 (was 15 steps of +1).
FadeIn:
	LDA.w #$FFFF
	STA $3C
.step
	LDA.w #$0002             ; wait one frame
	LDX.w #$0001
	JSL $C00450
	LDA.w #$2100             ; queue a brightness write
	JSL $C00580
	LDA $3C
	INC A
	INC A
	STA $3C
	STA $0004,X
	JSL $C00588
	LDA $3C
	CMP.w #$000F
	BNE .step
	RTL


; ---------------------------------------------------------------------------
; Tiles, same results as $E8:C484 (= JSR $C48B : JSR $C4D1).
; In:  A/X/Y 16-bit, D = caller's direct page, DB = bank of the tiles.
;      [$10] = packed data, ($13) = output, $28 = tiles, ($1A) = the tiles to
;      XOR (the output), $15/$17 = rows carried over from the previous call.
; Packed: per 8 output bytes one control byte, MSB first: 1 = a literal byte
; follows, 0 = a zero byte. Then in each 4bpp tile every row is XORed with the
; row above (planes 0/1 and planes 2/3 separately), carrying on from the
; previous tile. Every 128 tiles the original waits a frame; so does this.
; Out: $10/$13 advanced, $15/$17 = last rows, $19 = 0, $1C = $1A+$10, $20 = 0,
;      $2A = 0, $2C = 0, A = Y = tiles*32, X = X on entry, or what the last
;      wait returned.
macro zbit(off)
	ASL $19
	BCC ?zero
	LDA [$10],Y
	INY
	STA.w <off>,X
	BRA ?done
?zero:
	STZ.w <off>,X
?done:
endmacro

FastTiles:
	PHX                      ; [1,S] = X to return
	LDA $1A
	CLC
	ADC.w #$0010
	STA $1C
	LDA $28
	ASL
	ASL
	STA $2A                  ; 8-byte groups (0 = 65536, like the original)
	LDY.w #$0000             ; index into the packed data
	SEP #$20
if !ForceExact
	JMP .exact
endif
	LDA $12                  ; packed data in WRAM (could overlap the output):
	CMP #$7E                 ; do it byte by byte like the original
	BCC +
	CMP #$80
	BCS +
	JMP .exact
+	LDA $21                  ; the original's bit counter is $20/$21 with only $20
	BEQ +                    ; reset per group; a nonzero $21 stretches the first one
	JMP .exact
+	LDX $13                  ; output pointer
.group
	LDA [$10],Y
	BEQ .zero8
	INY
	CMP #$FF
	BEQ .lit8
	JMP .mixed
.zero8                       ; control byte 0: 8 zero bytes
	INY
	REP #$21
	STZ.w $0000,X
	STZ.w $0002,X
	STZ.w $0004,X
	STZ.w $0006,X
	TXA
	ADC.w #$0008
	TAX
	DEC $2A
	SEP #$20
	BNE .group
	JMP .packed
.lit8                        ; control byte $FF: 8 literal bytes
	REP #$20
	LDA [$10],Y
	STA.w $0000,X
	INY
	INY
	LDA [$10],Y
	STA.w $0002,X
	INY
	INY
	LDA [$10],Y
	STA.w $0004,X
	INY
	INY
	LDA [$10],Y
	STA.w $0006,X
	INY
	INY
	SEP #$20
.next
	REP #$21                 ; A 16-bit, carry clear
	TXA
	ADC.w #$0008
	TAX
	DEC $2A
	SEP #$20
	BNE .group
	JMP .packed
.mixed                       ; any other control byte: bit by bit
	STA $19
	%zbit($0000)
	%zbit($0001)
	%zbit($0002)
	%zbit($0003)
	%zbit($0004)
	%zbit($0005)
	%zbit($0006)
	%zbit($0007)
	JMP .next
.packed
	STZ $19                  ; the last control byte, shifted out
	REP #$20
	STX $13                  ; output pointer advanced
	STZ $20                  ; bit counter
	BRA .rows

.exact                       ; A 8-bit: the original loop ($E8:C49E)
	LDA #$08
	STA $20
	LDA [$10],Y
	INY
	STA $19
..bit
	ASL $19
	BCC ..zero
	LDA [$10],Y
	INY
	STA ($13)
	BRA ..step
..zero
	LDA #$00
	STA ($13)
..step
	REP #$20
	INC $13
	DEC $20
	SEP #$20
	BNE ..bit
	REP #$20
	DEC $2A
	SEP #$20
	BNE .exact
	REP #$20

.rows                        ; A 16-bit; Y = packed bytes read
	TYA
	CLC
	ADC $10
	STA $10                  ; packed data pointer advanced (16 bits, like the original)
	LDY.w #$0000             ; tile offset
	LDA $28
	STA $2C
.tile
	LDA $2C
	AND.w #$007F
	BNE +
	PHY
	LDA.w #$0002             ; every 128 tiles let the other tasks run a frame
	LDX.w #$0001
	JSL $C00450
	TXA
	STA 3,S                  ; X to return
	PLY
+	TYA
	CLC
	ADC $1A
	TAX                      ; X = this tile
	LDA $15                  ; planes 0/1: each row ^= the (new) row above
	EOR.w $0000,X
	STA.w $0000,X
	EOR.w $0002,X
	STA.w $0002,X
	EOR.w $0004,X
	STA.w $0004,X
	EOR.w $0006,X
	STA.w $0006,X
	EOR.w $0008,X
	STA.w $0008,X
	EOR.w $000A,X
	STA.w $000A,X
	EOR.w $000C,X
	STA.w $000C,X
	EOR.w $000E,X
	STA.w $000E,X
	STA $15
	LDA $17                  ; planes 2/3
	EOR.w $0010,X
	STA.w $0010,X
	EOR.w $0012,X
	STA.w $0012,X
	EOR.w $0014,X
	STA.w $0014,X
	EOR.w $0016,X
	STA.w $0016,X
	EOR.w $0018,X
	STA.w $0018,X
	EOR.w $001A,X
	STA.w $001A,X
	EOR.w $001C,X
	STA.w $001C,X
	EOR.w $001E,X
	STA.w $001E,X
	STA $17
	TYA
	CLC
	ADC.w #$0020
	TAY
	DEC $2C
	BEQ +
	JMP .tile
+	PLX
	TYA
	RTL


; ---------------------------------------------------------------------------
; Doubled pixels, same results as $E8:C480 (= JSR $C41C : RTL).
; In:  A/X/Y 16-bit, DB = bank of the buffer at ($10).
;      38 groups: mask bytes ($10)+$4C0+g*32+j -> ($10)+g*64+j = high nibble,
;      ($10)+g*64+32+j = low nibble, each pixel doubled (abcd -> aabbccdd).
;      The output covers the mask area; the order (and so the result) is the
;      original's: a mask byte is read before anything is written over it.
; Out: $20 = $21 = $22 = 0, X = ($10)+$980, A = Y = $0980.
FastStretch:
	LDA $10
	CLC
	ADC.w #$04C0
	TAX                      ; mask
	LDY $10                  ; output
	SEP #$20
	LDA #$26
	STA $20                  ; groups
.group
	LDA #$00
	XBA                      ; B = 0, so TAX gives X = the mask byte
	LDA #$20
	STA $21
.byte
	LDA.w $0000,X
	PHX
	TAX
	LDA.l StretchHi,X
	STA.w $0000,Y
	LDA.l StretchLo,X
	STA.w $0020,Y
	PLX
	INX
	INY
	DEC $21
	BNE .byte
	REP #$21
	TYA
	ADC.w #$0020
	TAY
	SEP #$20
	DEC $20
	BNE .group
	STZ $22
	REP #$30
	TYA
	SEC
	SBC $10
	TAY
	RTL


; ---------------------------------------------------------------------------
; Field graphics, same results as $C2:3B87 (called with JSL from a stub there).
; In:  A 16-bit (all callers), D = caller's direct page, DB = output bank.
;      [$73] = packed data (24-bit pointer), ($76) = output, $44 = tiles
;      (32 bytes each; the original rounds the byte count up to 8).
; Packed: per 8 output bytes one control byte, MSB first: 1 = a literal byte
; follows, 0 = the byte 2 back (two zero bytes before the start).
; Out: $73-$75 and $76 advanced, $44 = 0, $46/$48 = last two bytes, $4A = 0,
;      A/X/Y 16-bit: X = 0, Y = next-to-last byte, A = last byte, with in the
;      high half what the original's last 16-bit read left there.
macro fbit0(off)
	ASL $4A
	BCC ?rep
	LDA [$73],Y
	INY
	BRA ?got
?rep:
	LDA $48
?got:
	PHA
	LDA $46
	STA $48
	PLA
	STA $46
	STA.w <off>,X
endmacro

macro fbit(off)
	ASL $4A
	BCC ?rep
	LDA [$73],Y
	INY
	BRA ?got
?rep:
	LDA.w <off>,X            ; X = output - 2
?got:
	STA.w <off>+2,X
endmacro

FastField:
	REP #$30
	STZ $46
	STZ $48
	LDA $44
	ASL
	ASL
	ASL
	ASL
	ASL
	CLC
	ADC.w #$0007
	LSR
	LSR
	LSR
	STA $44                  ; 8-byte groups (0 = 65536, like the original)
	PHA                      ; [3,S] = group count (high byte: see .end)
	PEA.w $FFFF              ; [1,S] = packed index just past the last literal read
	LDX $76
	LDY.w #$0000
	SEP #$20
.slowgroup                   ; one group with "2 back" kept in $46/$48, as the original does
	LDA [$73],Y
	INY
	STA $4A
	PHA                      ; control byte
	%fbit0($0000)
	%fbit0($0001)
	%fbit0($0002)
	%fbit0($0003)
	%fbit0($0004)
	%fbit0($0005)
	%fbit0($0006)
	%fbit0($0007)
	PLA
	BEQ +
	REP #$20                 ; this group read a literal
	TYA
	STA 1,S
	SEP #$20
+	REP #$21
	TXA
	ADC.w #$0008
	TAX
	DEC $44
	SEP #$20
	BEQ .slowdone
if !ForceExact
	JMP .slowgroup
endif
	LDA $75                  ; packed data in WRAM (could overlap the output): stay on
	CMP #$7E                 ; this path, byte by byte like the original
	BCC .fast
	CMP #$80
	BCS .fast
	JMP .slowgroup
.fast
	REP #$20
	DEX
	DEX                      ; X = output - 2 from here on
	SEP #$20
	BRA .group
.slowdone
	REP #$20
	DEX
	DEX                      ; X = address of the next-to-last byte
	JMP .end
.group
	LDA [$73],Y
	BEQ .rep8
	INY
	CMP #$FF
	BEQ .lit8
	JMP .mixed
.rep8                        ; control byte 0: the last 2 bytes, 4 more times
	INY
	REP #$21
	LDA.w $0000,X
	STA.w $0002,X
	STA.w $0004,X
	STA.w $0006,X
	STA.w $0008,X
	TXA
	ADC.w #$0008
	TAX
	DEC $44
	SEP #$20
	BNE .group
	JMP .end
.lit8                        ; control byte $FF: 8 literal bytes
	REP #$20
	LDA [$73],Y
	STA.w $0002,X
	INY
	INY
	LDA [$73],Y
	STA.w $0004,X
	INY
	INY
	LDA [$73],Y
	STA.w $0006,X
	INY
	INY
	LDA [$73],Y
	STA.w $0008,X
	INY
	INY
	SEP #$20
.nextlit
	REP #$21
	TXA
	ADC.w #$0008
	TAX
	TYA
	STA 1,S                  ; this group read a literal
	DEC $44
	SEP #$20
	BNE .group
	JMP .end
.mixed                       ; any other control byte: bit by bit
	STA $4A
	%fbit($0000)
	%fbit($0001)
	%fbit($0002)
	%fbit($0003)
	%fbit($0004)
	%fbit($0005)
	%fbit($0006)
	%fbit($0007)
	JMP .nextlit

.end                         ; X = address of the next-to-last output byte
	REP #$30
	PHY                      ; [1,S] packed bytes read, [3,S] last-literal index, [5,S] groups
	LDA 3,S
	INC A
	BEQ .nolit
	DEC A
	TAY
	SEP #$20
	LDA [$73],Y              ; the original read each literal as 16 bits: the byte after
	BRA .gotb                ; the last one stayed in the high half of A
.nolit
	SEP #$20
	LDA 6,S                  ; no literal: the group count's high byte stayed there
.gotb
	STA 3,S                  ; [3,S] = the high byte for A
	REP #$20
	PLA
	CLC
	ADC $73
	STA $73                  ; packed data pointer advanced (24 bits)
	SEP #$20
	BCC +
	INC $75
+	STZ $4A
	REP #$20
	TXA
	INC A
	INC A
	STA $76                  ; output pointer advanced
	LDA.w $0000,X            ; last two output bytes
	SEP #$20
	STA $48
	XBA
	STA $46
	LDY $48                  ; Y = next-to-last byte ($49 = 0)
	LDX.w #$0000
	XBA
	LDA 1,S
	XBA                      ; A = high byte : last byte
	REP #$20
	PLX                      ; drop the two stack slots
	PLX
	LDX.w #$0000
	RTL



; ---------------------------------------------------------------------------
; Menu text: copy a character into the shift buffer, same results as the loop at
; $C0:ED4D-$ED77 (entered there with A/X/Y 16-bit, DB = $7E).
; In:  X = (character+1)*16 (+$800 for the second font).
; The font has 16 bytes per character: rows 0-14 are 8 pixels each. Buffer rows
; are 3 bytes ($7E:3090 + 3*row): the font byte, then two zero bytes.
; Out: like the original: X = X-14, Y = $FFFD, A = font rows 0/1, carry clear.
TextLoad:
	LDA.l $FE55FD,X          ; rows 13/14 (the original's first pair)
	STA.w $30B7
	XBA
	STA.w $30BA
	STZ.w $30B8
	STZ.w $30BB
	LDA.l $FE55FB,X          ; rows 11/12
	STA.w $30B1
	XBA
	STA.w $30B4
	STZ.w $30B2
	STZ.w $30B5
	LDA.l $FE55F9,X          ; rows 9/10
	STA.w $30AB
	XBA
	STA.w $30AE
	STZ.w $30AC
	STZ.w $30AF
	LDA.l $FE55F7,X          ; rows 7/8
	STA.w $30A5
	XBA
	STA.w $30A8
	STZ.w $30A6
	STZ.w $30A9
	LDA.l $FE55F5,X          ; rows 5/6
	STA.w $309F
	XBA
	STA.w $30A2
	STZ.w $30A0
	STZ.w $30A3
	LDA.l $FE55F3,X          ; rows 3/4
	STA.w $3099
	XBA
	STA.w $309C
	STZ.w $309A
	STZ.w $309D
	LDA.l $FE55F1,X          ; rows 1/2
	STA.w $3093
	XBA
	STA.w $3096
	STZ.w $3094
	STZ.w $3097
	TXA
	SEC
	SBC.w #$000E
	TAX                      ; X as the original leaves it
	LDA.l $FE55FE,X          ; row 0 (and row 1 in the high byte, as the original reads it)
	STA.w $3090
	STZ.w $3091
	LDY.w #$FFFD
	CLC
	RTL


; Menu text: one 8x8 tile column of a character with its shadow, same results as the
; loop at $C0:F07A (the plain, overwriting case). A/X/Y 16-bit, DB = $7E.
; In:  X = buffer byte left of this column in the row above the first one,
;      Y = tile offset ($7E:3400+Y), on a tile boundary for the fast path.
; Row r of the tile: plane 1 = the character's byte b(r); plane 0 = shadow =
; h(r) | h(r-1), with h(r) = b(r) | (b(r) >> 1, the left byte's last pixel shifted in).
; Out: X += 24, Y += 16, A = 0, carry = last byte's bit 0 (like the original).
macro textrow(k)
	LDA.w $0003+(3*<k>),X      ; left byte: its last pixel
	LSR A
	LDA.w $0004+(3*<k>),X      ; this column's byte
	STA.w $3401+(2*<k>),Y      ; plane 1
	ROR A
	ORA.w $0004+(3*<k>),X      ; h(k)
	STA.w $3402+(2*<k>),Y      ; next row's shadow starts with h(k)
	ORA.w $3400+(2*<k>),Y      ; | h(k-1)
	STA.w $3400+(2*<k>),Y
endmacro

TextRows:
if !ForceExact
	JMP .slow
endif
	TYA
	AND.w #$000F
	BEQ +
	JMP .slow
+	SEP #$20
	LDA.w $0000,X            ; the row above: h(-1)
	LSR A
	LDA.w $0001,X
	ROR A
	ORA.w $0001,X
	STA.w $3400,Y
	%textrow(0)
	%textrow(1)
	%textrow(2)
	%textrow(3)
	%textrow(4)
	%textrow(5)
	%textrow(6)
	LDA.w $0018,X            ; row 7: no next row in this tile
	LSR A
	LDA.w $0019,X
	STA.w $340F,Y
	ROR A
	ORA.w $0019,X
	ORA.w $340E,Y
	STA.w $340E,Y
	REP #$21
	TXA
	ADC.w #$0018
	TAX
	TYA
	ADC.w #$0010
	TAY
	SEP #$20
	LDA.w $0001,X            ; carry = bit 0 of the last row's byte, as the original leaves it
	LSR A
	REP #$20
	LDA.w #$0000
	RTL
.slow                        ; not on a tile boundary: the original loop
	LDA.w $0000,X
	SEP #$20
	LSR A
	XBA
	ROR A
	ORA.w $0001,X
	PHA
	LDA.w $0003,X
	LSR A
	LDA.w $0004,X
	PHA
	ROR A
	ORA $01,S
	ORA $02,S
	STA $02,S
	REP #$20
	PLA
	XBA
	INX
	INX
	INX
	STA.w $3400,Y
	INY
	INY
	TYA
	AND.w #$000F
	BNE .slow
	RTL


; ---------------------------------------------------------------------------
; Icon uploads in a safe order (see $C1:D9DF/$C1:DA8D above). Graphics task context:
; D = its direct page ($32 = icon buffer in bank $7F, $0C = VRAM address), DB = $7F.
macro iconjob(type, src, vram, size)
	LDA.w #<type>
	JSL $C00560              ; X = new DMA job (waits if none is free)
	LDA.w #$007F
	STA $0006,X              ; source bank (the size below overwrites the high byte)
	LDA $32
	CLC
	ADC.w #<src>
	STA $0004,X
	LDA $0C
	CLC
	ADC.w #<vram>
	STA $000B,X
	LDA.w #<size>
	STA $0007,X
	JSL $C00568              ; queue it
endmacro

IconJobs4:                   ; was: (9: +0 -> +$000), then 1: +$40 -> +$010, +$20 -> +$100, +$60 -> +$110
	REP #$20
	%iconjob($0001, $0040, $0010, $0020)
	%iconjob($0001, $0020, $0100, $0020)
	%iconjob($0001, $0060, $0110, $0020)
	%iconjob($0009, $0000, $0000, $0020)
	LDA.w #$0110             ; what the original's helper ($C1:DA20) left in $24/$26
	STA $24
	LDA.w #$0060
	STA $26
	RTL

IconJobs2:                   ; was: (9: +0 -> +$000), then 1: +$40 -> +$100, 64 bytes each
	REP #$20
	%iconjob($0001, $0040, $0100, $0040)
	%iconjob($0009, $0000, $0000, $0040)
	RTL


TextCount = $7E2BD0          ; lines queued since the last pause (free RAM, see NOTES.md)

; ---------------------------------------------------------------------------
; Menu text upload, called from $C4:9840 (JSR'd from $C4:97FA/9825/983A).
; A/X/Y 16-bit, D = menu direct page: $2E = cells in the line, $57 = next tile of the
; pool. Same job fields, VRAM address and DMA budget check as the original.
TextUpload:
	PHB
	SEP #$20
	LDA #$7F
	PHA
	PLB                      ; DB = $7F (job records and heap), like the original
	REP #$20
	LDA $2E
	ASL A
	STA $1E                  ; the original computes this too
	LDA $2E
	XBA
	LSR A
	LSR A
	LSR A                    ; bytes = cells * 32
	BNE +
	JMP .wait
+	LDA.l TextCount          ; the system frees the blocks only when this task pauses:
	CMP.w #$0004             ; after 4 lines without one, pause a frame (that frees them)
	BCC +
	LDA.w #$0002
	LDX.w #$0001
	JSL $C00450
	LDA.w #$0000
+	INC A
	STA.l TextCount
	LDA $2E
	XBA
	LSR A
	LSR A
	LSR A
	PHA                      ; [1,S] = bytes
	TAX
	JSL $C00500              ; heap block (bank $7F), X = 0 if none
	TXY
	BNE +
	PLA
	JMP .wait
+	PHY                      ; [1,S] = block, [3,S] = bytes
	LDA 3,S
	DEC A
	LDX.w #$3400
	MVN $7F,$7E              ; copy the line: $7E:3400 -> $7F:block (DB = $7F after)
	LDA.w #$0009             ; VRAM DMA; when done the NMI has the block freed
	JSL $C00560
	LDA.w #$007F
	STA $0006,X
	PLA
	STA $0004,X              ; source = the block
	LDA $57
	SEC
	SBC.w #$2000
	SEC
	SBC $1E
	ASL A
	ASL A
	ASL A
	STA $000B,X              ; VRAM address, as the original
	LDA 1,S
	CLC
	ADC.w #$0800
	JSL $E8CCF7              ; wait if this frame's DMA budget is full (keeps A, X)
	PLA
	STA $0007,X              ; size
	JSL $C00568              ; queue it
	PLB
	LDA.l $7E3080            ; the original ends with this load
	RTL
.wait                        ; the original: one buffer, wait until it is uploaded
	LDA.w #$0011
	JSL $C00560
	LDA.w #$007E
	STA $0006,X
	LDA.w #$3400
	STA $0004,X
	LDA $57
	SEC
	SBC.w #$2000
	SEC
	SBC $1E
	ASL A
	ASL A
	ASL A
	STA $000B,X
	LDA $2E
	XBA
	LSR A
	LSR A
	LSR A
	PHA
	CLC
	ADC.w #$0800
	JSL $E8CCF7
	PLA
	STA $0007,X
	JSL $C00568
-	LDA.w #$0004             ; wait for "done" messages until it is ours
	JSL $C0052C
	LDA $0004,X
	PHA
	JSL $C00524
	PLA
	CMP.w #$3400
	BNE -
	PLB
	LDA.l $7E3080
	RTL

assert pc() <= $CBFD00           ; end of the free space in bank $CB


; Doubled-pixel tables for FastStretch: abcd -> aabbccdd (slow ROM is fine for tables).
org $570000
function dbl(n) = ((n&8)*24)|((n&4)*12)|((n&2)*6)|((n&1)*3)
StretchHi:
for i = 0..256
	db dbl(!i>>4)
endfor
StretchLo:
for i = 0..256
	db dbl(!i&15)
endfor
