# Bridget Brinkman
# brb351

# print_str macro
# preserves a0, v0
# debugging
.macro print_str %str
	.data
	print_str_message: .asciiz %str
	.text
	push a0
	push v0
	la a0, print_str_message
	li v0, 4
	syscall
	pop v0
	pop a0
.end_macro

# Cardinal directions.
.eqv DIR_N 0
.eqv DIR_E 1
.eqv DIR_S 2
.eqv DIR_W 3

# Game grid dimensions.
.eqv GRID_CELL_SIZE 4 # pixels
.eqv GRID_WIDTH  16 # cells
.eqv GRID_HEIGHT 14 # cells
.eqv GRID_CELLS 224 #= GRID_WIDTH * GRID_HEIGHT

# How long the snake can possibly be.
.eqv SNAKE_MAX_LEN GRID_CELLS # segments

# How many frames (1/60th of a second) between snake movements.
.eqv SNAKE_MOVE_DELAY 12 # frames

# How many apples the snake needs to eat to win the game.
.eqv APPLES_NEEDED 20

# ------------------------------------------------------------------------------------------------
.data

# set to 1 when the player loses the game (running into the walls/other part of the snake).
lost_game: .word 0

# the direction the snake is facing (one of the DIR_ constants).
snake_dir: .word DIR_N

# how long the snake is (how many segments).
snake_len: .word 2

# parallel arrays of segment coordinates. index 0 is the head.
snake_x: .byte 0:SNAKE_MAX_LEN
snake_y: .byte 0:SNAKE_MAX_LEN

# used to keep track of time until the next time the snake can move.
snake_move_timer: .word 0

# 1 if the snake changed direction since the last time it moved.
snake_dir_changed: .word 0

# how many apples have been eaten.
apples_eaten: .word 0

# coordinates of the (one) apple in the world.
apple_x: .word 3
apple_y: .word 2

# A pair of arrays, indexed by direction, to turn a direction into x/y deltas.
# e.g. direction_delta_x[DIR_E] is 1, because moving east increments X by 1.
#                         N  E  S  W
direction_delta_x: .byte  0  1  0 -1
direction_delta_y: .byte -1  0  1  0

.text

# ------------------------------------------------------------------------------------------------

# these .includes are here to make these big arrays come *after* the interesting
# variables in memory. it makes things easier to debug.
.include "display_2211_0822.asm"
.include "textures.asm"

# ------------------------------------------------------------------------------------------------

.text
.globl main
main:
	jal setup_snake
	jal wait_for_game_start

	# main game loop
	_loop:
		jal check_input
		jal update_snake
		jal draw_all
		jal display_update_and_clear
		jal wait_for_next_frame
	jal check_game_over
	beq v0, 0, _loop

	# when the game is over, show a message
	jal show_game_over_message
syscall_exit

# ------------------------------------------------------------------------------------------------
# Misc game logic
# ------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------

# waits for the user to press a key to start the game (so the snake doesn't go barreling
# into the wall while the user ineffectually flails attempting to click the display (ask
# me how I know that that happens))
wait_for_game_start:
enter
	_loop:
		jal draw_all
		jal display_update_and_clear
		jal wait_for_next_frame
	jal input_get_keys_pressed
	beq v0, 0, _loop
leave

# ------------------------------------------------------------------------------------------------

# returns a boolean (1/0) of whether the game is over. 1 means it is.
check_game_over:
enter
	li v0, 0

	# if they've eaten enough apples, the game is over.
	lw t0, apples_eaten
	blt t0, APPLES_NEEDED, _endif
		li v0, 1
		j _return
	_endif:

	# if they lost the game, the game is over.
	lw t0, lost_game
	beq t0, 0, _return
		li v0, 1
_return:
leave

# ------------------------------------------------------------------------------------------------

show_game_over_message:
enter
	# first clear the display
	jal display_update_and_clear

	# then show different things depending on if they won or lost
	lw t0, lost_game
	bne t0, 0, _lost
		# they finished successfully!
		li   a0, 7
		li   a1, 25
		lstr a2, "yay! you"
		li   a3, COLOR_GREEN
		jal  display_draw_colored_text

		li   a0, 12
		li   a1, 31
		lstr a2, "did it!"
		li   a3, COLOR_GREEN
		jal  display_draw_colored_text
	j _endif
	_lost:
		# they... didn't...
		li   a0, 5
		li   a1, 30
		lstr a2, "oh no :("
		li   a3, COLOR_RED
		jal  display_draw_colored_text
	_endif:

	jal display_update_and_clear
leave

# ------------------------------------------------------------------------------------------------
# Snake
# ------------------------------------------------------------------------------------------------

# sets up the snake so the first two segments are in the middle of the screen.
setup_snake:
enter
	# snake head in the middle, tail below it
	li  t0, GRID_WIDTH
	div t0, t0, 2
	sb  t0, snake_x
	sb  t0, snake_x + 1

	li  t0, GRID_HEIGHT
	div t0, t0, 2
	sb  t0, snake_y
	add t0, t0, 1
	sb  t0, snake_y + 1
leave

# ------------------------------------------------------------------------------------------------

# checks for the arrow keys to change the snake's direction.
check_input:
enter
	lw a0, snake_dir_changed
	bne a0, zero, _break # if snake_dir_changed != 0, branch to break, avoids weird head-in-body case for the snake
	jal input_get_keys_held
	# switch cases to switch the direction that the snake is traveling
	beq v0, KEY_U, _north
	beq v0, KEY_D, _south
	beq v0, KEY_R, _east
	beq v0, KEY_L, _west
	j _break
	_north:
		lw a0, snake_dir
		beq a0, DIR_N, _break
		beq a0, DIR_S, _break
		li, a1, DIR_N
		sw a1, snake_dir
		li a1, 1
		sw a1, snake_dir_changed
		j _break
	_south:
		lw a0, snake_dir
		beq a0, DIR_N, _break
		beq a0, DIR_S, _break
		li, a1, DIR_S
		sw a1, snake_dir
		li a1, 1
		sw a1, snake_dir_changed
		j _break
	_east:
		lw a0, snake_dir
		beq a0, DIR_E, _break
		beq a0, DIR_W, _break
		li, a1, DIR_E
		sw a1, snake_dir
		li a1, 1
		sw a1, snake_dir_changed
		j _break
	_west:
		lw a0, snake_dir
		beq a0, DIR_E, _break
		beq a0, DIR_W, _break
		li, a1, DIR_W
		sw a1, snake_dir
		li a1, 1
		sw a1, snake_dir_changed
		j _break
	_break:
leave

# ------------------------------------------------------------------------------------------------

# update the snake.
update_snake:
enter
	# if-else
	# slowing the snake down
	lw a0, snake_move_timer
	beq a0, zero, _else # if snake_move_timer == 0, do else
	_decrement: # if snake_move_timer != 0, decrement snake_move_timer
		sub a0, a0, 1
		sw a0, snake_move_timer
		j _endif # jump over the else part
	_else: # else, set snake_move_timer = SNAKE_MOVE_DELAY
		li a1, SNAKE_MOVE_DELAY
		sw a1, snake_move_timer # snake_move_timer = SNAKE_MOVE_DELAY
		sw zero, snake_dir_changed # snake_dir_changed = 0
		jal move_snake
	_endif:
leave

# ------------------------------------------------------------------------------------------------

move_snake:
enter s0, s1
	#jal shift_snake_segments
	#jal compute_next_snake_pos
	#sb v0, snake_x
	#sb v1, snake_y
	
	jal compute_next_snake_pos # store the return values v0 and v1 in s0 and s1
	move s0, v0
	move s1, v1
	
	# now, for the rest of the function, s0 and s1 are the "next position"
	
	# switch case
	
	# snake collides with the edges of the screen = _game_over
	blt s0, 0, _game_over
	bge s0, GRID_WIDTH, _game_over
	blt s1, 0, _game_over
	bge s1, GRID_HEIGHT, _game_over
	
	# if snake hits itself = game over
	move a0, s0
	move a1, s1
	jal is_point_on_snake
	beq v0, 1, _game_over
	
	
	lw a1, apple_x
	bne s0, a1, _move_forward
	lw a2, apple_y
	bne s1, a2, _move_forward
	# otherwise eat apple 
	# s0 == apple_x && s1 == apple_y, eat apple
	_eat_apple:
		lw a1, apples_eaten
		add a1, a1, 1 # apples_eaten ++;
		sw a1, apples_eaten
		
		lw a1, snake_len
		add a1, a1, 1 # snake_len ++;
		sw a1, snake_len
		
		jal shift_snake_segments
		sb s0, snake_x
		sb s1, snake_y
		
		jal move_apple # move apple
		j _break
	_move_forward:
		jal shift_snake_segments
		sb s0, snake_x
		sb s1, snake_y
		j _break
	_game_over:
		li a0, 1
		sw a0, lost_game
		j _break
	_break:
	
leave s0, s1

# ------------------------------------------------------------------------------------------------

shift_snake_segments:
enter s0, s1
	lw s0, snake_len
	sub s0, s0, 1 # s0 is loop counter, starts at s0 = snake_len - 1
	_loop:
		blt s0, 1, _next # if s0 < 1, jump to next, otherwise continue looping
		
		sub s1, s0, 1 # s1 = s0 - 1
		lb s2, snake_x(s1) # s2 = snake_x[i-1]
		sb s2, snake_x(s0) # snake_x[i] = snake_x[i-1]
		
		lb s2, snake_y(s1) # s2 = snake_y[i-1]
		sb s2, snake_y(s0) # snake_y[i] = snake_y[i-1]
	
		sub s0, s0, 1 # s0--;
	j _loop
	_next:
leave s0, s1

# ------------------------------------------------------------------------------------------------

move_apple:
enter s0, s1
	_loop:
		
		# random x coord value in v0
		li a0, 0
		li a1, GRID_WIDTH
		li v0, 42
		syscall # now v0 contains a random integer
		
		move s0, v0 # store it in s0
	
		
		# random y coord value in v0
		li a0, 0
		li a1, GRID_HEIGHT
		li v0, 42
		syscall # now v0 contains a random integer
		
		move s1, v0 # store it in s1
		
		
		move a0, s0 # move it back to a0
		move a1, s1 # move it back to a1
		
		jal is_point_on_snake # call function with parameters a0 and a1
		
		# debugging to see if is_point_on_snake returns 0s and 1s correctly
		#move a0, v0
		#li v0, 1
		#syscall
		#move v0, a0
		
		beq v0, 1, _loop
		j _break
	_break: # after the loop, store the random x, y coordinate into apple_x and apple_y
	sw s0, apple_x
	sw s1, apple_y
leave s0, s1

# ------------------------------------------------------------------------------------------------

compute_next_snake_pos:
enter
	# t9 = direction
	lw t9, snake_dir

	# v0 = direction_delta_x[snake_dir]
	lb v0, snake_x
	lb t0, direction_delta_x(t9)
	add v0, v0, t0

	# v1 = direction_delta_y[snake_dir]
	lb v1, snake_y
	lb t0, direction_delta_y(t9)
	add v1, v1, t0
leave

# ------------------------------------------------------------------------------------------------

# takes a coordinate (x, y) in a0, a1.
# returns a boolean (1/0) saying whether that coordinate is part of the snake or not.
is_point_on_snake:
enter
	# for i = 0 to snake_len
	li t9, 0
	_loop:
		lb t0, snake_x(t9)
		bne t0, a0, _differ
		lb t0, snake_y(t9)
		bne t0, a1, _differ

			li v0, 1
			j _return

		_differ:
	add t9, t9, 1
	lw  t0, snake_len
	blt t9, t0, _loop

	li v0, 0

_return:
leave

# ------------------------------------------------------------------------------------------------
# Drawing functions
# ------------------------------------------------------------------------------------------------

draw_all:
enter
	# if we haven't lost...
	lw t0, lost_game
	bne t0, 0, _return

		# draw everything.
		jal draw_snake
		jal draw_apple
		jal draw_hud
_return:
leave

# ------------------------------------------------------------------------------------------------

draw_snake:
enter s0
	li s0, 0 # loop counter
	lw a3, snake_len
	_loop:
		
		bge s0, a3, _next
		
		lb a0, snake_x(s0)
		mul a0, a0, GRID_CELL_SIZE
		
		lb a0, snake_x(s0)
		mul a0, a0, GRID_CELL_SIZE
		
		lb a1, snake_y(s0)
		mul a1, a1, GRID_CELL_SIZE
		
		la a2, tex_snake_segment
		
		# if-else
		bne s0, 0, _draw_body  # if s0 == 0, draw head
		_draw_head:
			# load tex_snake_head[snake_dir * 4] into a2 with lw
			lw a2, snake_dir # first, load snake_dir
			mul a2, a2, 4 # multiply by 4
			lw a2, tex_snake_head(a2) # load tex_snake_head[snake_dir * 4] into a2
			j _endif # jump over the else
		_draw_body: # else, draw body
			la a2, tex_snake_segment
		_endif:
		
		jal display_blit_5x5_trans
		
		add s0, s0, 1
		j _loop
	_next:
leave s0

# ------------------------------------------------------------------------------------------------

draw_apple:
enter
	lw a0, apple_x # set a0 to apple_x * GRID_CELL_SIZE
	mul a0, a0, GRID_CELL_SIZE
	lw a1, apple_y
	mul a1, a1, GRID_CELL_SIZE # set a1 to apple_y * GRID_CELL_SIZE
	la a2, tex_apple # load apple's texture into a2
	jal display_blit_5x5_trans
leave

# ------------------------------------------------------------------------------------------------

draw_hud:
enter
	# draw a horizontal line above the HUD showing the lower boundary of the playfield
	li  a0, 0
	li  a1, GRID_HEIGHT
	mul a1, a1, GRID_CELL_SIZE
	li  a2, DISPLAY_W
	li  a3, COLOR_WHITE
	jal display_draw_hline

	# draw apples collected out of remaining
	li a0, 1
	li a1, 58
	lw a2, apples_eaten
	jal display_draw_int

	li a0, 13
	li a1, 58
	li a2, '/'
	jal display_draw_char

	li a0, 19
	li a2, 58
	li a2, APPLES_NEEDED
	jal display_draw_int
leave
