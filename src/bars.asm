; Sin of Mana add-on: revenge bars, cast bars and buff markers, drawn in the
; style of the game's HUD.
;
; One engine, five features, each with its own switch word (below). Every
; feature patch (tools/build.py) carries this whole engine, byte for byte the
; same, plus its own switch set to 0; the switches sit in free ROM that is $FF
; in the base game, so a switch nobody wrote reads $FFFF = off. Any mix of the
; feature patches can be applied, in any order.
;   FeatRevenge    revenge bar under enemies
;   FeatMarkers    raised/lowered-stat arrow at the left end of the enemy bar
;                  (without the revenge bar: on an empty bar under the enemy)
;   FeatCastParty  cast bar under party members
;   FeatCastEnemy  cast bar under enemies
;   FeatHudIcons   buff/debuff icons beside the party HUD
;   FeatLevelInfo  info panel at the level-up stat choice: what the highlighted
;                  stat does, and the character's Lv60 capstone for it (LevelPanel)
;   FeatShopInfo   the same panel in a shop's buy/sell ring: the highlighted
;                  equipment's description (needs the equip descriptions patch,
;                  which notes it: src/main.asm ShopNote)
;  * Revenge bar under enemies: hate / revenge threshold. Green, then yellow,
;    then red as it fills; flashes red/gold at the threshold. Its left end shows
;    a green up arrow if the enemy has raised stats (worth an Antimagic), a red
;    down arrow if it has lowered stats (both: up arrow left, down arrow right).
;  * Cast bar under anyone casting (party and enemies): blue with a small
;    diamond at its left end, gold when the spell is ready. An enemy's cast bar
;    sits under its revenge bar.
;  * Party buff tags beside the HUD: "ATK" etc. with a green up / red down
;    arrow, in the HUD's own font, next to each party member's HP.
; Bars: 4 pixels tall, dark outline with rounded ends, fill with a highlight
; row, 24-pixel track filled in 2-pixel steps (12 steps).
;
; How the bars are drawn
;  * BG3 is the HUD layer. Each bar is drawn in an off-screen row of the BG3 map
;    (rows 28-31; two bars per row, one in pixel rows 0-3 and one in rows 4-7,
;    each with its own tile set), and an HDMA table (channel 1) scrolls BG3 on
;    just the 4 screen lines where the bar belongs, so it lands on the exact
;    pixel under its owner. Every other line keeps BG3 scroll 0.
;  * Bars whose lines would touch are pushed down a few pixels. A bar is left
;    out while the game shows text on BG3 on those lines (the target name).
;  * Bars runs every frame from the sprite builder ($FD:6E24, main loop) and
;    builds the table into one of two buffers. The NMI hook ($C0:22BC, where the
;    game re-enables HDMA after its uploads) points channel 1 at the newest
;    table and enables it, but only if it was built in the last 2 frames, so the
;    bars switch off by themselves in menus (the sprite builder doesn't run there).
;  * DMA channel 0 is the game's upload channel; spell effects and the message
;    box use HDMA 2-7 (the message box switches lines 38-61 to mode 5, where BG3
;    isn't shown). Channel 1 is unused by the game. BG3 scroll is normally 0.
;  * Graphics: 20 tiles (tools/make_bargfx.py) in BG3 tiles $0C0-$0D3, the font's
;    kana, which the English game never shows. Colours from the HUD's BG3
;    palettes 0-4. Re-sent on (re)activation and every 128 frames.
;  * Steady colours. The game flickers colours 2-3 of BG3 palettes 0-3 every
;    other frame (C4:5ECF steps through 3 shades it keeps at $7E:3000/3020/3040:
;    bright, middle, dark, middle). It needs that for the tech gauge (palette
;    0) and for low / critical HP digits (2 / 3); palette 1 is only used by a
;    rare text colour. PulseFix (after each step) puts palette 1 back on its
;    middle shade, and palettes 2 and 3 too while no HP digit shows in them, so
;    our marks don't flicker. While a critical HP digit needs palette 3 to
;    flicker, the red buff marks use BG3 palette 5 instead: CGRAM 21-23, which
;    only windows use (BG palette 1 is the window palette). The NMI hook writes
;    palette 3's middle shades there while nothing uses HDMA (every window is
;    drawn through HDMA: a mode 5 split), and puts the window colours back as
;    soon as anything does.
;  * RAM: $7E:2800-$7E:2A5F. Never written in battles, menus, field or dialogs
;    in testing (the title screen clears it).
;  * Cast timing: when a cast starts, the mod hands its computed cast value to
;    the battle script ($D0:FB12), which then waits value + 1 ticks on one of
;    the game's timers ($C0:C960: records in bank $7F linked from $7F:00C4,
;    +$04 wake tick of the clock $7F:00C6, +$06 length). CastStart records that
;    length; CastBar finds the timer (FindCastTimer) and, while the caster's
;    state (record +$00) is $0A, shows T - time left out of T, T = the largest
;    time left seen (value + 1 at first), never fewer steps than before. While
;    the field is paused (ring menu) the game takes its timers off the list and
;    keeps the time left in +$08 ($C0:CB00, the mod's $40:16C0): the bar stands
;    still with them. Right after a ring menu the mod pushes the party's cast
;    waits 16 ticks later ($40:2400): the bar stands still until it catches up.
;  * DMA job type must be $01: type $11 makes the NMI send a "done" message to
;    whatever task was running, and enemy scripts read it as a command (that
;    overwrote the brightness pointer -> black screen).
; Data used: entity table $7E:2040 (records in $7F), record +$00 state, +$01
; side (1 = party, 2 = enemy), +$04 sprite object, +$90 enemy type, +$92 HP,
; +$120 hate, +$C5..+$C7 stat changes (battle stats +$35..+$37: 2-bit fields,
; 1 = up, 2 = down); threshold $50:5300+type; object +$83 x centre, +$87
; ground y (+$8B, the jump height, is ignored); camera $7F:032A/$032C; max HP
; +$A2 and HP +$92 (to tell which party member each HUD block shows).

exhirom

FeatRevenge   = $CBF4F0      ; feature switches: $FFFF (blank ROM) = off, $0000 = on
FeatMarkers   = $CBF4F2
FeatCastParty = $CBF4F4
FeatCastEnemy = $CBF4F6
FeatHudIcons  = $CBF4F8
FeatLevelInfo = $CBF4FA
FeatShopInfo  = $CBF4FC

!Ram      = $7E2800
!CastBook = !Ram+$000        ; 16 entity slots x (wait timer, steps << 12 | bar length; $FFFF, tick it ran out)
!Counter  = !Ram+$040        ; frames
!Stamp    = !Ram+$042        ; !Ticks when the ready table was built
!Ready    = !Ram+$044        ; address (bank $7E) of the table the NMI should use
!Active   = !Ram+$046        ; rows 28-31 set up and tiles sent
!Owner    = !Ram+$048        ; 8 bar slots: $8000 | key (entity slot*2 + 0 revenge / 1 cast), 0 = free
!Code     = !Ram+$058        ; 8 bar slots: bar code on screen ($FFFF = must redraw)
!BarX     = !Ram+$068        ; 8 bar slots: left edge of the track this frame
!BarY     = !Ram+$078        ; 8 bar slots: top line this frame
!Seen     = !Ram+$088        ; bit per bar slot shown this frame
!Dirty    = !Ram+$08A        ; bit per BG3 row 28-31 changed this frame
!Order    = !Ram+$08C        ; up to 8 bar slots (x2), sorted by y
!ScanRow  = !Ram+$09C        ; next BG3 row to check for game text
!HudBlock = !Ram+$09E        ; next HUD block to update (* 2)
!Owned    = !Ram+$0A2        ; bit per bar slot in use
!LastRun  = !Ram+$0A4        ; !Ticks when Bars last ran with BG3 as the HUD
!Swept    = !Ram+$0A0        ; $5A5A once old-style bar cells were swept away
!Borrow   = !Ram+$0A6        ; NMI: write the red into CGRAM 21-23 while nonzero (counts down)
!Borrowed = !Ram+$0A8        ; nonzero: CGRAM 21-23 hold our red, not the window colours
!Warn     = !Ram+$0AA        ; HP digits shown in palette 2 (bit 0) / palette 3 (bit 1)
!RedPal   = !Ram+$0AC        ; palette bits of the red buff marks: $0C00 (3) or $1400 (5)
!LastRed  = !Ram+$0AE        ; !RedPal the HUD icons were last drawn with
!Held     = !Ram+$0B0        ; frames the game's HDMA was held back for the red marks (NmiRed)
!Keep     = !Ram+$0B2        ; HDMA channels the NMI hook may enable this frame (byte)
!PanelOn  = !Ram+$0E0        ; level-up info panel up (LevelPanel)
!PanelSig = !Ram+$0E2        ; what it shows: stat, character, capstone line, red palette
!P5Dirty  = !Ram+$0E4        ; its BG3 row 5 changed: upload it
!SprSave  = !Ram+$0E6        ; Y of OAM entries 1 and 2 (HUD portraits) while it hides them
!SprHid   = !Ram+$0E8        ; bits 0 / 1 / 2: entry 1 / 2 / 0 hidden by it
!SprSave0 = !Ram+$0EC        ; Y of OAM entry 0 while it hides it
!PanelMiss = !Ram+$0EA       ; frames in a row the window wasn't found (closes at 4)
!PanelSig2 = !Ram+$0EE       ; the level-up panel's spell line (LvSpells)
!ShopDesc  = !Ram+$0F0       ; description (bank $53) of the last item name printed (main.asm)
!ShopStamp = !Ram+$0F2       ; !Ticks when it was noted
!PanelVal  = !Ram+$0F4       ; the highlighted stat as the window shows it (with the +1)
!RowBusy  = !Ram+$0C0        ; byte per BG3 row: nonzero = the game shows text there
!TableA   = !Ram+$100        ; HDMA tables (<= 100 bytes each)
!TableB   = !Ram+$180
!HudLast  = !Ram+$200        ; 38 icon cells beside the HUD: what we last wrote there
!TagList  = !Ram+$250        ; icon cells of the HUD block being drawn (up to 9)
!HudSig   = !Ram+$270        ; per HUD block: record, stat bytes, shown (skip if unchanged)

!Shadow   = $7E4000          ; BG3 tilemap copy (game uploads it to VRAM $5800)
!Entities = $7E2040
!Thresh   = $505300
!CamX     = $7F032A
!CamY     = $7F032C
!Ticks    = $7F00C6          ; mod's frame counter
!RtlFD    = $FD0A70          ; any RTL byte in bank $FD
!Frame    = $2C              ; bytes of locals on the stack (D+$01..D+$2C)
!Pri      = $2000            ; BG3 priority bit: above sprites, like the HUD
!TileBase = $00C0            ; bar tiles: upper set $0C0-$0C9, lower set $0CA-$0D3
!TagTile  = $00D4            ; stat icons $0D4-$0DC (order = TagDefs)
!Steps    = 12               ; fill steps: 3 cells x 4
!StepMask = $000F            ; bar code: steps | up | down | cast | palette bits
!UpFlag   = $0020
!DownFlag = $0040
!CastFlag = $0080
!RedFlag  = $0100            ; red arrow drawn in palette 5 (see RedPalette)
!BandH    = 4                ; bar height in lines
!YRev     = 2                ; bar top = ground y + YRev
!YGap     = 5                ; cast bar under a revenge bar
!YMin     = 40               ; keep clear of the top HUD...
!YMax     = 180              ; ...and the bottom HUD (BG3 row 23 = line 184)
!LineCal  = -1               ; a band starts on the screen row equal to its running line count
!VCal     = -1               ; screen row r shows BG3 line r + VOFS + 1

org $FD6E24
	JSL Bars                 ; was JSR $6E9B : SEP #$20
	NOP

org $D0FB12
	JSL CastStart            ; was JSL $C40018 (push the cast value for the script)

org $C022BC
	JSL NmiHdma              ; was LDA $0032 : STA $00420C (re-enable HDMA after uploads)
	NOP
	NOP
	NOP

org $C45EF5                  ; end of the HUD flicker step, after it copied this step's colours
	JSL PulseFix             ; was LDA $7F0330 : ORA #$0004 : STA $7F0330 : RTS
	RTS

org $CBE400                  ; free space in a FastROM bank
Bars:
	PHK                      ; the replaced JSR $6E9B, via an RTL in bank $FD
	PER .back-1
	PEA.w (!RtlFD&$FFFF)-1
	JML $FD6E9B
.back                        ; ($CB:E40B: keep it here, save states return to it)
	PHP
	REP #$30
	PHB
	PHD
	TSC
	SEC
	SBC.w #!Frame
	TCS
	TCD                      ; locals at D+$01..D+$2C
	PEA.w $7F7F
	PLB
	PLB                      ; DB = $7F (entity records, objects)
	STZ $23                  ; nonzero: send our tiles this frame
	LDA.l !Counter
	INC
	STA.l !Counter
	AND.w #$00FF             ; every 256 frames set everything up again
	BNE +                    ; (in case the game rewrote rows 28-31)
	STA.l !Active
+	LDA.l $7F0805            ; BG3 must be the HUD layer (game's $2105 copy: mode 1
	AND.w #$0008             ; with BG3 on top). Some spell effects take BG3 over
	BNE +                    ; for themselves: stay out of it, and set everything
	LDA.w #$0000             ; up again once it's back
	STA.l !Active
	LDA.w #$0C00             ; (and leave CGRAM 21-23 to them)
	STA.l !RedPal
	JMP .exit
+	JSR RedPalette
	LDA.l !Ticks             ; back after a gap (power-on, menu, map change, spell
	SEC                      ; effect)? Send our tiles before anything is drawn
	SBC.l !LastRun
	CMP.w #$0004
	BCC +
	INC $23
+	LDA.l !Ticks
	STA.l !LastRun
	LDA.w #$0000
	STA.l !Seen
	STA.l !Dirty
	LDA.l FeatLevelInfo      ; level-up stat window or shop ring up: the info panel
	AND.l FeatShopInfo       ; has rows 28-31 and the HDMA table (no bars meanwhile)
	BMI +
	JSL LevelPanel
	BCC +
	JMP .uploads
+	LDA.l FeatRevenge        ; no bar feature on (e.g. only the HUD icons): no bars
	AND.l FeatMarkers
	AND.l FeatCastParty
	AND.l FeatCastEnemy
	BPL +
	JMP .released
+	JSR ScanRows
	LDX.w #$0000
.entity
	STX $01                  ; entity slot * 2
	LDA.l !Entities,X
	BNE +
	JMP .nextEntity
+	STA $03                  ; entity record (bank $7F)
	TAX
	STZ $05                  ; position not read yet (only read for bars)
	LDA.w $0001,X            ; side
	AND.w #$00FF
	CMP.w #$0002
	BEQ .enemy
	CMP.w #$0001
	BNE +
	JMP .cast                ; party: cast bar only (their buffs go beside the HUD)
+	JMP .nextEntity

.enemy                       ; revenge bar: value = hate, max = threshold
	LDA.w $0092,X            ; HP
	BNE +
	JMP .nextEntity
+	LDA.l FeatMarkers
	BMI +
	JSR BuffMarker           ; up / down arrow for its ends
	BIT.w #!DownFlag         ; red arrow in palette 5 now: redraw it when that changes
	BEQ ++
	PHA
	LDA.l !RedPal
	CMP.w #$1400
	PLA
	BCC ++
	ORA.w #!RedFlag
	BRA ++
+	LDA.w #$0000
++	STA $25
	LDA.l FeatRevenge        ; revenge bar off: a bar only to carry the arrow
	BMI .noRevenge
	LDX $03
	LDA.w $0120,X            ; hate
	AND.w #$00FF
	STA $0B
	LDA.w $0090,X            ; enemy type
	AND.w #$01FF
	TAX
	LDA.l !Thresh,X          ; revenge threshold, 0 = never
	AND.w #$00FF
	STA $0D
	BEQ .noRevenge
	LDA $0B
	BEQ .noRevenge
	JSR FillSteps
	JSR RevengeColour
	BRA .revenge
.noRevenge
	LDA $25                  ; no revenge yet: a bar only to carry the arrow
	BNE +
	JMP .cast
+	LDA.w #$0400             ; empty, green
.revenge
	ORA $25
	STA $13                  ; bar code
	JSR Position
	BCC +
	JMP .nextEntity          ; no sprite object
+	LDA $01
	STA $11                  ; key: slot*2 + 0
	LDA $09
	STA $17
	JSR AddBar
	LDA $09
	CLC
	ADC.w #!YGap             ; a cast bar goes under it
	STA $09

.cast                        ; cast bar (CastBar: whether, and how full)
	LDX $03
	LDA.w $0001,X            ; party or enemy cast bar switched off?
	AND.w #$00FF
	CMP.w #$0002
	BEQ +
	LDA.l FeatCastParty
	BRA ++
+	LDA.l FeatCastEnemy
++	BPL +
	JMP .nextEntity
+	JSL CastBar              ; X = record -> carry clear: A = bar code
	BCC +
	JMP .nextEntity
+	STA $13
	LDA $05                  ; position already read for its revenge bar?
	BNE +
	JSR Position
	BCC +
	JMP .nextEntity          ; no sprite object
+	LDA $01
	INC
	STA $11                  ; key: slot*2 + 1
	LDA $09
	STA $17
	JSR AddBar

.nextEntity
	LDX $01
	INX
	INX
	CPX.w #$0020
	BCS +
	JMP .entity

+	LDA.l !Seen              ; free the bar slots nobody used this frame
	EOR.w #$FFFF
	AND.l !Owned
	BEQ .released
	LDX.w #$0000
.release
	LDA.l !Owner,X
	BEQ .relNext
	LDA.l !Seen
	AND.l SlotBit,X
	BNE .relNext
	LDA.l SlotBit,X
	EOR.w #$FFFF
	AND.l !Owned
	STA.l !Owned
	LDA.w #$0000
	STA.l !Owner,X
	LDA.w #$FFFF
	STA.l !Code,X
	STX $01
	JSR ClearSlot
	LDX $01
.relNext
	INX
	INX
	CPX.w #$0010
	BCC .release
.released

	LDA.l !Seen
	BNE +
	LDA.w #$0000             ; no bars: the NMI hook switches HDMA off
	STA.l !Active
	JMP .uploads
+	JSR BuildTable

.uploads
	LDA.l !P5Dirty           ; the info panel's row 5 changed
	BEQ +
	LDA.w #$0000
	STA.l !P5Dirty
	LDA.w #5*64              ; rows 5-6
	JSR QueueHudRows
+	LDA.l !Dirty             ; changed rows 28-31
	BEQ +
	JSR QueueRows
+	LDA $23
	BNE .tiles
	LDA.l !Counter           ; and our tiles every 64 frames (a menu may have
	AND.w #$003F             ; reloaded the font they sit in)
	BNE .hud
.tiles
	JSR QueueTiles
.hud
	LDA.l FeatHudIcons
	BMI .exit
	JSR HudTags
.exit
	LDA.l !RedPal            ; marks drawn in palette 5: the NMI keeps our red in
	CMP.w #$1400             ; CGRAM 21-23 (set last, once this frame's cells are
	BNE +                    ; queued) for 16 frames: the game skips Bars for up
	LDA.w #16                ; to ~7 frames while it sets up the ring menu; the
	BRA ++                   ; main menu shows ~80 frames after Bars stops
+	LDA.w #$0000
++	STA.l !Borrow
	TSC
	CLC
	ADC.w #!Frame
	TCS
	PLD
	PLB
	PLP
	SEP #$20                 ; the replaced SEP #$20
	RTL


; $03 = entity record -> $07 x centre on screen, $09 bar top line (ground y +
; YRev; the jump height +$8B is ignored), $05 = 1. Carry set: no sprite object.
Position:
	LDX $03
	LDA.w $0004,X
	BNE +
	SEC
	RTS
+	TAY
	LDA.w $0083,Y
	SEC
	SBC.l !CamX
	STA $07
	LDA.w $0087,Y
	SEC
	SBC.l !CamY
	CLC
	ADC.w #!YRev
	STA $09
	INC $05
	CLC
	RTS


; X = entity record -> A = !UpFlag if a stat is raised, !DownFlag if one is
; lowered (both if both), 0 if neither.
BuffMarker:
	LDA.w $00C7,X            ; no stat changes at all (the usual case)?
	AND.w #$00FC
	ORA.w $00C5,X
	AND.w #$FCFC
	BNE +
	RTS
+	LDA.w $00C5,X            ; stat-change fields +$35/+$36
	JSR .fields
	STA $1F
	LDA.w $00C7,X            ; and +$37
	AND.w #$00FF
	JSR .fields
	ORA $1F
	RTS
.fields                      ; A = up to two bytes of 2-bit fields -> up/down flags
	STA $0F                  ; (bits 1-0 of each byte are special fields: ignored)
	AND.w #$5454
	STA $1B                  ; low bit of each field
	LDA $0F
	AND.w #$A8A8
	LSR
	STA $1D                  ; high bit, lined up with the low bit
	STZ $0F
	EOR.w #$FFFF
	AND $1B                  ; 01 = raised
	BEQ +
	LDA.w #!UpFlag
	STA $0F
+	LDA $1B
	EOR.w #$FFFF
	AND $1D                  ; 10 = lowered
	BEQ +
	LDA $0F
	ORA.w #!DownFlag
	STA $0F
+	LDA $0F
	RTS


; Request a bar: $11 key, $13 code, $07 x centre, $17 top line.
AddBar:
	LDA.l !Active            ; first bar since we were off: set up rows 28-31
	BNE +
	JSR Setup
+	LDA $11
	ORA.w #$8000
	STA $19                  ; owner tag
	LDX.w #$0000
.find
	LDA.l !Owner,X
	CMP $19
	BEQ .have
	INX
	INX
	CPX.w #$0010
	BCC .find
	LDX.w #$0000             ; new bar: take a free slot
.free
	LDA.l !Owner,X
	BEQ .claim
	INX
	INX
	CPX.w #$0010
	BCC .free
	RTS                      ; all 8 in use
.claim
	LDA $19
	STA.l !Owner,X
	LDA.w #$FFFF
	STA.l !Code,X
	LDA.l SlotBit,X
	ORA.l !Owned
	STA.l !Owned
.have
	LDA $07                  ; track's left edge = centre - 12; with its end caps
	SEC                      ; it needs 8 pixels on each side to stay on screen
	SBC.w #12
	BMI .off
	CMP.w #$0008
	BCC .off
	CMP.w #$00E1
	BCS .off
	STA.l !BarX,X
	LDA $17
	BMI .off
	CMP.w #!YMin
	BCC .off
	CMP.w #!YMax+1
	BCS .off
	STA.l !BarY,X
	LDA.l SlotBit,X
	ORA.l !Seen
	STA.l !Seen
	LDA $13                  ; redraw if the code changed...
	CMP.l !Code,X
	BNE .draw
	STX $15                  ; ...or the game overwrote our cells
	JSR FirstCell
	STA $1B
	LDA.l SlotBase,X
	TAX
	LDA.l !Shadow+2,X
	LDX $15
	CMP $1B
	BEQ .off
	LDA $13
.draw
	STA.l !Code,X
	JMP DrawSlot
.off
	RTS


; Clear rows 28-31 of the BG3 copy, free every bar slot, send our tiles.
Setup:
	LDX.w #$00FE
	LDA.w #$00FF
-	STA.l !Shadow+$700,X
	DEX
	DEX
	BPL -
	LDX.w #$000E
-	LDA.w #$0000
	STA.l !Owner,X
	LDA.w #$FFFF
	STA.l !Code,X
	DEX
	DEX
	BPL -
	LDA.w #$0000
	STA.l !Owned
	STZ $1B
	LDA.l !Swept             ; (once per session)
	CMP.w #$5A5A
	BEQ .swept
	LDA.w #$5A5A
	STA.l !Swept
	LDX.w #$0480-2           ; an earlier build drew bars into rows 5-22 with
-	LDA.l !Shadow+$140,X     ; tiles $001-$006: if a save state from it left any,
	AND.w #$03FF             ; blank them and send those rows once
	DEC
	CMP.w #$0006
	BCS +
	LDA.w #$00FF
	STA.l !Shadow+$140,X
	STA $1B
+	DEX
	DEX
	BPL -
	LDA $1B
	CMP.w #$00FF
	BNE .swept
	JSR QueueOldRows
.swept
	LDA.w #$000F
	STA.l !Dirty
	STA $23
	LDA.w #!TableA&$FFFF
	STA.l !Ready
	LDA.l !Ticks             ; stale until BuildTable runs
	SEC
	SBC.w #$0010
	STA.l !Stamp
	LDA.w #$0001
	STA.l !Active
	RTS


; X = bar slot * 2, A = code: draw it (left cap, 3 fill cells, right cap).
DrawSlot:
	STA $1B
	LDA.l RowBit,X
	ORA.l !Dirty
	STA.l !Dirty
	LDA.l SlotTile,X
	STA $21                  ; tile set: upper or lower half of the map row
	LDA $1B
	AND.w #$1C00
	ORA.w #!Pri
	STA $1D                  ; fill palette + priority
	LDA $1B
	AND.w #!StepMask
	STA $1F                  ; steps left to draw
	LDA.l SlotBase,X
	TAX                      ; X = cell offset in the BG3 copy
	LDA $1B                  ; left cap: spell diamond, buff arrow or plain
	BIT.w #!CastFlag
	BEQ +
	LDA.w #6
	ORA $1D
	BRA .cap
+	BIT.w #!UpFlag
	BEQ +
	LDA.w #7|$0400|!Pri      ; green up arrow
	BRA .cap
+	BIT.w #!DownFlag
	BEQ +
	JSR RedArrow             ; red down arrow
	BRA .cap
+	LDA.w #5
	ORA $1D
.cap
	CLC
	ADC $21
	STA.l !Shadow,X
	LDY.w #$0003
.cell
	INX
	INX
	LDA $1F                  ; this cell: min(steps left, 4)
	CMP.w #$0004
	BCC +
	LDA.w #$0004
+	STA $0F
	LDA $1F
	SEC
	SBC $0F
	STA $1F
	LDA $0F
	CLC
	ADC $21
	ORA $1D
	STA.l !Shadow,X
	DEY
	BNE .cell
	INX
	INX
	LDA $1B                  ; right cap: plain, or the down arrow (mirrored) when
	AND.w #!UpFlag|!DownFlag ; the left end has the up arrow
	CMP.w #!UpFlag|!DownFlag
	BNE +
	JSR RedArrow
	ORA.w #$4000             ; horizontal flip
	BRA ++
+	LDA.w #9
	ORA $1D
++	CLC
	ADC $21
	STA.l !Shadow,X
	RTS

; $1B = bar code -> A = the down-arrow cap cell (before the tile set is added):
; palette 5 if the code says so (!RedFlag), else palette 3.
RedArrow:
	LDA $1B
	AND.w #!RedFlag
	BEQ +
	LDA.w #8|$1400|!Pri
	RTS
+	LDA.w #8|$0C00|!Pri
	RTS


; X = bar slot * 2: blank its 5 cells.
ClearSlot:
	LDA.l RowBit,X
	ORA.l !Dirty
	STA.l !Dirty
	LDA.l SlotBase,X
	TAX
	LDA.w #$00FF
	STA.l !Shadow,X
	STA.l !Shadow+2,X
	STA.l !Shadow+4,X
	STA.l !Shadow+6,X
	STA.l !Shadow+8,X
	RTS


; A = code, X = bar slot * 2 -> A = the tilemap value of the first fill cell.
FirstCell:
	PHA
	AND.w #!StepMask
	CMP.w #$0004
	BCC +
	LDA.w #$0004
+	CLC
	ADC.l SlotTile,X
	ORA.w #!Pri
	STA $1B
	PLA
	AND.w #$1C00
	ORA $1B
	RTS


; Check one BG3 row of the battle area (5-22) per frame for game text (the
; target name), every other cell: bars stay off those lines.
ScanRows:
	LDA.l !Counter           ; every other frame (HUD tags take the others)
	LSR
	BCS +
	RTS
+	LDA.l !ScanRow
	CMP.w #$0005
	BCC .wrap
	CMP.w #$0017
	BCC +
.wrap
	LDA.w #$0005
+	STA $0F                  ; row
	INC
	STA.l !ScanRow
	LDA $0F
	XBA
	LSR
	LSR
	TAX                      ; row * 64
	LDA.w #$0010
	STA $11                  ; cells left to check
	STZ $13                  ; non-blank cells
-	LDA.l !Shadow,X
	AND.w #$03FF
	CMP.w #$00FF
	BEQ +
	INC $13
+	INX
	INX
	INX
	INX
	DEC $11
	BNE -
	LDX $0F
	SEP #$20
	LDA $13
	STA.l !RowBusy,X
	REP #$20
	RTS


; Build the HDMA table for the bars in !Seen into the buffer the NMI isn't using.
BuildTable:
	LDX.w #$0000             ; collect shown slots, insertion-sorted by y
	STZ $1D                  ; count * 2
.collect
	LDA.l !Seen
	AND.l SlotBit,X
	BEQ .nextSlot
	STX $1F                  ; slot to insert
	LDA.l !BarY,X
	STA $21                  ; its y
	LDY $1D                  ; shift bigger ones up
.shift
	CPY.w #$0000
	BEQ .put
	TYX
	LDA.l !Order-2,X
	TAX
	LDA.l !BarY,X
	CMP $21
	BCC .put
	BEQ .put
	TYX
	LDA.l !Order-2,X
	STA.l !Order,X
	DEY
	DEY
	BRA .shift
.put
	TYX
	LDA $1F
	STA.l !Order,X
	LDA $1D
	INC
	INC
	STA $1D
	LDX $1F
.nextSlot
	INX
	INX
	CPX.w #$0010
	BCC .collect

	LDA.l !Ready             ; write into the other buffer
	CMP.w #!TableA&$FFFF
	BEQ +
	LDA.w #!TableA&$FFFF
	BRA ++
+	LDA.w #!TableB&$FFFF
++	STA $25                  ; table start (bank $7E)
	STA $29                  ; write pointer
	LDA.w #-1-!LineCal       ; HDMA starts at line 0 (one line above the picture)
	STA $27                  ; line the table has reached (signed)
	STZ $15                  ; first line the next band may use
	STZ $1F                  ; index into the order list
.band
	LDA $1F
	CMP $1D
	BCC +
	JMP .finish
+	TAX
	LDA.l !Order,X
	STA $21                  ; slot * 2
	TAX
	LDA.l !BarY,X            ; push it below the previous band if they touch
	CMP $15
	BCS +
	LDA $15
+	CMP.w #!YMax+1
	BCC +
	JMP .finish              ; no room left on screen
+	STA $19                  ; band top line
	JSR BandBusy             ; game text on these lines: leave this bar out
	BCC +
	JMP .nextBand
+	LDA $19
	SEC                      ; gap lines with normal scroll (count <= 127 each)
	SBC $27
	STA $1B
.gap
	LDA $1B
	BEQ .gapDone
	CMP.w #$0080
	BCC +
	LDA.w #$007F
+	STA $13
	JSR EmitNormal
	LDA $1B
	SEC
	SBC $13
	STA $1B
	BRA .gap
.gapDone
	LDX $21                  ; the band: 4 lines scrolled onto the bar's map row
	LDA.l SlotBgX,X          ; HOFS = bar cell's map x - left edge
	SEC
	SBC.l !BarX,X
	AND.w #$03FF
	STA $13
	LDA.l SlotBgY,X          ; VOFS = bar's map line - screen line
	SEC
	SBC $19
	CLC
	ADC.w #!VCal
	AND.w #$03FF
	STA $1B
	LDX $29
	SEP #$20
	LDA.b #!BandH
	STA.l $7E0000,X
	REP #$20
	LDA $13
	STA.l $7E0001,X
	LDA $1B
	STA.l $7E0003,X
	TXA
	CLC
	ADC.w #$0005
	STA $29
	LDA $19
	CLC
	ADC.w #!BandH
	STA $27                  ; the table now reaches the band's end
	INC
	STA $15                  ; and the next band keeps a 1-line gap
.nextBand
	LDA $1F
	INC
	INC
	STA $1F
	JMP .band
.finish
	LDA.w #223               ; normal scroll down to the last visible line, which
	SEC                      ; gets BG3 row 27 (blank): with scroll 0 it would show
	SBC $27                  ; the top pixel row of row 28 (bars, info panel)
	BEQ .last
	BMI .last
	STA $1B
-	LDA $1B
	CMP.w #$0080
	BCC +
	LDA.w #$007F
+	STA $13
	JSR EmitNormal
	LDA $1B
	SEC
	SBC $13
	STA $1B
	BNE -
.last
	LDX $29
	JSR EmitLastLine
	LDA $25
	STA.l !Ready
	LDA.l !Ticks
	STA.l !Stamp
	RTS

; X = write pointer: the table's last line (BG3 VOFS -1: shows row 27, blank) and
; the end marker.
EmitLastLine:
	SEP #$20
	LDA.b #$01
	STA.l $7E0000,X
	LDA.b #$00
	STA.l $7E0005,X
	REP #$20
	LDA.w #$0000
	STA.l $7E0001,X
	LDA.w #$03FF
	STA.l $7E0003,X
	RTS

; Write a table entry: $13 lines with BG3 scroll 0,0 at the write pointer $29.
EmitNormal:
	LDX $29
	SEP #$20
	LDA $13
	STA.l $7E0000,X
	REP #$20
	LDA.w #$0000
	STA.l $7E0001,X
	STA.l $7E0003,X
	TXA
	CLC
	ADC.w #$0005
	STA $29
	LDA $27                  ; the next line is now further down
	CLC
	ADC $13
	STA $27
	RTS

; $19 = band top line -> carry set if the game shows BG3 text on its rows.
BandBusy:
	LDA $19
	LSR
	LSR
	LSR
	TAX
	LDA.l !RowBusy,X
	AND.w #$00FF
	BNE .busy
	LDA $19
	CLC
	ADC.w #!BandH-1
	LSR
	LSR
	LSR
	TAX
	LDA.l !RowBusy,X
	AND.w #$00FF
	BNE .busy
	CLC
	RTS
.busy
	SEC
	RTS


; Value $0B out of max $0D (max > 0) -> A = filled steps, 0-12.
FillSteps:
	LDA $0D
.scale
	CMP.w #$1000             ; keep value * 12 in 16 bits
	BCC +
	LSR
	LSR $0B
	BRA .scale
+	STA $0D
	LDA $0B                  ; t = value * 12
	ASL
	CLC
	ADC $0B
	ASL
	ASL
	STA $0F
	LDY.w #$0000             ; n = filled steps
	LDA $0D
.fill
	CMP $0F                  ; while max*(n+1) <= t
	BEQ .more
	BCS .got
.more
	INY
	CPY.w #!Steps
	BCS .got
	CLC
	ADC $0D
	BRA .fill
.got
	TYA
	RTS


; A = steps -> A = steps | palette: green, yellow, red; flashing red/gold when full.
RevengeColour:
	CMP.w #!Steps
	BCS .full
	CMP.w #$0005
	BCS +
	ORA.w #$0400             ; 0-4: green (palette 1)
	RTS
+	CMP.w #$0009
	BCS +
	ORA.w #$0800             ; 5-8: yellow (palette 2)
	RTS
+	ORA.w #$0C00             ; 9-11: red (palette 3)
	RTS
.full
	LDA.l !Counter
	AND.w #$0010             ; swap about every 16 frames
	BEQ +
	LDA.w #!Steps|$1000      ; gold (palette 4)
	RTS
+	LDA.w #!Steps|$0C00      ; red
	RTS


; Party buff icons beside the HUD blocks (one block every other frame): one
; 8x8 icon per changed stat (sword, shield, wand, shining shield, reticle,
; boot, heart, drop, ghost), green = raised, red = lowered, gold = Lucid
; Barrier; raised ones first. Bottom block: right of it, 2 rows of 9; top
; blocks: 2 rows of 5 each in the gap between them. All 9 always fit.
HudTags:
	LDA.l !RedPal            ; the red icons change palette: redo all three blocks
	CMP.l !LastRed           ; now (the colours in CGRAM change in this NMI)
	BEQ +
	STA.l !LastRed
	JSR HudBlock
	JSR HudBlock
	JMP HudBlock
+	LDA.l !Counter
	AND.w #$0001
	BEQ HudBlock
	RTS

HudBlock:                    ; the next block in turn
	STZ $0B                  ; HUD rows changed: bit 0 = rows 1-2, bit 1 = rows 23-24
	LDA.l !HudBlock          ; this frame's block * 2: 0 bottom, 2 top right, 4 top left
	CMP.w #$0006
	BCC +
	LDA.w #$0000
+	TAX
	INC
	INC
	STA.l !HudBlock
	STX $01
	STZ $05                  ; tags * 2
	JSR BlockRecord          ; $03 = party member shown in this block, carry = shown
	STZ $11                  ; signature: record, stat bytes, shown
	STZ $13
	BCC +
	LDX $03
	LDA.w $00C5,X
	STA $11
	LDA.w $00C7,X
	AND.w #$00FF
	ORA.w #$8000
	ORA.l !RedPal            ; (and the red icons' palette)
	STA $13
+	LDA $01                  ; block * 6
	ASL
	CLC
	ADC $01
	TAX
	LDA $03
	CMP.l !HudSig,X
	BNE .changed
	LDA $11
	CMP.l !HudSig+2,X
	BNE .changed
	LDA $13
	CMP.l !HudSig+4,X
	BNE .changed
	LDA $01                  ; unchanged: just check the game left our cells alone
	ASL                      ; (every cell of the first row: the game's HP text can
	ASL                      ; blank the one next to it)
	CLC
	ADC $01
	ASL
	TAX                      ; block * 20 (BlockRows)
	LDA.l BlockRows+2,X
	STA $17                  ; cells
	LDA.l BlockRows+4,X
	STA $15
	LDA.l BlockRows,X
	STA $19
-	LDX $19
	LDA.l !Shadow,X
	LDX $15
	CMP.l !HudLast,X
	BNE .changed
	INC $15
	INC $15
	INC $19
	INC $19
	DEC $17
	BNE -
	RTS
.changed
	LDA $01                  ; (block * 6 again)
	ASL
	CLC
	ADC $01
	TAX
	LDA $03
	STA.l !HudSig,X
	LDA $11
	STA.l !HudSig+2,X
	LDA $13
	STA.l !HudSig+4,X
	LDX $01
	LDA $13                  ; shown?
	BEQ +
	JSR CollectTags
+	JSR RenderTags
	LDA $0B
	LSR
	BCC +
	PHA
	LDA.w #$0040             ; rows 1-2
	JSR QueueHudRows
	PLA
+	LSR
	BCC +
	LDA.w #$05C0             ; rows 23-24
	JSR QueueHudRows
+	RTS

; X = HUD block * 2 -> $03 = the party member the block shows, carry set if
; found. Read from the HUD's own digits ("cur/max" HP in the big font): the
; record whose max HP (+$A2) matches; current HP (+$92) breaks ties. (The
; HUD task keeps its own per-block list at its direct page + $26, but that
; page moves from session to session.)
BlockRecord:
	STZ $03
	LDA.l BlockHpCell,X
	STA $0F                  ; first cell of the block's HP row
	LDA.w #$000A
	STA $11                  ; cells left to look at
	STZ $19                  ; current HP (digits before the slash)
.find
	LDX $0F
	LDA.l !Shadow,X
	AND.w #$03FF
	CMP.w #$002A             ; '/'
	BEQ .slash
	SEC
	SBC.w #$0020             ; big digits $020-$029
	CMP.w #$000A
	BCC +
	STZ $19                  ; not a digit: start over
	BRA .step
+	STA $15
	LDA $19                  ; current = current * 10 + digit
	ASL
	STA $17
	ASL
	ASL
	CLC
	ADC $17
	CLC
	ADC $15
	STA $19
.step
	INC $0F
	INC $0F
	DEC $11
	BNE .find
	CLC                      ; no slash: the block isn't on screen
	RTS
.slash
	STZ $13                  ; max HP (digits after the slash)
.digit
	INC $0F
	INC $0F
	DEC $11
	BEQ .parsed
	LDX $0F
	LDA.l !Shadow,X
	AND.w #$03FF
	SEC
	SBC.w #$0020
	CMP.w #$000A
	BCS .parsed
	STA $15
	LDA $13
	ASL
	STA $17
	ASL
	ASL
	CLC
	ADC $17
	CLC
	ADC $15
	STA $13
	BRA .digit
.parsed
	LDA $13
	BEQ .none
	LDX.w #$0000             ; max HP and current HP both match
.match1
	LDA.l !Entities,X
	BEQ .next1
	TAY
	LDA.w $00A2,Y
	CMP $13
	BNE .next1
	LDA.w $0092,Y
	CMP $19
	BEQ .found
.next1
	INX
	INX
	CPX.w #$0006
	BCC .match1
	LDX.w #$0000             ; max HP alone (current HP may still be rolling)
.match2
	LDA.l !Entities,X
	BEQ .next2
	TAY
	LDA.w $00A2,Y
	CMP $13
	BEQ .found
.next2
	INX
	INX
	CPX.w #$0006
	BCC .match2
.none
	CLC
	RTS
.found
	STY $03
	SEC
	RTS

; $03 = party record -> !TagList: cell values of its icons (raised ones
; first, then lowered), $05 = count * 2.
CollectTags:
	LDA $03
	STA $07
	LDA.w #$007F
	STA $09                  ; [$07] = the record
	STZ $05
	STZ $19                  ; pass: 0 raised, 2 lowered
.pass
	LDX.w #$0000             ; TagDefs offset (8 bytes each)
	STZ $0D                  ; icon number
.def
	LDA.l TagDefs,X          ; record offset of the stat-change byte
	TAY
	LDA [$07],Y
	AND.l TagDefs+2,X        ; this stat's 2-bit field
	BEQ .skip
	LDY $19
	BNE .lowered
	CMP.l TagDefs+4,X        ; raised?
	BNE .skip
	LDA $0D
	CMP.w #$0008             ; Lucid Barrier: gold
	BNE +
	LDA.w #!TagTile+8|$1000|!Pri
	BRA .add
+	CLC
	ADC.w #!TagTile|$0400|!Pri   ; green
	BRA .add
.lowered
	CMP.l TagDefs+6,X        ; lowered?
	BNE .skip
	LDA $0D
	CLC
	ADC.w #!TagTile|!Pri
	ORA.l !RedPal            ; red (palette 3 or 5)
.add
	PHX
	LDX $05
	STA.l !TagList,X
	PLX
	INC $05
	INC $05
.skip
	INC $0D
	TXA
	CLC
	ADC.w #$0008
	TAX
	CPX.w #8*9
	BCC .def
	LDA $19
	BNE +
	LDA.w #$0002
	STA $19
	BRA .pass
+	RTS

; $01 = HUD block * 2, $05 = icons * 2 in !TagList -> update the block's icon
; cells: 2 rows (BlockRows), filled in order, left- or right-aligned.
RenderTags:
	LDA $01
	ASL
	ASL
	CLC
	ADC $01
	ASL
	STA $0D                  ; BlockRows offset of the row (block * 20)
	STZ $11                  ; icons placed * 2
	LDA.w #$0002
	STA $0F                  ; rows left
.row
	LDX $0D
	LDA.l BlockRows,X
	STA $1F                  ; first cell in the BG3 copy
	LDA.l BlockRows+4,X
	STA $1D                  ; its place in !HudLast
	LDA.l BlockRows+8,X
	STA $1B                  ; HUD row pair to upload if it changes
	LDA $05                  ; icons left
	SEC
	SBC $11
	LSR
	CMP.l BlockRows+2,X      ; this row holds at most its width
	BCC +
	LDA.l BlockRows+2,X
+	STA $13                  ; icons in this row
	LDA.l BlockRows+6,X      ; right-aligned: start further in
	BEQ +
	LDA.l BlockRows+2,X
	SEC
	SBC $13
+	STA $15                  ; first cell with an icon
	STZ $17                  ; cell
.cell
	LDA $17
	SEC
	SBC $15
	BCC .blank
	CMP $13
	BCS .blank
	ASL
	CLC
	ADC $11
	TAX
	LDA.l !TagList,X
	BRA .put
.blank
	LDA.w #$00FF
.put
	JSR PutCell
	INC $17
	LDX $0D
	LDA $17
	CMP.l BlockRows+2,X
	BCC .cell
	LDA $13
	ASL
	CLC
	ADC $11
	STA $11
	LDA $0D
	CLC
	ADC.w #10
	STA $0D
	DEC $0F
	BNE .row
	RTS

; A = desired cell; $1F = its offset in the BG3 copy, $1D = in !HudLast (both
; advance). A blank is only written over a cell we drew ourselves.
PutCell:
	STA $21
	LDX $1F
	LDA.l !Shadow,X
	CMP $21
	BEQ .same
	LDA $21
	CMP.w #$00FF
	BNE .write
	LDX $1D                  ; clearing: only if the cell is still what we drew
	LDA.l !HudLast,X
	LDX $1F
	CMP.l !Shadow,X
	BNE .same
	LDA.w #$00FF
.write
	STA.l !Shadow,X
	LDA $0B
	ORA $1B
	STA $0B
.same
	LDX $1D
	LDA $21
	STA.l !HudLast,X
	INC $1D
	INC $1D
	INC $1F
	INC $1F
	RTS

; A = offset of a HUD row pair in the BG3 copy: upload those 2 rows.
QueueHudRows:
	STA $1F
	LDA.w #$0001
	JSL $C00560
	LDA.w #$007E
	STA.w $0006,X
	LDA $1F
	CLC
	ADC.w #!Shadow
	STA.w $0004,X
	LDA.w #$0080
	STA.w $0007,X
	LDA $1F
	LSR
	CLC
	ADC.w #$5800
	STA.w $000B,X
	JSL $C00568
	RTS


; Upload the changed rows of 28-31 (whole rows, lowest..highest changed).
QueueRows:
	LDX.w #$0000             ; lowest changed row
-	LSR
	BCS +
	INX
	BRA -
+	STX $1B
	LDA.l !Dirty
	LDX.w #$0000             ; highest changed row + 1 = shifts until empty
-	INX
	LSR
	BNE -
	TXA
	SEC
	SBC $1B
	XBA
	LSR
	LSR
	STA $1D                  ; byte count = rows * 64
	LDA $1B
	XBA
	LSR
	LSR
	CLC
	ADC.w #$0700
	STA $1F                  ; offset in the BG3 copy
	LDA.w #$0001             ; job type $01: plain VRAM upload (see header)
	JSL $C00560              ; X = job record (bank $7F)
	LDA.w #$007E
	STA.w $0006,X            ; source bank (word store: size goes in after)
	LDA $1F
	CLC
	ADC.w #!Shadow
	STA.w $0004,X            ; source address
	LDA $1D
	STA.w $0007,X            ; size
	LDA $1F
	LSR
	CLC
	ADC.w #$5800
	STA.w $000B,X            ; VRAM word address
	JSL $C00568              ; submit
	RTS


; Upload rows 5-22 of the BG3 copy (after clearing old-style bar cells).
QueueOldRows:
	LDA.w #$0001
	JSL $C00560
	LDA.w #$007E
	STA.w $0006,X
	LDA.w #!Shadow+$140
	STA.w $0004,X
	LDA.w #$0480
	STA.w $0007,X
	LDA.w #$5800+$00A0
	STA.w $000B,X
	JSL $C00568
	RTS


; Upload our tiles to BG3 tiles $0C0-$0D3 (VRAM words $0600-$069F).
QueueTiles:
	LDA.w #$0001
	JSL $C00560
	LDA.w #BarGfx>>16
	STA.w $0006,X
	LDA.w #BarGfx
	STA.w $0004,X
	LDA.w #BarGfxEnd-BarGfx
	STA.w $0007,X
	LDA.w #!TileBase*8       ; BG3 characters start at VRAM $0000, 8 words per tile
	STA.w $000B,X
	JSL $C00568
	RTS


; NMI, after the game's uploads (was LDA $0032 : STA $00420C). Points HDMA
; channel 1 at the newest bar table and enables it if it's fresh.
NmiHdma:
	PHP
	REP #$30
	PHX
	SEP #$20
	LDA.b #$FF               ; (NmiRed may hold the game's channels back)
	STA.l !Keep
	LDA.l $00213F            ; which line is it? (read the way the game's NMI does)
	LDA.l $002137            ; latch the counters (the read above reset the read order)
	LDA.l $00213D            ; V, low byte
	XBA
	LDA.l $00213D            ; V, bit 8
	AND.b #$01
	XBA
	REP #$20
	CMP.w #225               ; a long upload ran us into the next frame: HDMA
	BCC .off                 ; would start mid-picture, so skip this frame
	JSR NmiRed               ; (still in vblank: CGRAM 21-23 for the red marks)
	LDA.l $7F0805            ; BG3 taken over by a spell effect: stay off
	AND.w #$0008
	BEQ .off
	LDA.l !Active
	BEQ .off
	LDA.l !Ticks
	SEC
	SBC.l !Stamp
	CMP.w #$0003             ; built in the last 2 frames?
	BCC +
	CMP.w #$0010             ; the level-up info panel: 15 (the game skips Bars for
	BCS .off                 ; a few frames at a time while the stat ring turns)
	LDA.l !PanelOn
	BEQ .off
+
	LDA.l !Ready
	STA.l $004312            ; table address
	SEP #$20
	LDA.b #!Ram>>16
	STA.l $004314            ; table bank
	LDA.b #$03
	STA.l $004310            ; direct, 2 registers x 2 bytes
	LDA.b #$11
	STA.l $004311            ; $2111 BG3HOFS, $2112 BG3VOFS
	LDA.l $7F0032            ; the game's HDMA channels (2-7 during spell effects)
	ORA.b #$02
	BRA .set
.off
	SEP #$20
	LDA.l $7F0032
.set
	AND.l !Keep
	STA.l $00420C
	REP #$10
	PLX
	PLP
	RTL

; NMI, in vblank, after the game's colour uploads (A/X 16-bit). While Bars asks
; for it (!Borrow) and the game turns no HDMA on this frame (every window is
; drawn through HDMA), CGRAM 21-23 (BG3 palette 5 colours 1-3, window colours
; otherwise) = palette 3's steady middle shades ($7E:3020 table), for red marks
; drawn in palette 5. Otherwise the window colours go back, from the game's
; CGRAM copy ($7E:4800), once. When the game turns HDMA on while our red is
; in place, its channels stay off (!Keep) for up to 3 frames, until Bars has
; moved the marks back to palette 3 (it then stops asking): the window opens
; that much later instead of showing the marks in window colours.
NmiRed:
	LDA.l !Borrow
	BEQ .give
	DEC                      ; (runs out by itself 16 frames after Bars stops)
	STA.l !Borrow
	LDA.l $7F0032
	AND.w #$00FF
	BEQ .take
	LDA.l !Borrowed          ; HDMA wanted while the marks use our red: hold it
	BEQ .give
	LDA.l !Held
	CMP.w #$0003
	BCS .give
	INC
	STA.l !Held
	SEP #$20
	LDA.b #$03               ; only channels 0-1 (ours) this frame
	STA.l !Keep
	REP #$20
	BRA .ours                ; (the game may have just re-sent CGRAM 21-23)
.take
	LDA.w #$0000
	STA.l !Held
.ours
	LDA.w #$0001
	STA.l !Borrowed
	LDX.w #$303A             ; palette 3 colours 1-3, middle step
	BRA .write
.give
	LDA.w #$0000
	STA.l !Held
	LDA.l !Borrowed
	BEQ .done
	LDA.w #$0000
	STA.l !Borrowed
	LDX.w #$482A             ; game's copy of CGRAM 21-23
.write
	SEP #$20
	LDA.b #21
	STA.l $002121
	LDA.l $7E0000,X
	STA.l $002122
	LDA.l $7E0001,X
	STA.l $002122
	LDA.l $7E0002,X
	STA.l $002122
	LDA.l $7E0003,X
	STA.l $002122
	LDA.l $7E0004,X
	STA.l $002122
	LDA.l $7E0005,X
	STA.l $002122
	REP #$20
.done
	RTS


; Palette for the red buff marks this frame -> !RedPal: palette 3, steady
; unless a critical HP digit needs its flicker (!Warn bit 1, see PulseFix);
; then palette 5, whose colours the NMI borrows (NmiRed), as long as nothing
; uses HDMA (windows) and a mark feature is on.
RedPalette:
	LDA.w #$0C00
	STA.l !RedPal
	LDA.l FeatHudIcons
	AND.l FeatMarkers
	AND.l FeatLevelInfo      ; (the info panel's stat name is red too)
	BMI +
	LDA.l !Warn
	AND.w #$0002
	BEQ +
	LDA.l $7F0032
	AND.w #$00FF
	BNE +
	LDA.w #$1400
	STA.l !RedPal
+	RTS


incsrc "../build/bargfx.asm"

SlotBit:
	dw $0001, $0002, $0004, $0008, $0010, $0020, $0040, $0080
RowBit:
	dw $0001, $0001, $0002, $0002, $0004, $0004, $0008, $0008
SlotTile:                    ; tile set: upper half / lower half of the map row
	dw !TileBase, !TileBase+10, !TileBase, !TileBase+10, !TileBase, !TileBase+10, !TileBase, !TileBase+10
SlotBase:                    ; byte offset of the left cap cell in the BG3 copy
	dw $0700, $0720, $0740, $0760, $0780, $07A0, $07C0, $07E0
SlotBgX:                     ; map x of the first fill cell
	dw $0008, $0088, $0008, $0088, $0008, $0088, $0008, $0088
SlotBgY:                     ; map line of the bar's top pixel row
	dw 224, 228, 232, 236, 240, 244, 248, 252

; HUD tags. Font tiles: A-Z = $04A-$063, digits $080-$089, '+' $03D, up arrow
; $02E, down arrow $02F, blank $0FF.
BlockHpCell:                 ; first cell of each block's HP row ("cur/max" HP)
	dw (23*32+11)*2, (1*32+21)*2, (1*32+1)*2
BlockRows:                   ; per block, 2 rows: first cell, cells, !HudLast offset, right-aligned, upload bit
	dw (23*32+22)*2, 9, $00, 0, 2    ; bottom block: right of it, rows 23-24
	dw (24*32+22)*2, 9, $12, 0, 2
	dw (1*32+16)*2, 5, $24, 1, 1     ; top right block: left of it, rows 1-2 (column 21
	dw (2*32+16)*2, 5, $2E, 1, 1     ; is the game's HP field: it blanks our icon there)
	dw (1*32+11)*2, 5, $38, 0, 1     ; top left block: right of it, rows 1-2
	dw (2*32+11)*2, 5, $42, 0, 1
TagDefs:                     ; record offset, field mask, raised, lowered (icon order)
	dw $00C5, $00C0, $0040, $0080    ; Attack power (sword)
	dw $00C6, $000C, $0004, $0008    ; Defense power (shield)
	dw $00C6, $0030, $0010, $0020    ; Magic effectiveness (wand)
	dw $00C6, $00C0, $0040, $0080    ; Magic defense (shining shield)
	dw $00C5, $0030, $0010, $0020    ; Hit rate (reticle)
	dw $00C5, $000C, $0004, $0008    ; Evade rate (boot)
	dw $00C7, $0030, $0010, $0020    ; Maximum HP (heart)
	dw $00C7, $000C, $0004, $0008    ; Maximum MP (drop)
	dw $00C7, $00C0, $0040, $FFFF    ; Lucid Barrier (ghost), gold

assert pc() <= FeatRevenge      ; the feature switches follow (menuspeed.asm starts at $CB:F500)


; CastStart runs once per cast, so it can live in slow ROM.
org $56A000
; Cast start: X = the mod's computed cast value, [D+$34] = caster's battle
; stats (entity record + $90), D = the caster's script thread page.
; Records the length of the wait that follows (value + 1 ticks) with no timer
; yet and no steps shown, then continues to $C40018. (The cast book keeps the
; length in 12 bits: a wait of 4096 ticks or more, over a minute, gets no bar.)
CastStart:
	PHP
	REP #$30
	PHX
	PHY
	PHA
	LDA $34
	SEC
	SBC.w #$0090
	PHA                      ; [1,S] = caster's entity record
	LDX.w #$0000
.find
	LDA.l !Entities,X
	CMP $01,S
	BEQ .found
	INX
	INX
	CPX.w #$0020
	BCC .find
	BRA .done
.found
	TXA
	ASL
	TAX                      ; X = slot * 4
	LDA.w #$0000             ; its wait timer: Bars finds it in the timer list
	STA.l !CastBook,X
	LDA $07,S                ; cast value: the script then waits value + 1 ticks
	INC
	CMP.w #$1000
	BCC +
	LDA.w #$0000
+	STA.l !CastBook+2,X
.done
	PLA
	PLA
	PLY
	PLX
	PLP
	JML $C40018


; HUD flicker step (C4:5EF5, every other frame): the game just copied this
; step's shades of BG3 palettes 0-3 colours 2-3 into its CGRAM copy ($7E:4800).
; Keep palette 1 on its middle shades (table at $7E:3020), and palettes 2 and 3
; too while no HP digit is shown in them (the low / critical HP flicker), so our
; marks, bars and the level-up panel don't flicker. Nothing changes while no
; feature using palettes 1-3 is on. X/Y as the step left them.
PulseFix:
	PHP
	REP #$30
	PHX
	PHY
	LDA.l FeatRevenge
	AND.l FeatMarkers
	AND.l FeatHudIcons
	AND.l FeatLevelInfo
	BMI .done
	JSR Warnings
	STA.l !Warn
	LDA.l $7E302C            ; palette 1 colours 2-3 (green)
	STA.l $7E480C
	LDA.l $7E302E
	STA.l $7E480E
	LDA.l !Warn
	LSR
	BCS +
	LDA.l $7E3034            ; palette 2 (yellow)
	STA.l $7E4814
	LDA.l $7E3036
	STA.l $7E4816
+	LDA.l !Warn
	AND.w #$0002
	BNE .done
	LDA.l $7E303C            ; palette 3 (red)
	STA.l $7E481C
	LDA.l $7E303E
	STA.l $7E481E
.done
	PLY
	PLX
	LDA.l $7F0330            ; the replaced code: have the colours uploaded
	ORA.w #$0004
	STA.l $7F0330
	PLP
	RTL

; -> A: bit 0 = an HP digit (big font, tiles $020-$029) shown in palette 2 (low
; HP), bit 1 = one in palette 3 (critical or 0 HP). HP rows as in BlockHpCell.
Warnings:
	LDY.w #$0000
	LDX.w #(23*32+11)*2
	JSR .row
	LDX.w #(1*32+21)*2
	JSR .row
	LDX.w #(1*32+1)*2
	JSR .row
	TYA
	RTS
.row
	LDA.w #10
	PHA                      ; cells left, at 1,S
.cell
	LDA.l !Shadow,X
	AND.w #$03FF
	SEC
	SBC.w #$0020
	CMP.w #$000A
	BCS .next
	LDA.l !Shadow,X
	AND.w #$1C00
	CMP.w #$0800
	BNE +
	TYA
	ORA.w #$0001
	TAY
	BRA .next
+	CMP.w #$0C00
	BNE .next
	TYA
	ORA.w #$0002
	TAY
.next
	INX
	INX
	LDA $01,S
	DEC
	STA $01,S
	BNE .cell
	PLA
	RTS


; Cast bar of one entity. JSL from Bars for a party member / enemy whose cast
; bar is switched on: X = entity record, $01 = entity slot * 2, DB = $7F, D =
; Bars' locals, A/X/Y 16-bit. -> carry clear: A = bar code (steps, !CastFlag,
; gold once ready); carry set: no cast bar. Uses $0B-$11 (keeps $01-$09).
; Cast book entry (slot * 4), set up by CastStart:
;   +0  the cast's wait timer (bank $7F); 0 = not found yet, $FFFF = ran out
;   +2  bits 0-11 = the bar's length T in ticks, bits 12-15 = steps shown;
;       after it ran out: the tick it did (0 before CastStart: no cast)
; T starts as the wait's length (value + 1) and grows to the largest time left
; seen: right after a ring menu the mod pushes the party's cast waits 16 ticks
; later ($40:2400), so the time left can go up, even above value + 1. The
; steps never go down during a cast: after such a push the bar stands still
; until the time left is back where it was, and it is full exactly when the
; timer runs out.
CastBar:
	LDA.w $0000,X            ; state $0A = casting
	AND.w #$00FF
	CMP.w #$000A
	BNE .none
	LDA $01
	ASL
	TAX                      ; X = slot * 4
	LDA.l !CastBook+2,X
	STA $0D
	LDA.l !CastBook,X        ; its timer record
	CMP.w #$FFFF
	BNE .live
	LDA.l !Ticks             ; ran out ($0D = when): ready until the spell goes
	SEC                      ; off (a few ticks, longer if the ring menu opens
	SBC $0D                  ; meanwhile); stale after 4 s
	CMP.w #240
	BCS .none
.full
	LDA.w #!Steps|!CastFlag|$1000    ; full, gold (palette 4)
	CLC
	RTL
.none
	SEC
	RTL
.live
	LDY $0D                  ; (no cast recorded)
	BEQ .none
	TAY
	BNE .timer
	JSR FindCastTimer        ; not in the timer list yet
	BNE .timer
	LDA.w #!CastFlag         ; meanwhile: an empty bar
	CLC
	RTL
.timer                       ; Y = its timer record
	LDA.w $0008,Y            ; time left, kept there while the timer is suspended
	BEQ +                    ; (ring menu, caster hit)
	BPL .left
	BRA .out
+	LDA.w $0004,Y            ; else wake - clock
	SEC
	SBC.l !Ticks
	BEQ .out
	BMI .out
.left
	CMP.w #$1000
	BCC +
	LDA.w #$0FFF
+	STA $0B                  ; time left
	LDA $0D
	AND.w #$0FFF
	CMP $0B                  ; T = the largest time left seen
	BCS +
	LDA $0B
+	STA $0F
	SEC
	SBC $0B                  ; elapsed = T - left
	ASL
	STA $11
	ASL
	CLC
	ADC $11
	ASL
	STA $11                  ; elapsed * 12
	LDY.w #$0000             ; steps = elapsed * 12 / T
	LDA $0F
.step
	CMP $11                  ; while T * (steps + 1) <= elapsed * 12
	BEQ .more
	BCS .got
.more
	INY
	CLC
	ADC $0F
	BRA .step
.got
	TYA
	XBA
	ASL
	ASL
	ASL
	ASL
	STA $11                  ; steps << 12
	LDA $0D
	AND.w #$F000             ; never fewer than shown before
	CMP $11
	BCS +
	LDA $11
+	ORA $0F
	STA.l !CastBook+2,X
	XBA
	LSR
	LSR
	LSR
	LSR
	AND.w #!StepMask
	ORA.w #!CastFlag         ; filling: blue (palette 0)
	CLC
	RTL
.out                         ; ran out: note when, then full
	LDA.w #$FFFF
	STA.l !CastBook,X
	LDA.l !Ticks
	STA.l !CastBook+2,X
	BRL .full

; X = slot * 4, $0D = its cast book +2 (the wait's length; no steps yet) ->
; A = Y = the wait's timer record (also stored in the cast book; Z clear), or
; A = 0 if it isn't in the timer list yet. The match: a timer of that length
; that started at most 16 ticks ago and isn't another cast's. A record still in
; another slot's entry counts as that cast's only while that entity is casting
; (state $0A); otherwise that entry is stale (cast over, entity gone, the timer
; freed and reused) and is cleared. DB = $7F. Keeps X.
FindCastTimer:
	LDA $0D
	AND.w #$0FFF
	STA $0F                  ; the wait's length
	PHX                      ; [3,S] = slot * 4
	LDA.l !Ticks
	PHA                      ; [1,S] = clock
	LDY.w $00C4              ; timer list
.walk
	BEQ .none
	LDA.w $0006,Y
	CMP $0F
	BNE .next
	LDA.w $0004,Y            ; wake - clock + 16 >= length?
	SEC
	SBC $01,S
	CLC
	ADC.w #16
	CMP $0F
	BCC .next
	LDX.w #$0000             ; not another cast's
.slots
	TYA
	CMP.l !CastBook,X
	BNE .other
	TXA
	LSR
	TAX                      ; slot * 2
	LDA.l !Entities,X
	BEQ .stale
	PHX
	TAX
	LDA.w $0000,X
	PLX
	AND.w #$00FF
	CMP.w #$000A
	BEQ .next                ; that one is casting: not this timer
.stale
	TXA
	ASL
	TAX
	LDA.w #$0000
	STA.l !CastBook,X
	STA.l !CastBook+2,X
.other
	INX
	INX
	INX
	INX
	CPX.w #$0040
	BCC .slots
	PLA
	PLX
	TYA
	STA.l !CastBook,X
	RTS
.next
	LDA.w $0000,Y
	TAY
	BRA .walk
.none
	PLA
	PLX
	LDA.w #$0000
	RTS


; ---------------------------------------------------------------------------
; Level-up info panel (FeatLevelInfo). While the game's level-up stat window is
; on BG3 (frame at rows 6-21, columns 1-16; the six stat names at column 2 of
; rows 10, 12 .. 20; the highlighted one in palette 3), a 5-row panel across the
; top of the screen (cell columns 1-30) shows what that stat does (rows 1-2)
; and, for a character in a final class who hasn't reached Lv60 yet, the
; character's Lv60 capstone for it (rows 3-5; "on track" when taking this +1
; leaves the stat the highest, ties going to the upper one, as $40:7A10 picks
; it). Rows 1-4 live in the off-screen BG3 rows 28-31 (no bars meanwhile; the
; battle is paused) and our HDMA table shows them over the top HUD (lines
; 8-39), so the HUD itself is never touched; row 5 is drawn in place (the
; empty BG3 row above the window). The HUD portraits on those lines (OAM
; entries 0-2, set once by the HUD, see NOTES) are hidden meanwhile. The level byte is still
; the old level while the window is up, and the capstone is taken after the +1
; at the level-up to 60 (record +$B1 0-based: 58 = Lv59 -> 60).
; Texts: tools/make_levelinfo.py -> build/levelinfo.asm (tile numbers).

org $580000                  ; free bank (slow ROM; runs in a few hundred cycles)
; JSL from Bars (D = Bars' locals, DB = $7F, A/X/Y 16-bit) -> carry set while the
; panel is up (rows 28-31 and the HDMA table are its this frame).
LevelPanel:
	LDA.l FeatLevelInfo
	BMI .shop
	JSR LvFindWindow         ; $01 = highlighted stat ($FFFF: none), $1B = BG3 copy
	BCS .found
	CMP.w #$0001             ; its frame is up, the rows are being redrawn: matters
	BNE .shop                ; only while the stat panel is up
	LDA.l !PanelOn
	BEQ .shop
	LDA.l !PanelSig
	BMI .shop
	JMP .redraw
.found                       ; About every 30 frames the game redraws the window: for
	LDA.w #$0000             ; ~5 frames the record itself holds the highlighted stat's
	STA.l !PanelMiss         ; +1 while the rows (names, digits, highlight) go blank and
	LDA $01                  ; come back. Only a whole, settled window is read; on the
	BPL +                    ; other frames the panel stays as it is.
-	JMP .keep
+	JSR LvFindChar           ; $03 = the leveling character's record (0: none matched)
	BCC -                    ; (digits mid-redraw)
	LDA $03
	BNE +
	LDA.l !PanelOn           ; no match: the ring turning (the record has the new
	BNE -                    ; stat's +1, the window still the old one)
+	JSR LvCompose            ; $05 signature, $07 char, $09 capstone line flags
	JSR LvSpells             ; $1F.. the spell line
	LDA $21                  ; its signature: mode | name << 4 | more << 12
	ASL
	ASL
	ASL
	ASL
	ORA $1F
	STA $0D
	LDA $27
	XBA
	ASL
	ASL
	ASL
	ASL
	ORA $0D
	STA $0D
	LDA $05
	CMP.l !PanelSig
	BNE +
	LDA $0D
	CMP.l !PanelSig2
	BEQ .show
+	LDA $05
	STA.l !PanelSig
	LDA $0D
	STA.l !PanelSig2
	JSR LvDraw
	BRA .show
.shop
	LDA.l FeatShopInfo
	BMI .missing
	JSR LvFindShop           ; carry set: $11 = description to show; else A = 1 box up
	BCS +                    ; without one (close now), 0 no box (grace frames)
	CMP.w #$0001
	BNE .missing
	BRA .off
+	LDA.w #$0000
	STA.l !PanelMiss
	LDA $11                  ; (description addresses are $8000+: never a stat panel's)
	CMP.l !PanelSig
	BEQ .show
	STA.l !PanelSig
	JSR LvShopDraw
.show
	JSR LvHideSprites
	JSR LvTable
	LDA.l !PanelOn           ; just opened: send our tiles (the panel's punctuation
	BNE +                    ; lives in the font's kana tiles) with this frame's rows
	INC $23
+	LDA.w #$0001
	STA.l !PanelOn
	SEC
	RTL
.keep                        ; window up but not readable this frame: as it is
	LDA.l !PanelOn
	BEQ .off
	LDA.l !PanelSig
	BMI .off                 ; (that was the shop panel)
	BRA .show
.redraw                      ; frame up, rows being redrawn: keep it up to 16 frames
	LDA.w #16                ; (in case another window has the same frame)
	BRA .grace
.missing                     ; window not there: close after 4 frames in a row
	LDA.w #4
.grace
	STA $0D
	LDA.l !PanelOn
	BEQ .off
	LDA.l !PanelMiss
	INC
	STA.l !PanelMiss
	CMP $0D
	BCS .off
	JSR LvHideSprites        ; meanwhile keep it as it is
	JSR LvTable
	SEC
	RTL
.off
	JSR LvPanelOff
	CLC
	RTL

; -> carry set if the level-up stat window is on BG3, $01 = highlighted stat (0-5,
; $FFFF if none is highlighted this frame); else A = 1 if its frame is there but
; not the stat names (the game is redrawing the rows), 0 if not even the frame.
LvFindWindow:
	LDA.l !Shadow+((6*32+15)*2) ; caster on the left of the screen: the game draws the
	AND.w #$03FF             ; window 14 columns further right (corners at 15 / 30)
	CMP.w #$0040
	BEQ +
	LDA.w #!Shadow&$FFFF
	BRA ++
+	LDA.w #(!Shadow&$FFFF)+(14*2)
++	STA $1B
	LDA.w #!Shadow>>16
	STA $1D
	LDX.w #$0000             ; frame corners and the six stat names
-	LDA.l LvCells,X
	TAY
	LDA [$1B],Y
	AND.w #$03FF
	CMP.l LvCells+2,X
	BNE .no
	INX
	INX
	INX
	INX
	CPX.w #4*10
	BCC -
	LDX.w #4*4               ; the stat name in palette 3 is the highlighted one
-	LDA.l LvCells,X
	TAY
	LDA [$1B],Y
	AND.w #$1C00
	CMP.w #$0C00
	BEQ .found
	INX
	INX
	INX
	INX
	CPX.w #4*10
	BCC -
	LDA.w #$FFFF             ; window up, no stat highlighted right now
	STA $01
	SEC
	RTS
.no
	LDA.w #$0000
	CPX.w #4*4
	BCC +
	INC                      ; corners matched, a name didn't
+	CLC
	RTS
.found
	TXA
	SEC
	SBC.w #4*4
	LSR
	LSR
	STA $01
	SEC
	RTS

LvCells:                     ; BG3-copy offset, tile
	dw (6*32+1)*2, $0040     ; frame corners
	dw (6*32+16)*2, $0042
	dw (21*32+1)*2, $0045
	dw (21*32+16)*2, $0047
	dw (10*32+2)*2, $005C    ; S(trength)
	dw (12*32+2)*2, $004A    ; A(gility)
	dw (14*32+2)*2, $005F    ; V(itality)
	dw (16*32+2)*2, $0052    ; I(ntelligence)
	dw (18*32+2)*2, $005C    ; S(pirit)
	dw (20*32+2)*2, $0055    ; L(uck)

; $01 = highlighted stat -> carry clear if a window value isn't all digits (being
; redrawn); else !PanelVal = the highlighted stat's value as shown (always the
; stat +1, even at its cap) and $03 = record of the party member whose stats
; match the window's values (columns 14-15, small digits $080-$089; the
; highlighted one is left out), 0 if none.
LvFindChar:
	LDX.w #$0000             ; window values -> $0B..$10 (bytes)
	BRA .value
.unread                      ; (a value isn't all digits)
	STZ $03
	CLC
	RTS
.value
-	LDA.l LvCells+16,X
	CLC
	ADC.w #12*2              ; column 14: tens (blank = 0)
	TAY
	LDA [$1B],Y
	AND.w #$03FF
	CMP.w #$00FF
	BNE +
	LDA.w #$0080
+	SEC
	SBC.w #$0080
	CMP.w #10
	BCS .unread
	STA $19
	ASL
	ASL
	CLC
	ADC $19
	ASL
	STA $19                  ; tens * 10 (scratch $19: $0B-$10 hold the values)
	INY
	INY
	LDA [$1B],Y              ; column 15: ones
	AND.w #$03FF
	SEC
	SBC.w #$0080
	CMP.w #10
	BCS .unread
	CLC
	ADC $19
	STA $19
	PHX
	TXA
	LSR
	LSR
	TAX
	SEP #$20
	LDA $19
	STA $0B,X
	REP #$20
	PLX
	INX
	INX
	INX
	INX
	CPX.w #4*6
	BCC -
	LDX $01                  ; the highlighted one as shown
	LDA $0B,X
	AND.w #$00FF
	STA.l !PanelVal
	STZ $03
	LDX.w #$0000             ; party: entity slots 0-2
.slot
	LDA.l !Entities,X
	BEQ .next
	TAY
	LDA.w $0001,Y            ; side 1 = party
	AND.w #$00FF
	CMP.w #$0001
	BNE .next
	TYA
	CLC
	ADC.w #$0096
	STA $11                  ; -> stats (bank $7F = DB)
	PHX
	LDX.w #$0000
-	CPX $01
	BEQ +
	TXY
	SEP #$20
	LDA ($11),Y
	CMP $0B,X
	REP #$20
	BNE .differs
+	INX
	CPX.w #$0006
	BCC -
	PLX
	LDA.l !Entities,X
	STA $03
	SEC
	RTS
.differs
	PLX
.next
	INX
	INX
	CPX.w #$0006
	BCC .slot
	SEC
	RTS

; -> $07 = character (0-5), $09 = 0 no capstone line, 1 "if highest", 2 "on
; track"; $05 = signature of the whole panel.
LvCompose:
	STZ $07
	STZ $09
	LDX $03
	BEQ .sig
	LDA.w $00B3,X            ; character
	AND.w #$0007
	CMP.w #$0006
	BCS .sig
	STA $07
	LDA.w $00B4,X            ; final class (0 base, 1 second, 2 final)
	AND.w #$00FF
	CMP.w #$0002
	BNE .sig
	LDA.w $00B1,X            ; level (0-based): this level-up reaches 60 at most
	AND.w #$00FF
	CMP.w #59
	BCS .sig
	LDA.w $00C8,X            ; no capstone yet
	AND.w #$00FF
	BNE .sig
	INC $09                  ; capstone line: "if highest"
	TXA
	CLC
	ADC.w #$0096
	STA $11
	SEP #$20                 ; v = the stat with the +1 taken, as the window shows it
	LDA.l !PanelVal          ; (the record holds the +1 itself while the window redraws)
	STA $0F
	LDY.w #$0000
-	CPY $01
	BEQ ++
	LDA ($11),Y
	CPY $01
	BCS +
	CMP $0F                  ; above it: must be lower
	BCS .notTop
	BRA ++
+	CMP $0F                  ; below it: lower or equal
	BEQ ++
	BCS .notTop
++	INY
	CPY.w #$0006
	BCC -
	REP #$20
	INC $09                  ; "on track"
	BRA .sig
.notTop
	REP #$20
.sig
	LDA $07                  ; stat | char << 3 | line << 6 | red palette << 8
	ASL
	ASL
	ASL
	ORA $01
	STA $05
	LDA $09
	XBA
	LSR
	LSR
	ORA $05
	STA $05
	LDA.l !RedPal
	AND.w #$1000
	LSR
	LSR
	LSR
	LSR
	ORA $05
	STA $05
	RTS


; Draw the panel into the BG3 copy (rows 1-4 -> BG3 rows 28-31, row 5 in place,
; cell columns 1-30, columns 0 and 31 blank) and mark those rows for upload.
LvDraw:
	LDA $01                  ; [$15] = LvStatText + stat*60
	ASL
	ASL
	STA $0F
	ASL
	ASL
	ASL
	ASL
	SEC
	SBC $0F
	CLC
	ADC.w #LvStatText
	STA $15
	LDA.w #LvStatText>>16
	STA $17
	LDY.w #$0000
	LDX.w #28*64             ; row 1: the name in red, the rest white
	JSR LvBlank1
	PHX
	LDX $01
	LDA.l LvNameLen,X
	PLX
	AND.w #$00FF
	STA $0D
	STA $19
	LDA.l !RedPal
	ORA.w #$2000
	STA $13
	JSR LvPut
	LDA.w #30
	SEC
	SBC $0D
	STA $19
	LDA.w #$3000             ; palette 4 (white), above sprites
	STA $13
	JSR LvPut
	JSR LvBlank1
	JSR LvBlank1             ; row 2 (BG3 row 29)
	LDA.w #30
	STA $19
	JSR LvPut
	JSR LvBlank1
	JSR LvSpellRow           ; row 3 (BG3 row 30): the spells that use the stat
	LDA $09                  ; rows 4-5: capstone line?
	BNE .capstone
	LDX.w #31*64
	JSR LvBlankRow
	LDX.w #5*64
	JSR LvBlankRow
	JMP .marked
.capstone
	DEC                      ; [$15] = LvLabels + (line-1)*16
	ASL
	ASL
	ASL
	ASL
	CLC
	ADC.w #LvLabels
	STA $15
	LDA.w #LvLabels>>16
	STA $17
	LDY.w #$0000
	LDX.w #31*64             ; row 4: label, then the text
	JSR LvBlank1
	LDA.w #16
	STA $19
	LDA.w #$2400             ; label in palette 1 (green)
	STA $13
	JSR LvPut
	LDA $07                  ; [$15] = LvCapText + (char*6 + stat)*44
	ASL
	STA $0F
	ASL
	CLC
	ADC $0F
	CLC
	ADC $01
	ASL
	ASL
	STA $0F                  ; n*4
	ASL
	STA $11                  ; n*8
	ASL
	ASL                      ; n*32
	CLC
	ADC $11
	CLC
	ADC $0F
	CLC
	ADC.w #LvCapText
	STA $15
	LDY.w #$0000
	LDA.w #$3000
	STA $13
	LDA.w #14                ; rest of row 4
	STA $19
	JSR LvPut
	JSR LvBlank1
	LDX.w #5*64              ; row 5 (in place)
	JSR LvBlank1
	LDA.w #30
	STA $19
	JSR LvPut
	JSR LvBlank1
.marked
	LDA.l !Dirty             ; rows 28-31 and row 5 go up this frame
	ORA.w #$000F
	STA.l !Dirty
	LDA.w #$0001
	STA.l !P5Dirty
	RTS

; $01 stat, $03 record, !PanelVal (the stat +1, as shown) -> the spell line of
; panel row 3: $1F mode (0 none drawn, 1 list full, 2 no spell of the class uses
; the stat, 3 all reached, 4 this +1 learns $21, 5 next is $21 at $25 with $27
; more after, 6 the ones left wait for a Mana Spirit), $21 spell, $2B its target
; type (1 one, 2 all, 3 one or all, 4 self), $25 threshold, $27 more.
; From the game's own level-up table, read as D0:DFEA / E007 / E02B do:
; $D1:BCC0 + LvListOfs[tier, character, path], 6 / 11 / 12 entries of type (0 =
; none), stat << 5 | value (stat 1 STR .. 6 LUK, 0 = no stat needed), the spell
; it replaces, spell. One counts if the game would act on it (D0:E06B): it
; teaches something (the spell is new, known with a lower type, or replaces a
; known one: $40:1420 / $40:1440) and its spirit has joined ($50:1400[spell] &
; record +$16F, $C0 counting as $20; 0 = none needed). With 10 spells known
; (record +$14E) the game learns nothing ($40:6BE0).
LvSpells:
	STZ $1F
	STZ $21
	STZ $27
	STZ $2B
	STZ $0D                  ; ones above waiting for a spirit
	LDA.w #$00FF             ; lowest threshold above (none yet)
	STA $25
	LDX $03
	BNE +
-	RTS
+	LDA.w $00B3,X            ; character
	AND.w #$00FF
	CMP.w #$0006
	BCS -
	STA $11
	LDA.w $00B4,X            ; tier
	AND.w #$00FF
	BEQ .base
	CMP.w #$0003
	BCS -
	CMP.w #$0002
	BEQ .final
	LDA.w $00B5,X            ; second: 6 + character*2 + path, 11 entries
	AND.w #$0001
	CLC
	ADC $11
	ADC $11
	ADC.w #6
	LDY.w #11
	BRA .list
.final
	LDA $11                  ; final: 18 + character*4 + path, 12 entries
	ASL
	ASL
	STA $11
	LDA.w $00B5,X
	AND.w #$0003
	CLC
	ADC $11
	ADC.w #18
	LDY.w #12
	BRA .list
.base
	LDA $11                  ; base: character, 6 entries
	LDY.w #6
.list
	STY $0B
	ASL
	TAX
	LDA.l LvListOfs,X
	CLC
	ADC.w #$BCC0
	STA $15
	LDA.w #$00D1
	STA $17
	LDA.l !PanelVal          ; v = the stat now: the window's value less its +1 (the
	DEC                      ; record holds the +1 itself while the window redraws)
	STA $0F
	LDA $01                  ; the stat's code in the table
	INC
	STA $19
	LDA.w #$0002             ; "no spell uses it" until one does
	STA $1F
	LDY.w #$0000
.scan
	LDA [$15],Y              ; type (0: no entry)
	AND.w #$00FF
	BEQ .skip
	INY
	LDA [$15],Y              ; stat << 5 | threshold
	DEY
	AND.w #$00FF
	STA $13
	LSR
	LSR
	LSR
	LSR
	LSR
	CMP $19
	BNE .skip
	LDA.w #$0003             ; one uses it: "all reached" unless one is above
	STA $1F
	LDA $13
	AND.w #$001F
	STA $13                  ; threshold
	CMP $0F
	BEQ .skip
	BCC .skip
	JSR .gains
	BCC .skip
	JSR .spirit
	BCS +
	INC $0D
	BRA .skip
+	LDA $13                  ; one to come: the lowest threshold is next
	CMP $25
	BCS .later
	LDA $25
	CMP.w #$00FF
	BEQ +
	INC $27                  ; (the one it takes over from comes after it)
+	LDA $13
	STA $25
	LDA [$15],Y
	AND.w #$00FF
	STA $2B
	INY
	INY
	INY
	LDA [$15],Y
	DEY
	DEY
	DEY
	AND.w #$00FF
	STA $21
	BRA .skip
.later
	INC $27
.skip
	INY
	INY
	INY
	INY
	DEC $0B
	BNE .scan
	LDA $25
	CMP.w #$00FF
	BEQ .none
	LDA $0F                  ; the next: with this +1, or later
	INC
	CMP $25
	BEQ +
	LDA.w #$0005
	BRA ++
+	LDA.w #$0004
++	STA $1F
	BRA .full
.none
	LDA $0D                  ; none to get, some once a spirit joins
	BEQ .done
	LDA.w #$0006
	STA $1F
.full
	LDX $03                  ; 10 spells known: nothing more
	LDA.w $014E,X
	BEQ .done
	LDA.w #$0001
	STA $1F
.done
	RTS

.gains                       ; Y = entry -> carry set if it teaches something
	LDA $03
	CLC
	ADC.w #12
	STA $11                  ; (end of the 12 spell slots)
	LDX $03
-	LDA.w $0145,X            ; known spell
	AND.w #$00FF
	BEQ .new                 ; free slot: a new spell
	PHA
	INY
	INY
	INY
	LDA [$15],Y              ; the entry's spell
	DEY
	DEY
	DEY
	AND.w #$00FF
	CMP $01,S
	BEQ .same
	INY
	INY
	LDA [$15],Y              ; the spell it replaces
	DEY
	DEY
	AND.w #$00FF
	CMP $01,S
	BEQ .repl
	PLA
	INX
	CPX $11
	BCC -
	CLC
	RTS
.repl
	PLA
.new
	SEC
	RTS
.same                        ; known: only a better type is something new
	PLA
	LDA [$15],Y
	SEP #$20
	CMP.w $0151,X
	REP #$20
	BEQ +
	RTS                      ; (carry: higher set, lower clear)
+	CLC
	RTS

.spirit                      ; Y = entry -> carry set if its spirit is with the party
	INY
	INY
	INY
	LDA [$15],Y
	DEY
	DEY
	DEY
	AND.w #$00FF
	TAX
	LDA.l $501400,X
	AND.w #$00FF
	BEQ +
	CMP.w #$00C0
	BNE ++
	LDA.w #$0020
++	LDX $03
	AND.w $016F,X
	AND.w #$00FF
	BEQ ++
+	SEC
	RTS
++	CLC
	RTS

; Panel row 3 (BG3 row 30) from $1F/$21/$25/$27 (LvSpells).
LvSpellRow:
	LDX.w #30*64
	JSR LvBlank1
	LDA.w #30
	STA $0B                  ; cells left
	LDA.w #LvFixed>>16       ; (all the texts are in this bank)
	STA $17
	LDA $1F
	BNE +
	JMP .pad
+	CMP.w #$0004
	BEQ .compose
	CMP.w #$0005
	BEQ .compose
	PHX                      ; fixed line L: 0 full, 1 + stat none, 7 + stat all,
	TAX                      ; 13 + stat spirit
	LDA.l LvFixedBase-1,X
	PLX
	AND.w #$00FF
	BEQ .fixedL
	CLC
	ADC $01
.fixedL
	STA $0D
	ASL                      ; [$15] = LvFixed + L*30
	ASL
	ASL
	ASL
	ASL
	SEC
	SBC $0D
	SEC
	SBC $0D
	CLC
	ADC.w #LvFixed
	STA $15
	PHX
	LDX $0D
	LDA.l LvFixedLab,X
	PLX
	AND.w #$00FF
	STA $19
	STA $0D
	LDY.w #$0000
	LDA.w #$2400             ; label green
	STA $13
	JSR LvPut
	LDA.w #30
	SEC
	SBC $0D
	STA $19
	LDA.w #$3000
	STA $13
	JSR LvPut
	JMP .end
.compose
	LDA.w #$2400
	STA $13
	LDA $1F
	CMP.w #$0004
	BNE .next
	LDA.w #LvTxtLearns       ; "Learns <spell> now!"
	JSR LvEmitL
	LDA.w #$3000
	STA $13
	JSR .name
	LDA.w #LvTxtNow
	JSR LvEmitL
	BRA .pad
.next                        ; "Next: <spell> at <n> (+k)"
	LDA.w #LvTxtNext
	JSR LvEmitL
	LDA.w #$3000
	STA $13
	JSR .name
	LDA.w #LvTxtAt
	JSR LvEmitL
	LDA $25
	JSR LvEmitNum
	LDA $27
	BEQ .pad
	LDA $0B
	CMP.w #$0005
	BCC .pad
	LDA.w #LvTxtMore
	JSR LvEmitL
	LDA $27
	JSR LvEmitNum
	LDA.w #LvTxtClose
	JSR LvEmitL
.pad
	LDA $0B
	BEQ .end
	LDA.w #$00FF
	JSR LvEmit
	BRA .pad
.end
	JSR LvBlank1             ; column 31
	RTS
.name                        ; the spell's name (LvSpellPtr[$21]) and its target mark
	LDA $21
	ASL
	PHX
	TAX
	LDA.l LvSpellPtr,X
	PLX
	CLC
	ADC.w #LvSpellNames
	JSR LvEmitL
	LDA $2B                  ; 2 all (#), 3 one or all (*), 4 self (^)
	SEC
	SBC.w #$0002
	CMP.w #$0003
	BCS +
	PHX
	TAX
	LDA.l LvMarks,X
	PLX
	AND.w #$00FF
	ORA.w #$3000
	JSR LvEmit
+	RTS

LvFixedBase:                 ; first fixed line of modes 1, 2, 3, (4, 5,) 6
	db 0, 1, 7, 0, 0, 13

; A = cell: write it at X if a cell is left ($0B), X advances.
LvEmit:
	PHA
	LDA $0B
	BEQ +
	DEC $0B
	PLA
	STA.l !Shadow,X
	INX
	INX
	RTS
+	PLA
	RTS

; A = address (this bank) of a length byte + tiles: write them with attributes $13.
LvEmitL:
	STA $15
	LDA [$15]
	AND.w #$00FF
	STA $0D
	BEQ .done
	LDY.w #$0001
.cell
	LDA [$15],Y
	AND.w #$00FF
	CMP.w #$00FF
	BEQ +
	ORA $13
	BRA ++
+	LDA.w #$00FF
++	JSR LvEmit
	INY
	DEC $0D
	BNE .cell
.done
	RTS

; A = 0-99: write it in white digits (no leading zero).
LvEmitNum:
	LDY.w #$0000
-	CMP.w #10
	BCC +
	SEC
	SBC.w #10
	INY
	BRA -
+	PHA
	TYA
	BEQ +
	ORA.w #$3080
	JSR LvEmit
+	PLA
	ORA.w #$3080
	JMP LvEmit

; -> carry set if a shop's buy or sell ring is up (on BG3: the buy ring's
; "Owned" box, frame rows 8-13 / columns 1-8 with "Ow" on row 10; or the sell
; ring's category box, frame rows 8-15 / columns 1-10 with the arrows up, right,
; down at column 2 of rows 10, 12, 14) and the last item name printed has a
; description ($11 = its address in bank $53; when the panel opens it must be
; fresh: the ring prints the name before it draws the box). Carry clear: A = 1
; if a box is up without one, A = 0 if no box.
LvFindShop:
	LDA.w #!Shadow&$FFFF
	STA $1B
	LDA.w #!Shadow>>16
	STA $1D
	LDX.w #$0000             ; buy ring
	JSR LvCellsMatch
	BCS +
	LDX.w #4*6               ; sell ring
	JSR LvCellsMatch
	BCC .noBox
+	LDA.l !ShopDesc
	BEQ .none
	STA $11
	LDA.l !PanelOn
	BNE .yes
	LDA.l !Ticks
	SEC
	SBC.l !ShopStamp
	CMP.w #120
	BCS .none
.yes
	SEC
	RTS
.none
	LDA.w #$0001
	CLC
	RTS
.noBox
	LDA.w #$0000
	CLC
	RTS

; X = offset of 6 cells in LvShopCells -> carry set if they all match.
LvCellsMatch:
	LDA.w #6
	STA $19
-	LDA.l LvShopCells,X
	TAY
	LDA [$1B],Y
	AND.w #$03FF
	CMP.l LvShopCells+2,X
	BNE +
	INX
	INX
	INX
	INX
	DEC $19
	BNE -
	SEC
	RTS
+	CLC
	RTS

LvShopCells:                 ; BG3-copy offset, tile
	dw (8*32+1)*2, $0040     ; buy ring: "Owned" box corners
	dw (8*32+8)*2, $0042
	dw (13*32+1)*2, $0045
	dw (13*32+8)*2, $0047
	dw (10*32+2)*2, $0058    ; O(wned)
	dw (10*32+3)*2, $007A    ; w
	dw (8*32+1)*2, $0040     ; sell ring: category box corners
	dw (8*32+10)*2, $0042
	dw (15*32+1)*2, $0045
	dw (15*32+10)*2, $0047
	dw (10*32+2)*2, $002E    ; arrows by the categories
	dw (14*32+2)*2, $002F

; $11 = description in bank $53 (ASCII, as for the equip screen's help box:
; control codes >= $80, line 1, $12, line 2, $FF) -> panel rows 2-3 (BG3 rows
; 29-30, all 32 columns), rows 1 and 4 blank.
LvShopDraw:
	LDA $11
	STA $15
	LDA.w #$0053
	STA $17
	LDY.w #$0000
	LDX.w #28*64
	JSR LvBlankRow
	JSR LvAsciiRow           ; row 29: line 1
	JSR LvAsciiRow           ; row 30: line 2
	LDX.w #31*64
	JSR LvBlankRow
	LDA.l !Dirty
	ORA.w #$000F
	STA.l !Dirty
	RTS

; One 32-cell row at X from the ASCII text [$15],Y: up to $12 / $FF (Y then
; points past a $12), control codes skipped, the rest of the row blank.
LvAsciiRow:
	LDA.w #32
	STA $19
.next
	LDA [$15],Y
	AND.w #$00FF
	CMP.w #$00FF
	BEQ .pad
	INY
	CMP.w #$0012
	BEQ .pad
	CMP.w #$0080
	BCS .next                ; colour / layout code
	SEC
	SBC.w #$0020
	BCC .next
	PHX
	TAX
	LDA.l LvAscii,X
	PLX
	AND.w #$00FF
	CMP.w #$00FF
	BEQ +
	ORA.w #$3000             ; palette 4 (white), above sprites
	BRA ++
+	LDA.w #$00FF
++	STA.l !Shadow,X
	INX
	INX
	DEC $19
	BNE .next
	LDA [$15],Y              ; a full row: step over the $12 that ends it
	AND.w #$00FF
	CMP.w #$0012
	BNE +
	INY
+	RTS
.pad
	JSR LvBlank1
	DEC $19
	BNE .pad
	RTS

; $19 cells from [$15],Y (tile numbers, $FF = blank) with attributes $13 to the
; BG3 copy at X; X and Y advance.
LvPut:
-	LDA [$15],Y
	AND.w #$00FF
	CMP.w #$00FF
	BEQ +
	ORA $13
	BRA ++
+	LDA.w #$00FF
++	STA.l !Shadow,X
	INX
	INX
	INY
	DEC $19
	BNE -
	RTS

LvBlank1:                    ; one blank cell at X
	LDA.w #$00FF
	STA.l !Shadow,X
	INX
	INX
	RTS

LvBlankRow:                  ; a blank row at X
	LDA.w #32
	STA $19
-	JSR LvBlank1
	DEC $19
	BNE -
	RTS

; Hide the HUD portraits (OAM entries 0-2, shadow OAM $7F:0100; set once by the
; HUD, which puts the top ones in any of the three) while they sit on the panel's
; lines; remember their Y.
LvHideSprites:
	SEP #$20
	LDA.l $7F0101            ; entry 0 Y
	CMP.b #8
	BCC +
	CMP.b #48
	BCS +
	STA.l !SprSave0
	LDA.b #$F0
	STA.l $7F0101
	LDA.l !SprHid
	ORA.b #$04
	STA.l !SprHid
+	LDA.l $7F0105            ; entry 1 Y
	CMP.b #8
	BCC +
	CMP.b #48
	BCS +
	STA.l !SprSave
	LDA.b #$F0
	STA.l $7F0105
	LDA.l !SprHid
	ORA.b #$01
	STA.l !SprHid
+	LDA.l $7F0109            ; entry 2 Y
	CMP.b #8
	BCC +
	CMP.b #48
	BCS +
	STA.l !SprSave+1
	LDA.b #$F0
	STA.l $7F0109
	LDA.l !SprHid
	ORA.b #$02
	STA.l !SprHid
+	REP #$20
	RTS

; Put them back (if still where we left them).
LvShowSprites:
	SEP #$20
	LDA.l !SprHid
	AND.b #$04
	BEQ +
	LDA.l $7F0101
	CMP.b #$F0
	BNE +
	LDA.l !SprSave0
	STA.l $7F0101
+	LDA.l !SprHid
	AND.b #$01
	BEQ +
	LDA.l $7F0105
	CMP.b #$F0
	BNE +
	LDA.l !SprSave
	STA.l $7F0105
+	LDA.l !SprHid
	AND.b #$02
	BEQ +
	LDA.l $7F0109
	CMP.b #$F0
	BNE +
	LDA.l !SprSave+1
	STA.l $7F0109
+	LDA.b #$00
	STA.l !SprHid
	REP #$20
	RTS

; The window closed: portraits back, row 5 blank again, bars set rows 28-31 up
; again when they next show (!Active = 0 also turns our HDMA off).
LvPanelOff:
	LDA.l !PanelOn
	BEQ +
	LDA.w #$0000
	STA.l !PanelOn
	STA.l !Active
	LDA.w #$FFFF
	STA.l !PanelSig
	JSR LvShowSprites
	LDX.w #5*64
	JSR LvBlankRow
	LDA.w #$0001
	STA.l !P5Dirty
	LDA.w #$0000             ; (a shop's next ring prints its first name again)
	STA.l !ShopDesc
+	RTS

; HDMA table for channel 1 (BG3 scroll) into the buffer the NMI isn't using:
; lines 0-7 normal, lines 8-39 show BG3 rows 28-31 (screen line L shows BG3
; line L + VOFS + 1), normal down to line 222, then the last line on blank row
; 27 (EmitLastLine).
LvTable:
	LDA.l !Ready
	CMP.w #!TableA&$FFFF
	BEQ +
	LDX.w #!TableA&$FFFF
	BRA ++
+	LDX.w #!TableB&$FFFF
++	LDA.w #$0000
	STA.l $7E0001,X
	STA.l $7E0003,X
	STA.l $7E0006,X
	STA.l $7E000B,X
	STA.l $7E000D,X
	STA.l $7E0010,X
	STA.l $7E0012,X
	LDA.w #224-8-1
	STA.l $7E0008,X
	SEP #$20
	LDA.b #8
	STA.l $7E0000,X
	LDA.b #32
	STA.l $7E0005,X
	LDA.b #127
	STA.l $7E000A,X
	LDA.b #223-8-32-127
	STA.l $7E000F,X
	REP #$20
	PHX
	TXA
	CLC
	ADC.w #20
	TAX
	JSR LvLastLine
	PLX
	TXA
	STA.l !Ready
	LDA.l !Ticks
	STA.l !Stamp
	LDA.w #$0001
	STA.l !Active
	RTS

LvLastLine:                  ; = EmitLastLine (that one is in bank $CB)
	SEP #$20
	LDA.b #$01
	STA.l $7E0000,X
	LDA.b #$00
	STA.l $7E0005,X
	REP #$20
	LDA.w #$0000
	STA.l $7E0001,X
	LDA.w #$03FF
	STA.l $7E0003,X
	RTS

incsrc "../build/levelinfo.asm"
