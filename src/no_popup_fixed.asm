; Fixed version of misc_patches/no_popup_messages.ips
;
; The original patch put an RTS at $D0:CE53 and $D0:D01A. $D0:D01A really is
; just a status-ailment message, but $D0:CE53 is the routine that APPLIES stat
; buffs/debuffs (Power Up, Protect Up, Life Booster, Magic Shield, ...):
;   JSR $CDFD    popups for each changed stat     <- display only
;   merge the new buff bits with the character's  <- needed
;   JSR $CEF9    recalc stats / special buff field <- needed
;   store the new buff bits                       <- needed
; With the RTS none of that happens, so those spells did nothing.
;
; This version returns from the popup loop instead, and blanks out the message
; calls of the special buff field, keeping all of its state changes.
; It also restores $D0:CE53, so it works even on a ROM that already has the
; old patch applied.

exhirom

; Status ailment messages (same as the original patch).
org $D0D01A
	RTS

; Undo the old patch: the buff routine runs normally again.
org $D0CE53
	STX $1A			; original first instruction (86 1A)

; Stat modifier popups: skip only the display loop (it saves and restores
; its inputs, nothing else depends on it).
org $D0CDFD
	RTS

; Special buff field (bits $C0 of +$37): drop the messages, keep the rest.
; Each message is: JSL $C4007C (queue message), [LDX/JSR $D598 (message
; timing)], INC $04 : INC $04 (advance message counter).
org $D0CEEA			; "wore off" check routine at $D0:CED9
	NOP #4			; JSL $C4007C
org $D0CEF1
	NOP #3			; JSR $D598
	NOP #4			; INC $04 x2
org $D0CF6B			; gained
	NOP #4			; JSL $C4007C   (JSL $D0C7E0 after it is kept)
org $D0CF73
	NOP #4			; INC $04 x2    (stat recalc after it is kept)
org $D0CF95			; gained (second message) / lost
	NOP #4			; JSL $C4007C
org $D0CF9C
	NOP #3			; JSR $D598
	NOP #4			; INC $04 x2
