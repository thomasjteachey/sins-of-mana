; Sin of Mana add-on: equipment descriptions in the equip screen's help box.
; Applied on top of Sin of Mana 2.060 (ExHiROM). See NOTES.md for addresses.
;
; How it works:
;  * The equip screen's help box prints string $FB:1855. The mod's text hook at
;    $40:7960 already redirects $FB strings to its own name bank ($53). We replace
;    that hook with a copy that, for $FB:1855 only, looks up the highlighted item
;    and prints its description instead (if it has one).
;  * The game redraws the help box when the item-list cursor moves, but not when
;    the slot cursor moves. Three small hooks add that redraw.

exhirom

; Descriptions must live in bank $53: the mod's glyph reader ($40:7920) only
; reads plain ASCII from that bank and treats every other bank as compressed.
!DescBank = $53

; ---------------------------------------------------------------------------
; Hooks into existing code
; ---------------------------------------------------------------------------

; Mod's text redirect hook (entered by JSL from $C0:EAF4).
org $407960
	JML NewRedirect

; Item-icon palette copy ($E8:C18F, from the icon drawer at $C4:4DBC): it puts the
; icon's 7 colours at $7E:4922 + 16 * [D+$79], the icon's palette half (0-11, it
; wraps at 12 itself). With a bad value there it wrote icon colours anywhere: in the
; user's state 5 (2026-11-03) over the field's tile block 0 ($7E:8C02, the ceiling
; turned to garbage after leaving the equip screen) and two other places
; ($7E:FB32, $7F:2B22). IconSlot only lets 0-11 through. Was (11 bytes):
; LDA $79 : ASL #4 : CLC : ADC #$0120 : TAX
org $E8C19E
	assert read1($E8C19E) == $A5 && read1($E8C19F) == $79 && read1($E8C1A8) == $AA
	JSL IconSlot
	TAX
	db $EA, $EA, $EA, $EA, $EA, $EA

; Slot cursor moved up / down, and "B" back from the item list.
; Each site was:  LDA #$0001 : STA $46   (5 bytes)
org $C481AB
	JSL SlotHelpRedraw
	NOP
org $C481F5
	JSL SlotHelpRedraw
	NOP
org $C4828B
	JSL SlotHelpRedraw
	NOP

; ---------------------------------------------------------------------------
; New code (free space in the expanded ROM)
; ---------------------------------------------------------------------------
org $568000

; Replacement for the mod's redirect hook.
; In:  Y = string address, stack S+4..5 = string bank (pushed A), X = text record.
;      DB = $7F, 16-bit A/X/Y. Must end like the original: STA $0000,X then RTL.
NewRedirect:
	PHX
	LDA $06,S
	CMP.w #$00FB
	BNE .orig
	CPY.w #$1855		; equip screen help text?
	BNE .remap
	JSR GetHelpDesc		; A = description address in !DescBank, 0 = none
	BEQ .remap
	PHA
	LDA.w #!DescBank
	STA $08,S		; replace the string bank
	PLA
	PLX
	STA.w $0000,X
	RTL
.remap				; --- original hook from here on ---
	JSR ShopNote
	TYX
	LDA.l $520000,X
	AND.w #$00FF
	BNE .redirect
.orig
	TYA
	PLX
	STA.w $0000,X
	RTL
.redirect
	PHA
	LDA.w #$0053
	STA $08,S
	PLA
	ASL
	ASL
	ASL
	ASL
	PLX
	STA.w $0000,X
	RTL


; Remember the description of the last item name printed (Y = its $FB address):
; the shop's buy/sell ring has no help box, so the bars engine's shop panel
; (src/bars.asm, FeatShopInfo) shows it. Equipment names $FB:1C6C-$2D7F
; (name tables $C4:B31E/$C4:B51E) -> DescTable[their name slot] (0 if none);
; other item names $FB:2D80-$33FF (table $D3:9B36: $2D91-$2DA2 and
; $3006-$3394) -> none; any other string (prices, hints): no change. Keeps X/Y.
!ShopDesc  = $7E28F0		; (bars.asm: !Ram+$0F0)
!ShopStamp = $7E28F2		; mod's frame counter when it was noted
ShopNote:
	CPY.w #$1C6C
	BCC .done
	CPY.w #$2D80
	BCC .equip
	CPY.w #$3400
	BCS .done
	LDA.w #$0000
	BRA .store
.equip
	PHX
	TYX
	LDA.l $520000,X
	AND.w #$00FF
	ASL
	TAX
	LDA.l DescTable,X
	PLX
.store
	STA.l !ShopDesc
	LDA.l $7F00C6
	STA.l !ShopStamp
.done
	RTS


; Work out which item the equip-screen cursor is on and return its description.
; In:  D = the equip screen's direct page (the text engine runs with the caller's D;
;      it moves between sessions: $0500 in the prologue, $0A00 in later saves).
; Out: A = address of the description in !DescBank, or 0 (Z flag set) if none.
; Keeps Y. Uses only the stack for temporaries.
GetHelpDesc:
	PHY
	PHP
	REP #$30
	LDA $61			; current character
	AND.w #$00FF
	ASL
	TAX
	LDA.l $7E2040,X		; -> character record in bank $7F
	PHA			; [1,S] = record
	LDA.l $7F0129		; cursor sprite Y
	AND.w #$00FF
	CMP.w #$0060
	BCS .itemList

	; Slot list: rows at Y = 6, 22, 38, 54, 70  ->  slot 0-4
	SEC
	SBC.w #$0006
	LSR
	LSR
	LSR
	LSR
	CMP.w #$0005
	BCC .slotOk
	JMP .noneOne
.slotOk
	PHA			; [1,S] = slot (kind), [3,S] = record
	CLC
	ADC $03,S
	TAX
	LDA.l $7F00BC,X		; equipped item index for that slot
	AND.w #$00FF
	BRA .haveItem

.itemList
	; Item list: rows at Y = 104 + 16*row, columns at X = 80 / 160
	SEC
	SBC.w #$0068
	LSR
	LSR
	LSR
	AND.w #$FFFE		; row*2
	TAY
	LDA.l $7F0128		; cursor sprite X
	AND.w #$00FF
	CMP.w #$0078		; carry set for the right column
	TYA
	ADC.w #$0000
	TAY			; Y = cell
	LDA $40			; slot being changed
	AND.w #$00FF
	PHA			; [1,S] = slot (kind), [3,S] = record
	CPY.w #$0000
	BNE .fromList
	CLC			; cell 0 = the item currently equipped in that slot
	ADC $03,S
	TAX
	LDA.l $7F00BC,X
	AND.w #$00FF
	BRA .haveItem
.fromList			; same as $D1:E751: record + offset[slot] + (cell-1) + $90
	ASL
	TAX
	LDA.l $C48693,X
	CLC
	ADC $03,S
	DEY
	PHY
	CLC
	ADC $01,S
	PLY
	TAX
	LDA.l $7F0090,X
	AND.w #$00FF

.haveItem			; A = item index, [1,S] = slot, [3,S] = record
	ASL
	TAX
	LDA $01,S
	BNE .armorName
	LDA.l $C4B31E,X		; weapon name table
	BRA .gotName
.armorName
	LDA.l $C4B51E,X		; helm/armor/accessory/shield name table
.gotName
	TAX
	LDA.l $520000,X		; mod's name slot for this string
	AND.w #$00FF
	BEQ .noneTwo
	ASL
	TAX
	LDA.l DescTable,X
	BRA .doneTwo
.noneTwo
	LDA.w #$0000
.doneTwo
	PLX
	PLX
	PLP
	PLY
	CMP.w #$0000
	RTS
.noneOne
	PLX
	PLP
	PLY
	LDA.w #$0000
	RTS


; $E8:C19E: A = $0120 + 16 * the icon's palette half [D+$79], 0-11 (anything else
; counts as 0 and is stored back, so the rest of $E8:C18F agrees). 16-bit A, D =
; the icon drawer's direct page.
IconSlot:
	LDA $79
	CMP.w #$000C
	BCC +
	LDA.w #$0000
	STA $79
+	ASL
	ASL
	ASL
	ASL
	CLC
	ADC.w #$0120
	RTL


; Replaces "LDA #$0001 : STA $46" after the slot cursor moves, then redraws
; the help box so it shows the newly highlighted item.
; Context: 16-bit A/X/Y, D = $0500, DB = $7F.
SlotHelpRedraw:
	LDA.w #$0001
	STA.b $46
	PHP
	REP #$30
	PHA
	PHX
	PHY
	LDA.b $20
	PHA
	LDA.b $5F
	PHA
	LDA.w #$0005		; layout used by the help box
	STA.b $20
	LDA.w #$007F
	STA.b $5F
	; JSR $C4:9D8E from another bank: its RTS lands on the RTL at $C4:9CEE.
	PHK
	PER .back-1
	PEA.w $9CED
	JML $C49D8E
.back
	PLA
	STA.b $5F
	PLA
	STA.b $20
	PLY
	PLX
	PLA
	PLP
	RTL


; ---------------------------------------------------------------------------
; Description data (generated by tools/build.py from src/descriptions.txt)
; Bank $53 is the mod's plain-text bank; $53:0000-0FFF holds its names,
; the rest of the bank is unused.
; ---------------------------------------------------------------------------
org $538000
incsrc "../build/desc.asm"
