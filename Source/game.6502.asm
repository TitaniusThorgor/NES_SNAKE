;GAME
;implementation of gamestates

;GAME STATE PLAYING
_gameStatePlaying:


;Check if paused
	LDA playerOnePressed
	AND #%00010000
	BEQ _gameIsNotPaused
	;use sprites to display text at $10 in CHR, use the 6 first sprites
	LDX #$00
	LDY #$00
_pauseLoop:
	;Y-position
	LDA #$70
	STA $0200, X
	INX

	;Tile Number
	TYA
	CLC
	ADC #$10
	STA $0200, X
	INX

	;Attributes
	LDA #%00000010
	STA $0200, X
	INX

	;X-Position
	STY temp
	INC temp
	LDA #$00
_pause_X_Loop:
	CLC
	ADC #$08
	DEC temp
	BNE _pause_X_Loop

	CLC
	ADC #$65
	STA $0200, X
	INX
	
	INY
	CPY #$05
	BNE _pauseLoop

	;Set game state
	LDA #GAME_STATE_PAUSED
	STA gameState
_gameIsNotPaused:

	;snakeLastInput
	;convert input to two bytes
	LDA playerOneInput
	;let's make this easy for us

	CMP #%00001000
	BNE _snakePersistantInputUpDone
	LDX #$00
	STX snakeLastInputTemp
_snakePersistantInputUpDone:

	CMP #%00000100
	BNE _snakePersistantInputDownDone
	LDX #$01
	STX snakeLastInputTemp
_snakePersistantInputDownDone:

	CMP #%00000010
	BNE _snakePersistantInputLeftDone
	LDX #$02
	STX snakeLastInputTemp
_snakePersistantInputLeftDone:

	CMP #%00000001
	BNE _snakePersistantInputRightDone
	LDX #$03
	STX snakeLastInputTemp
_snakePersistantInputRightDone:
;;;;;;;;;;
	LDA snakeLastInputTemp
	EOR #$01
	CMP snakeLastTickInput
	BEQ _snakePersistantInputDone
	LDA snakeLastInputTemp
	STA snakeLastInput
_snakePersistantInputDone:

;;;;;;;;;;

	LDX snakeFrames
	INX
	STX snakeFrames
	CPX snakeFramesToMove
	BNE _tickDone
	JSR _tick
_tickDone:
;do things that need to be done every frame, such as updating sprites

;return from gamestate playing
	RTS


;keep this structure, as I could to add a state where the snake is not moving
;reads snakePos and updates namBuffer
;usage: load A with x of the position and X with y of the position, load Y with tile index
UpdateNamPos:
	;A has loaded snakePos_X
	;X has loaded snakePos_Y
	STA backgroundDir_lo
	LDA #$00
	STA backgroundDir_hi
	INX
_snakeUpdateHeadHighLoop:
	DEX
	BEQ _snakeUpdateHeadHighLoopDone
	LDA backgroundDir_lo
	CLC
	ADC #$20
	STA backgroundDir_lo
	LDA backgroundDir_hi
	ADC #$00
	STA backgroundDir_hi
	JMP _snakeUpdateHeadHighLoop
_snakeUpdateHeadHighLoopDone:
	;add to namBuffer, A (which contains the tileIndex in the function) will be loaded with the starting point in CHR, than added with the direction directly
	TYA
	;backgroundDir lo and hi are loaded with the correct addresses, minus $2000, A contains tile index
	JSR NamAdd

	RTS
;;;;;;;;;


;load X with x and Y with y, they will be updated depending on the dir in A (0 up, 1 down, 2 left, 3 right)
UpdatePos:
	;A is loaded with direction
	CMP #$00
	BNE _updatePosUpDone
	DEY
_updatePosUpDone:
	CMP #$01
	BNE _updatePosDownDone
	INY
_updatePosDownDone:
	CMP #$02
	BNE _updatePosLeftDone
	DEX
_updatePosLeftDone:
	CMP #$03
	BNE _updatePosDone
	INX
_updatePosDone:
	RTS
	

;Tick
_tick:

	;reset snakeFrames
	LDA #$00
	STA snakeFrames

	;tick input (the snake doesn't do a 180 degree turn)
	LDA snakeLastInput
	STA snakeLastTickInput

	;total amount of ticks
	LDA snakeTicks_0
	CLC
	ADC #$01
	STA snakeTicks_0
	LDA snakeTicks_1
	ADC #$00
	STA snakeTicks_1
	LDA snakeTicks_2
	ADC #$00
	STA snakeTicks_2
	LDA snakeTicks_3
	ADC #$00
	STA snakeTicks_3


	;display fruit
	LDY #FRUIT_CHR
	LDA fruitPos_X
	LDX fruitPos_Y
	JSR UpdateNamPos


	;display a body tile in the previous tick's head's position
	LDA snakeInputs
	AND #%00000011
	CMP snakeLastInput
	BEQ _snakeStraight

	;curvs
	ASL A
	ASL A
	CLC
	ADC snakeLastInput
	ADC #SNAKE_CHR_BODY_CURVES
	STA snakeInputsTemp
	
	;CURVE SOUNDS
	LDA snakeTicks_0
	AND #%00000001
	BEQ _snakeTickBeepHigh
	
	;LowBeep
	LDA #%10010011	;volume for the tone + duty of 50%
	STA $4000
	
	LDA #$FB
	STA $4002		;Height of the tone
	
	LDA #%10000001
	STA $4003		;Length of the tone + tone legth hi-byte

	LDA snakeInputsTemp

	LDA snakeInputsTemp
	JMP _snakeTickBeepDone

_snakeTickBeepHigh:
	;HighBeep
	LDA #%10010011	;volume for the tone + duty of 50%
	STA $4000
	
	LDA #$BA
	STA $4002		;Height of the tone
	
	LDA #%10000001
	STA $4003		;Length of the tone + tone legth hi-byte

_snakeTickBeepDone:

	LDA snakeInputsTemp
	JMP _snakeUpdateBody


_snakeStraight:
	LDA snakeInputs
	AND #%00000011
	CLC
	ADC #SNAKE_CHR_BODY_ROW
_snakeUpdateBody:
	TAY
	LDA snakePos_X
	LDX snakePos_Y
	JSR UpdateNamPos

;update the position
;when updated, the loop that goes through the rest of the snake can check for snake interception
;update pos as well as bouns checking with walls
	;update pos, check for wall collision
	LDA snakeLastInput
	LDX snakePos_X
	LDY snakePos_Y
	JSR UpdatePos

	STX snakePos_X
	STY snakePos_Y

	CPY #WALL_TOP
	BEQ _bumped
	CPY #WALL_BOTTOM
	BEQ _bumped
	CPX #WALL_LEFT
	BEQ _bumped
	CPX #WALL_RIGHT
	BNE _snakePosDone

_bumped:
	JSR ActivateGameOver

_snakePosDone:
	;update namBuffer through UpdateNamPos
	LDA #SNAKE_CHR_HEAD_ROW
	CLC
	ADC snakeLastInput
	TAY
	LDA snakePos_X
	LDX snakePos_Y
	JSR UpdateNamPos
	;now to the 2 remaining elements to be updated
	
	;loop to update snakeInputs buffer and to check for collisions with the current position
	;temp position variable for comparasions
	LDA snakePos_X
	STA snakeTempPos_X
	LDA snakePos_Y
	STA snakeTempPos_Y

	;translate the 16-bit length to an 8-bit indexer, this indexer covers up to 3 unnessesary elements, don't read these

;when outer is at the last index, use another inner loop
;first create the outer loop's index which should leave out remaining elements, create another counter which tells how many elements there are in the only parially filled byte
;snakeLength_lo, snakeLength_hi, snakeLengthCounter_lo, snakeLengthCounter_hi, use snakeTempPos_X and Y with this loop's own pos updater

;loop time
	;snakeLastInput must not have any ones apart from bit 0 and 1
	LDA snakeLastInput
	AND #%00000011
	STA snakeInputsTemp

	;create "meta loop" counter
	LDA snakeLength_hi
	LSR A
	TAX
	LDA snakeLength_lo
	ROR A
	TAY
	TXA
	LSR A
	TYA
	ROR A
	STA snakeInputsAllBytes		;the "meta loop" counter
	;the "last inner loop" counter is the two last bits in snakeLength_lo

	LDX #$FF


;OUTER LOOP
_snakeInputsOuterLoop:
	CPX snakeInputsAllBytes
	BEQ _snakeInputsLoopDone
	INX
	CPX snakeInputsAllBytes
	BNE _snakeInputsNotQuitting
	;set y to "last inner loop"
	LDA snakeLength_lo
	AND #%00000011
	TAY
	INY		;because of the y offset
	JMP _snakeInputsBoundsCheckDone
_snakeInputsNotQuitting:
	LDY #$05
_snakeInputsBoundsCheckDone:

	;clear temp's temp
	LDA #$00
	STA snakeInputsTempTemp

	;now shift current byte
	LDA snakeInputs, X		;this is faster
	ASL	A
	ROL snakeInputsTempTemp
	ASL A
	ROL snakeInputsTempTemp
	ORA snakeInputsTemp		;bit 0 and 1
	STA snakeInputs, X
	LDA snakeInputsTempTemp
	STA snakeInputsTemp

	;load the relevant byte to check and update on
	LDA snakeInputs, X
	STA snakeInputsDummy


;INNER LOOP
_snakeInputsLoop:
	DEY			;when it hits zero
	BEQ _snakeInputsOuterLoop
	
	;do stuff only with A
	LDA snakeInputsDummy
	AND #%00000011
	BNE _snakeInputsLoopUpDone
	;up
	INC snakeTempPos_Y
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopUpDone:
	CMP #$01
	BNE _snakeInputsLoopDownDone
	;down
	DEC snakeTempPos_Y
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopDownDone:
	CMP #$02
	BNE _snakeInputsLoopLeftDone
	;left
	INC snakeTempPos_X
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopLeftDone:
	;right
	DEC snakeTempPos_X
_snakeInputsLoopRightDone:

	;check for body colission
	LDA snakeTempPos_X
	CMP snakePos_X
	BNE _snakeInputsNoBumps
	LDA snakeTempPos_Y
	CMP snakePos_Y
	BEQ _snakeBumped
_snakeInputsNoBumps:
	;shift it
	LSR snakeInputsDummy
	LSR snakeInputsDummy
	;done, next "inner" iteration
	JMP _snakeInputsLoop

_snakeBumped:
	JSR ActivateGameOver
_snakeInputsLoopDone:
;done, now display tail and empty tile




;empty tile
;snakeInputsAllBytes
;snakeLength_lo, anded
	LDA snakeLength_lo
	AND #%00000011
	BEQ _snakeEmptyTileZero
	TAY
	LDA snakeInputs, X
_snakeEmptyTileLoop:
	LSR A
	LSR A
	DEY
	BNE _snakeEmptyTileLoop
	JMP _snakeEmptyTileLoopDone
_snakeEmptyTileZero:
	LDA snakeInputs, X			;there, if zero, A can't be shifted left
_snakeEmptyTileLoopDone:
	AND #%00000011
	;now A is loaded with the REVERSED direction
	TAX
	AND #%00000001
	BEQ _snakeEmptyTileAdd
	DEX
	JMP _snakeEmptyTileReverseDone
_snakeEmptyTileAdd:
	INX
_snakeEmptyTileReverseDone:
	TXA
	LDX snakeTempPos_X
	LDY snakeTempPos_Y
	JSR UpdatePos
	TXA
	STY snakeInputsTempTemp
	LDX snakeInputsTempTemp
	LDY #SNAKE_CHR_EMPTY_TILE
	JSR UpdateNamPos



;update snakeTempPos as tail
;snakeInputsAllBytes
;snakeLength_lo AND #03
	LDX snakeInputsAllBytes
	LDA snakeLength_lo
	AND #%00000011
	BEQ _snakeTailZero
	;not zero
	TAY
	LDA snakeInputs, X
_snakeTailLoop:
	DEY
	BEQ _snakeTailEvaluated
	LSR A
	LSR A
	JMP _snakeTailLoop
_snakeTailZero:
	;zero
	DEX
	LDA snakeInputs, X
	LSR A
	LSR A
	LSR A
	LSR A
	LSR A
	LSR A
_snakeTailEvaluated:
	AND #%00000011
	CLC
	ADC #SNAKE_CHR_TAIL_ROW
	TAY
	LDA snakeTempPos_X
	LDX snakeTempPos_Y
	JSR UpdateNamPos














;FRUIT
	;check for collision with fruit
	LDA snakePos_X
	CMP fruitPos_X
	BNE _snakeAfterIncrease
	LDA snakePos_Y
	CMP fruitPos_Y
	BNE _snakeAfterIncrease
	;ElongationSounds

	LDA #%00001010
	STA $400C		;Volume of the noise

	LDA #%0000011
	STA $400E		;Type of noise (it's a random generator for the noise channel)

	LDA #%1000000
	STA $400F		;Length of the noise

	;update score
	LDA score_lo
	CLC
	ADC #$01
	STA score_lo
	LDA score_hi
	ADC #$00
	STA score_hi

	;increase length
	LDA snakeLength_lo
	CLC
	ADC #$01
	STA snakeLength_lo
	LDA snakeLength_hi
	ADC #$00
	STA snakeLength_hi

	;change position of fruit, at the time of the writing, no other process is using the seed
_fruitChangePosition_Y:
	JSR PRNG
	LSR A
	LSR A
	LSR A
	TAX
	;check if inside bounds of the playing area, WALL_TOP and WALL_BOTTOM, if it is, roll again
_fruitCheckLoop_Y:
	CPX #WALL_TOP
	BEQ _fruitChangePosition_Y
	INX
	BEQ	_fruitChangePosition_Y		;if it hits zero; out of rage, thereby inside of the walls
	CPX #WALL_BOTTOM
	BNE _fruitCheckLoop_Y
;now y is in A
	TAX

_fruitChangePosition_X
	JSR PRNG
	LSR A
	LSR A
	LSR A
	TAY
_fruitCheckLoop_X:
	CPY #WALL_LEFT
	BEQ _fruitChangePosition_X
	INY
	BEQ _fruitChangePosition_X
	CPY #WALL_RIGHT
	BNE _fruitCheckLoop_X
;now x is in A
;done, now it's in a valid position

	LDY #FRUIT_CHR

	STA fruitPos_X
	STX fruitPos_Y
	JSR UpdateNamPos
_snakeAfterIncrease:
;FRUIT DONE



;return from tick
	RTS
;;;;


;GAME STATE TITLE
_gameStateTitle:
	
	;change seed
	INC seed

	;check for the player to press start
	LDA playerOneInput
	AND #%00010000
	BEQ _titleNotStarting

	;STARTING

	;snake psosition
	LDA #SNAKE_START_X
	STA snakePos_X
	LDA #SNAKE_START_Y
	STA snakePos_Y

	;snake length, snake is this +1 long
	LDA #$02
	STA snakeLength_lo
	LDA #$00
	STA snakeLength_hi

	;fruit position
	LDA #$15
	STA fruitPos_X
	LDA #$10
	STA fruitPos_Y

	;snake last input
	LDA #$03    ;right, facing right in the beginning
	STA snakeLastInput
	STA snakeLastInputTemp

	;snake inputs/buffer
	LDA #$FF            ;right in all elements (snake tiles, two bits per tile)
	STA snakeInputs     ;we start with the length of 4


	;starting: update background
	;disable NMI
	LDA #$00
	STA $2000
	LDA #%00000000
	STA $2001

	;load addresses
	LDA #LOW (background)
	STA backgroundPtr_lo
	LDA #HIGH (background)
	STA backgroundPtr_hi

	LDA #LOW (background + 960)
	STA backgroundDir_lo
	LDA #HIGH (attribute + 960)
	STA backgroundDir_hi

	JSR LoadNametable

	;enable NMI
	LDA #%10000000
	STA $2000
	LDA #%00011110
	STA $2001

	LDA #GAME_STATE_PLAYING
	STA gameState
_titleNotStarting:

	RTS


ActivateGameOver:
	;gameOver screen
	LDA #$00
	STA $2000
	LDA #%00000000
	STA $2001

	LDA #LOW (gameOverBackground)
	STA backgroundPtr_lo
	LDA #HIGH (gameOverBackground)
	STA backgroundPtr_hi

	LDA #LOW (gameOverBackground + 960)
	STA backgroundDir_lo
	LDA #HIGH (gameOverBackground + 960)
	STA backgroundDir_hi

	JSR LoadNametable

	LDA #%10000000
	STA $2000
	LDA #%00011110
	STA $2001

	;position of snake
	LDA #SNAKE_START_X
	STA snakePos_X
	LDA #SNAKE_START_Y
	STA snakePos_Y

	LDA #GAME_STATE_GAMEOVER
	STA gameState
	PLA
	PLA
	JMP _gameStateGameOver



;GAME STATE GAME OVER
_gameStateGameOver:
	LDX gameOverFrames
	INX
	STX gameOverFrames
	CPX #$80		;amount of frames to wait for title screen
	BNE _stillGameOver

	LDX #$00
	STX gameOverFrames

	;send player to the title screen
	LDA #$00
	STA $2000
	LDA #%00000000
	STA $2001

	;update nametable
	LDA #LOW (titleBackground)
	STA backgroundPtr_lo
	LDA #HIGH (titleBackground)
	STA backgroundPtr_hi

	LDA #LOW (titleBackground + 960)
	STA backgroundDir_lo
	LDA #HIGH (titleBackground + 960)
	STA backgroundDir_hi

	JSR LoadNametable

	LDA #%10000000
	STA $2000
	LDA #%00011110
	STA $2001

	LDA #GAME_STATE_TITLE
	STA gameState
_stillGameOver:
	RTS


;GAME STATE PAUSED
_gameStatePaused:
	LDA playerOnePressed
	AND #%00010000
	BEQ _stillPaused

	;Change back game state
	LDA #GAME_STATE_PLAYING
	STA gameState

	;Remove text
	JSR ResetSprites
_stillPaused:
	RTS
