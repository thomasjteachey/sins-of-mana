; Sin of Mana add-on: hits and spells land on time, even in crowded fights.
;
; In battle the game runs out of CPU time every frame. Its tasks share it by
; priority (lower number first): the sprite engine is $30, the character you
; control $60-$74, the sprite object task $64 (it wakes the sprite engine), the
; HUD $70, the damage numbers $90, AI allies $AC and enemies $C0. A fighter's
; task does everything that fighter does: when a hit connects, the hit
; detection sends it a message (type $40) and only its own task can flinch,
; apply the damage and report the number; when a cast runs out, a timer message
; (type $02) wakes it and it takes a few more turns to let the spell go. In a
; crowded fight each of those turns can wait many frames (2 seconds and more),
; so hits and spells show up late.
;
; The game already has a way to hurry a task: when 16 messages are waiting for
; it, $C0:5E05 raises it to priority 4 and keeps its own priority in task +$13;
; reading a message puts it back ($C0:5DDD, also when the messages of a task
; that is being removed are thrown away). This patch uses the same mechanism:
;  * a hit message (type $40): the target goes to !HitBoost (right after the
;    sprite engine) for the turn in which it reads it, then waits at !HitHold
;    (after the sprite object task, before the HUD and every other fighter)
;    until it applies the hit (the battle script's "process hit" op,
;    $D0:C151), or for !HitTicks after its last hit message if it never does;
;  * any message to a fighter in the middle of a cast: !CastBoost for that
;    turn, !CastHold until the spell goes off;
;  * a fighter reporting a damage number (type $80, first byte 1: the number
;    task): !NumBoost until the number task has read all its messages, or for
;    !NumTicks.
; A task that is holding goes back up for every new message of its kind. In
; each case it gets its own priority back at the first message it reads once
; the hurry is no longer needed, at once when it is removed, or through the
; Sweep below if it reads none.
; See NOTES.md ("Quick hits").

exhirom

!NumBoost ?= $4E
!HitBoost ?= $4F
!CastBoost ?= $50
!HitHold ?= $65              ; the sprite object task is $64
!CastHold ?= $66
!HitTicks ?= 60              ; clock ticks (frames)
!NumTicks ?= 20

SetPrio = $C00490            ; JSR $5151: A = id << 8 | priority -> A = old priority (8-bit)
DeqSkip = $C05DFF            ; $C0:5DDD: store the new count, no change of priority
Clock = $7F00C6              ; battle clock, +1 per frame (stops while the field is paused)
CurTask = $7F0064            ; the running task
!Start = $0014               ; task +$14: clock (low byte) when its hurry started or was renewed (unused by the game)
SweepNext = $7E2BFF          ; the task record Sweep looks at next (free RAM; cleared at power-on)

; ---- $C0:5EAC sends a message: queue it, wake the task, then count it ----
org $C05EED                  ; was LDX $03 : JSR $5E05 (count it; 16 waiting -> priority 4)
	JSL CountMsg
	NOP
assert pc() == $C05EF2       ; LDA #$FFFF : BRA: X and Y are free after this

; ---- $C0:5DDD: a task reads a message (or a removed task's message is thrown away) ----
org $C05DEB                  ; was LDA $0003,Y : CMP #$04 : BCC (put the priority back from 4 up)
	JSL KeepCheck
	BCC DeqSkip              ; carry clear: not now
	NOP
assert pc() == $C05DF2       ; LDA $0013,Y : BEQ : STA $0003,Y ... (A is loaded again)

; ---- battle script op "process hit" ($D0:C009 -> $C151): the target applies the hit ----
org $D0C154                  ; was LDA #$0001 : STA $2C
	JSL HitDone
	NOP
assert pc() == $D0C159

org $FAF800                  ; free in the base game ($FF to the end of the bank)
;-- In: D = the send routine's frame ($01 = message, $03 = target task record),
; DB = $7F, A/X/Y 16-bit, interrupts off. Out: X = task (as $5E05 leaves it).
CountMsg:
	PHP
	SEP #$20
	JSR Sweep
	LDX $03
	LDA $0017,X              ; messages waiting
	INC A
	STA $0017,X
	CMP #$10
	BCC .mine
	LDA $0013,X              ; 16 waiting: the game's own boost (as $C0:5E05)
	BNE .done
	LDA $0003,X
	CMP #$04
	BCC .done
	LDA #$04
	JSR SetIt
	STA $0013,X
	BRA .done
.mine:
	LDY $01
	LDA $0003,Y              ; message type
	CMP #$40                 ; hit ($C1:3020, $D7:FCB5)
	BNE .report
	LDA Clock
	STA !Start,X             ; (a later hit keeps an existing hurry up longer)
	LDA #!HitBoost
	BRA Hurry
.report:
	CMP #$80
	BNE .cast
	LDA $0004,Y
	CMP #$01                 ; damage number
	BNE .done
	LDX $0064                ; from a fighter? (it is the running task)
	JSR Fighter
	LDX $03
	BCC .done
	LDA Clock
	STA !Start,X
	LDA #!NumBoost
	BRA Hurry
.cast:
	JSR Casting
	BCC .done
	LDA #!CastBoost
	BRA Hurry
.done:
	LDX $03
	PLP
	RTL

;-- (CountMsg, carried on) A = the priority the task in X should have now.
Hurry:
	PHA
	LDA $0013,X
	BEQ .fresh
	LDA $0003,X              ; already hurried: one that is holding goes back up
	CMP #!HitHold
	BEQ .up
	CMP #!CastHold
	BNE .leave
.up:
	LDA $0013,X              ; its own priority, aside while SetPrio sets ours
	PHA
	LDA #$00
	STA $0013,X
	LDA $02,S
	JSR SetIt
	PLA
	STA $0013,X
.leave:
	PLA
	BRA CountMsg_done
.fresh:
	PLA
	CMP $0003,X
	BCS CountMsg_done        ; already at least this urgent
	JSR SetIt
	STA $0013,X              ; its own priority, put back by $C0:5DDD
	BRA CountMsg_done

;-- A = priority for the task in X (= [$03], the send routine's target), +$13 = 0.
; Out: A = its old priority, X = task.
SetIt:
	XBA
	LDA $0004,X              ; task id
	XBA                      ; A = id << 8 | priority
	JSL SetPrio              ; sets +$03 and re-sorts the ready list
	LDX $03
	RTS

;-- In: Y = task, A 8-bit, X/Y 16-bit, DB = $7F, the task is the one running (or being
; removed). Out: carry set = put its priority back now.
; As the game: only if one is saved and it is 4 or more; one of ours once it is no longer
; needed. A hit or cast hurry still needed steps down to its hold level here.
KeepCheck:
	LDA $0013,Y
	BEQ .keep
	LDA $0003,Y
	CMP #$04
	BCC .keep
	CMP #!NumBoost
	BNE .other
	LDA $04,S                ; number task: messages still waiting ($C0:5DDD pushed the new count)
	BEQ .back
.other:
	PHX
	PHY
	TYX
	JSR Needed
	PLY
	PLX
	BCC .back
	LDA $0003,Y              ; still needed. Running, so in no queue: +$03 is enough
	CMP #!HitBoost
	BNE +
	LDA #!HitHold
	STA $0003,Y
	BRA .keep
+	CMP #!CastBoost
	BNE .keep
	LDA #!CastHold
	STA $0003,Y
.keep:
	CLC
	RTL
.back:
	SEC
	RTL

;-- In: X = task whose priority is saved in +$13, A 8-bit, X/Y 16-bit, DB = $7F.
; Out: carry set = keep its present priority. Changes Y.
Needed:
	LDA $0002,X
	CMP #$10                 ; being removed
	BEQ .no
	LDA $0003,X
	CMP #!NumBoost
	BEQ .num
	CMP #!HitBoost
	BEQ .hit
	CMP #!HitHold
	BEQ .hit
	CMP #!CastBoost
	BEQ .cast
	CMP #!CastHold
	BNE .no                  ; anything else (the game's own priority 4): as the game
.cast:
	JMP Casting
.num:
	LDA $0017,X              ; messages waiting
	BEQ .no
	LDA Clock
	SEC
	SBC !Start,X
	CMP #!NumTicks
	BRA .young
.hit:
	LDA Clock
	SEC
	SBC !Start,X
	CMP #!HitTicks
.young:
	BCS .no                  ; (carry clear while younger)
	SEC
	RTS
.no:
	CLC
	RTS

;-- Safety net, run for every message sent: the next of the 28 task records (from $7F:0062)
; gets a hurry of ours put back once it is no longer needed, also when that task reads no
; message for a long time.
; DB = $7F, A 8-bit, X/Y 16-bit, interrupts off. Changes A, X, Y.
Sweep:
	LDA SweepNext
	INC A
	CMP #28
	BCC +
	LDA #$00
+	STA SweepNext
	REP #$20
	AND #$001F
	ASL #5
	CLC
	ADC $0062                ; the task records (set up at power-on)
	TAX
	SEP #$20
	LDA $0013,X
	BEQ .out
	LDA $0002,X
	BEQ .out                 ; free record
	LDA $0003,X
	CMP #!HitHold
	BEQ .ours
	CMP #!CastHold
	BEQ .ours
	CMP #!NumBoost
	BCC .out
	CMP #!CastBoost+1
	BCS .out                 ; not one of ours
.ours:
	JSR Needed
	BCS .out
	LDA $0013,X              ; put it back (re-sorted if it is waiting for its turn)
	XBA
	LDA #$00
	STA $0013,X
	LDA $0004,X
	XBA                      ; A = id << 8 | its own priority
	JSL SetPrio
.out:
	RTS

;-- In: X = task, A 8-bit, X/Y 16-bit, DB = $7F. Out: carry set if it is a fighter's task,
; with Y = the fighter's record (bank $7F). Keeps X.
; A fighter's task runs the battle script with its direct page on the page of its stack,
; where $34 points to the fighter's record + $90; the record's +$02 is its task id.
Fighter:
	PHX
	REP #$20
	LDA $0008,X              ; saved stack pointer
	AND #$1F00
	TAX
	LDA $7E0034,X
	SEC
	SBC #$0090
	TAY
	SEP #$20
	PLX
	LDA $0002,Y
	CMP $0004,X
	BNE .no
	SEC
	RTS
.no:
	CLC
	RTS

;-- As Fighter, and that fighter is casting (state $0A). Changes Y.
Casting:
	JSR Fighter
	BCC .no
	LDA $0000,Y
	CMP #$0A
	BEQ .yes                 ; (carry set)
	CLC
.no:
	RTS
.yes:
	RTS

;-- At the start of the "process hit" op, in the target's own task: D = its script page,
; A 16-bit. The hit is being applied: a hit hurry ends here (the task is running, so it
; is in no queue: setting +$03 is enough).
HitDone:
	PHP
	SEI
	REP #$30
	PHX
	LDA CurTask
	TAX
	SEP #$20
	LDA $7F0003,X
	CMP #!HitBoost
	BEQ .end
	CMP #!HitHold
	BNE .out
.end:
	LDA $7F0013,X
	BEQ .out
	STA $7F0003,X
	LDA #$00
	STA $7F0013,X
.out:
	REP #$30
	PLX
	PLP
	LDA.w #$0001             ; what the hook replaced
	STA $2C
	RTL

assert pc() <= $FB0000
