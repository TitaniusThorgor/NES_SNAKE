;GAME STARTUP

;set namBuffer
	LDA #$00
	STA namBuffer

;PRNG, should be tied to a counter at the title
	LDA #$01
	STA seed

;start game state
	LDA #GAME_STATE_TITLE
	STA gameState
	
;engage sound
	LDA #$0F
	STA $4015	;enables pulse , pulse 2, triangle and niose channels

;snakeInputs
	LDA #$FF
	LDX #$00
_setSnakeInputs:
	STA snakeInputs, X
	INX
	CPX #SNAKE_BUFFER_LENGTH
	BNE _setSnakeInputs

;amount of frames to move
	LDA #$0C
	STA snakeFramesToMove
