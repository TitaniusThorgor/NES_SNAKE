;MAIN FILE
;RESET, NMI, general functions

	.include "header.6502.asm"

;RESET
	.bank 0
	.org $C000
RESET:			;CPU starts reading here
	SEI			;disable IRQ interrupts, external interrupts
	CLD			;disable decimal mode, something the NES 6502 chip does not have
	LDX #$40
	STX $4017	;disable APU IRQs
	LDX #$FF
	TXS			;set up stack
	INX			;now x = 0
	;(2000)
	;76543210 10010000
	;| ||||||
	;| ||||++- Base nametable address
	;| ||||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
	;| |||+--- VRAM address increment per CPU read/write of PPUDATA
	;| |||     (0: increment by 1, going across; 1: increment by 32, going down)
	;| ||+---- Sprite pattern table address for 8x8 sprites (0: $0000; 1: $1000)
	;| |+----- Background pattern table address (0: $0000; 1: $1000)
	;| +------ Sprite size (0: 8x8; 1: 8x16)
	;|
	;+-------- Generate an NMI at the start of the
	;            vertical blanking interval vblank (0: off; 1: on)
	STX	$2000	;disable NMI for now
	;(2001)
	;76543210
	;||||||||
	;|||||||+- Grayscale (0: normal color; 1: AND all palette entries
	;|||||||   with 0x30, effectively producing a monochrome display;
	;|||||||   note that colour emphasis STILL works when this is on!)
	;||||||+-- Disable background clipping in leftmost 8 pixels of screen
	;|||||+--- Disable sprite clipping in leftmost 8 pixels of screen
	;||||+---- Enable background rendering
	;|||+----- Enable sprite rendering
	;||+------ Intensify reds (and darken other colors)
	;|+------- Intensify greens (and darken other colors)
	;+-------- Intensify blues (and darken other colors)
	STX $2001	;disable rendering
	STX $4010	;disable DMC IRQs
	
	JSR VBlankWait


;CLEAR MEMORY, MOVE SPRITES
_clearMem:
	LDA #$00
	STA $0000, X
	STA $0100, X
	STA $0300, X
	STA $0400, X
	STA $0500, X
	STA $0600, X
	STA $0700, X

	LDA $FE
	STA $0200, X	;move all sprites off screen
	INX
	BNE _clearMem	;when x turns from $FF to $00 the zero flag is set
	
	JSR VBlankWait

;LOAD PALETTE
	;PPU: palett recognition to address $3F00
	LDA $2002	;read PPU status to reset the high/low latch to high
	LDA #$3F	;load the high byte
	STA $2006	;write the high byte
	LDA #$00	;load the low byte
	STA $2006	;write the low byte
	;that code tells the PPU to set its address to $3F10, now the PPU data port at $2007 is ready to accept data
	;loop with x and feed PPU, use this method if the whole palette is changed, otherwise use $3F10 and 32 bytes up
	LDX #$00
_loadPalettsLoop:
	LDA palette, X
	STA $2007			;write the color one by one to the same address
	INX					;increment x
	CPX #$20			;compare x with $20 = 32, which is the size of both paletts combined
	BNE _loadPalettsLoop	;Branch if Not Equal
	
	
;LOAD TITLE BACKGROUND
	LDA #LOW (titleBackground) ;some NESASM3 exclusive features
	STA backgroundPtr_lo
	LDA #HIGH (titleBackground)
	STA backgroundPtr_hi

	LDA #LOW (titleAttribute)
	STA backgroundDir_lo
	LDA #HIGH (titleAttribute)
	STA backgroundDir_hi

	JSR LoadNametable
	
	
	;sprite data: $0200 - $0240 with 4 bytes interval
	;sprite data layout: 
	;1 - Y Position - vertical position of the sprite on screen. $00 is the top of the screen. Anything above $EF is off the bottom of the screen.
	;2 - Tile Number - this is the tile number (0 to 256) for the graphic to be taken from a Pattern Table.
	;3 - Attributes - this byte holds color and displaying information:
	;  76543210
	;  ||||||||
	;  |||   ++- Color Palette of sprite.  Choose which set of 4 from the 16 colors to use
	;  |||
	;  ||+------ Priority (0: in front of background; 1: behind background)
	;  |+------- Flip sprite horizontally
	;  +-------- Flip sprite vertically
	;4 - X Position - horizontal position on the screen. $00 is the left side, anything above $F9 is off screen
	
	.include "gameStartup.6502.asm"

	;enable NMI, sprites from pattern table table 0
	LDA #%10000000
	STA $2000
	
	;enable sprites
	LDA #%00010000
	STA $2001


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GAME LOOP

_gameLoop:
	LDA #$00
	STA nmiDone

	;Here, do the actual game

	;states
	LDA gameState

	CMP #GAME_STATE_PLAYING
	BNE _notGameStatePlaying
	JSR _gameStatePlaying
	JMP Forever
_notGameStatePlaying:

	CMP #GAME_STATE_TITLE
	BNE _notGameStateTitle
	JSR _gameStateTitle
	JMP Forever
_notGameStateTitle:

	CMP #GAME_STATE_GAMEOVER
	BNE _notGameStateGameOver
	JSR _gameStateGameOver
	JMP Forever
_notGameStateGameOver:

	CMP #GAME_STATE_PAUSED
	BNE _notGameStatePaused
	JSR _gameStatePaused
	JMP Forever
_notGameStatePaused:

Forever:
	LDA nmiDone
	CMP #$01
	BEQ _gameLoop
	JMP Forever


;IMPLEMENTATION OF GAME STATES
	.include "game.6502.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;FUNCTIONS

VBlankWait:
	BIT $2002		;BIT loads bit 7 into N, the bit apperently tells when the vBlank is done
	BPL VBlankWait	;BPL, Branch on PLus, checks the N register if it's 0
	RTS				;ReTurn from Subroutine

;adds one change of tile in nametable
;USAGE: load backgroundDir_hi with the high byte of the address, backgroundDir_lo with the low byte and A with the tile index
NamAdd:
	LDX namBuffer
	INX
	STA namBuffer, X
	INX
	LDA backgroundDir_lo
	STA namBuffer, X
	INX
	LDA backgroundDir_hi
	CLC
	ADC #$20
	STA namBuffer, X
	STX namBuffer

	RTS

;loads both pattern and attributes
;IMPORTANT: this must be done during VBlank
;usage: load backgroundPtr with the address of the pattern table, load backgroundDir with address of the nametable
LoadNametable:
	LDA $2002             ;read PPU status to reset the high/low latch
	LDA #$20
	STA $2006             ;write the high byte of $2000 address (start of nametable 0 in PPU memory)
	LDA #$00
	STA $2006             ;write the low byte of $2000 address

	;backgroundPtr_lo and backgroundPtr_hi are loaded
	LDX #$00
	LDY #$00
_loadBackgroundLoop:
	LDA [backgroundPtr_lo], Y
	STA $2007
	INY
	BNE _loadBackgroundLoop	;let it loop, let it loop, when zero
	INC backgroundPtr_hi	;increment memory (makes the pointer as a whole go up 256 bytes)
	INX
	CPX #$04	;make the 256 loop four times, this will load the attributes as well
	BNE _loadBackgroundLoop

	;load attribute table
;	LDA $2002             ;read PPU status to reset the high/low latch
;	LDA #$23
;	STA $2006             ;write the high byte of $23C0 address
;	LDA #$C0
;	STA $2006             ;write the low byte of $23C0 address
;	LDY #$00
;_loadAttributeLoop:
;	LDA [backgroundDir_lo], Y
;	STA $2007             ;write to PPU
;	INX
;	CPX #$20              ;8*4= $20 which is 32 in dec
;	BNE _loadAttributeLoop

	RTS
	

;PRNG, a pseudorandom number generatior taken from NesDev
;seed needs to be set someware at the start of the game
;usage: this fills A with the generated number, also uses Y
PRNG:
	LDY #08     	;iteration count (generates 8 bits)
	LDA seed
_PRNG_loop:
	ASL A			;shift the register
	ROL seed + 1
	BCC _PRNG_loop
	EOR #$39		;apply XOR feedback whenever a 1 bit is shifted out
	DEY
	BNE _PRNG_loop
	STA seed
	CMP #00			;reload flags
	RTS


ResetSprites:
	LDX #$00
_resetSpritesLoop:
	LDA $FE
	STA $0200, X	;move all sprites off screen
	INX
	BNE _resetSpritesLoop
	RTS


;NMI
;graphics interrupt, the only "time indicator". Expected to be 60 fps, (50) for PAL
NMI:
	;sprite setup, it seems this has to be done every NMI interrupt, 64 in the pattern table
	;sprite DMA setup (direct memory access), typically $0200-02FF (internal RAM) is used for this, which it is in this case
;SPRITE DMA
	LDA #$00	;low byte of $0200
	STA $2003
	LDA #$02
	STA $4014	;sets the high byte


;UDPATE BACKGROUND
;make updates to the background, ca 2250 cycles, ca 160 bytes can be copied from RAM
;apply changes in RAM, then apply them here
;in this case we can only copy 127 bytes, not "the full 160"
;namBuffer
	LDX namBuffer
	BEQ _afterNamUpdate

	LDA $2002             ;read PPU status to reset the high/low latch
_namUpdateLoop:
	;high-byte
	LDA namBuffer, X
	STA $2006
	DEX
	;low-byte
	LDA namBuffer, X
	STA $2006
	DEX
	;tile index
	LDA namBuffer, X
	STA $2007

	DEX		;element 0 is a flag and has already been read, this is just perfect flag/layout management, got rid of that CMP opcode
	BNE _namUpdateLoop

	STX namBuffer
_afterNamUpdate:


;MISC: Color Swapping with the Select button, can be done anytime since the button is never used elseware
;The effects will be shown first after a frame: not noticable
	LDX colorTemp
	LDA colorTemp
	CLC
	ADC #$10
	STA colorTempTemp

	LDA $2002
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
_loadAlternatePalettsLoop:
	LDA palette + $10, X
	STA $2007
	INX
	CPX colorTempTemp
	BNE _loadAlternatePalettsLoop


;PPU CLEAN UP
	LDA #%10010000	;enable NMI, sprites from pattern table 0, background from pattern table 1
	STA $2000
	LDA #%00011110
	STA $2001		;enable sprites and background, no clipping on left side
	LDA #$00
	STA $2005		;tells PPU there is no background scrolling
	STA $2005


;INPUT
;A, B, Select, Start, Up, Down, Left, Right
	LDA playerOneInput
	STA playerOnePreviousInput
	;latch buttons, prepare buttons to send out signals
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016
	
	LDX #$08
_input1Loop:
	LDA $4016
	LSR A
	ROL playerOneInput
	DEX
	BNE _input1Loop

	LDX #$08
_input2Loop:
	LDA $4017
	LSR A
	ROL playerTwoInput
	DEX
	BNE _input2Loop

;Player one pressed
	LDA playerOneInput
	EOR playerOnePreviousInput
	AND playerOneInput
	STA playerOnePressed

;Player one released
	LDA playerOneInput
	EOR playerOnePreviousInput
	AND playerOnePreviousInput
	STA playerOneReleased



;MISC: Change palette wiht Select
;This does not look to pretty, a face lift would help
	LDA playerOnePressed
	AND #%00100000
	BEQ _afterPaletteSelect

;increment the counter
	LDX colorSwap
	INX
	STX colorSwap
	CPX #$04		;number of palettes
	BNE _afterColorSwap
	LDA #$00
	STA colorSwap
_afterColorSwap:

	LDX #$FF
	LDA #$F0
_colorSwapIndexLoop:
	CLC
	ADC #$10
	INX
	CPX colorSwap
	BNE _colorSwapIndexLoop
	STA colorTemp
_afterPaletteSelect:


;end of NMI
	LDA #$01
	STA nmiDone
	RTI	;ReTurn from Interrupt



;PRG DATA
;use camel-casing
	.bank 1
	.org $A000
palette:
	.incbin "persistant.pal"
	;0 of the 4 colors in one pallete: beginning of the sprite table
	.incbin "persistant.pal"

;two other colors
	.incbin "blue.pal"
	.incbin "green.pal"
	.incbin "red.pal"

;game background
background:
	.incbin "snake.nam"
	.rsset background + 960
attribute	.rs 0

;title background
titleBackground:
	.incbin "title.nam"
	.rsset titleBackground + 960
titleAttribute	.rs 0

;gameOver background
gameOverBackground:
	.incbin "gameOver.nam"
	.rsset gameOverBackground + 960
gameOverAttribute	.rs 0

;level data; x then y
;the first two bytes describes the player starting position
;the 4th and 5th bytes describes the fruit starting position
;the 6th byte is the horizontal outer wall position
;the 7th byte is the vertical outer wall position
;the 8th byte describes the length of the "wall overrides"
;the rest of the bytes are the positions of the wall tiles

;level_1 is a 16x16 empty playing area
level_1:		 ;fruit		;wall	
	.db $0A, $10, $12, $10, $
;level_2 is the same as the previous but with one wall tile
level_2:
	.db $0A, $10, 1, $0C, $12

level_end:

;INTERRUPTS OR VECTORS
	;; $FFFA-$FFFB = NMI vector
	;; $FFFC-$FFFD = Reset vector
	;; $FFFE-$FFFF = IRQ/BRK vector
	.org $FFFA
	.dw NMI 	;"Update" vector, processor starts to read code here each graphics cycle if enabled
	.dw RESET	;the processor will start exicuting here when the program starst as well as when the reset button is pressed 
	.dw 0		;IRQs won't be used
	
;GRAPHICS BANKS
	.bank 2		;graphics bank
	.org $0000
	.incbin "main.chr"		;includes 8KB graphics file
