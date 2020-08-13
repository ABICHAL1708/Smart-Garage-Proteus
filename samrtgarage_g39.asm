#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#  

jmp     st1

db     1024 dup(0)

st1:      cli

mov       ax,0200h
mov       ds,ax
mov       es,ax
mov       ss,ax
mov       sp,0FFFEH





car_count dw 0
full db 'FULL'
empty db 'EMPTY'
word_length db 0

;assigning port addresses
inputs equ 02h               ;Port B as always is given address 02(we know that in 8086 0, 2, 4, 6)
lcd_data equ 00h             ;Port A A is always gievn 00h
lcd_motor_control equ 04h    ;Port C (address range is 00h-06h)
control_io equ 06h           ;Control register
clock_timer equ 08h
remote_timer equ 0Ah
door_timer equ 0Ch
control_timer equ 0Eh

jmp     st1
db     1024 dup(0)
st1:

;initializing the RAM
mov ax,0200h
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0FFFEH

mov al,10000000b
out control_io,al
mov al, 00110100b
out control_timer, al
mov al, 0A8h
out clock_timer, al
mov al, 61h
out clock_timer, al



;startup:
initialize_lcd
call update_lcd

garage_is_closed:
in al, inputs
and al, 00000001b
cmp al, 1
je open_garage_door
jmp garage_is_closed

open_garage:
mov ah, 0                   ; resetting the value in car_flag to 0
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for any remote press
je close_garage_door
mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for the timer (300 seconds ie 5 minutes)
je close_garage_door
mov bl, al
and bl, 00000010b
cmp bl, 00000010b           ; checking whether the outer IR is triggered
je entering
mov bl, al
and bl, 00001000b
cmp bl, 00001000b           ; checking whether the inner IR is triggerd
je exiting
jmp open_garage

close_garage_door:
motor_clockwise
start_door_timer
check_closing:
in al, inputs
and al, 00100000b
cmp al, 00100000b       ; waiting until the door is closing completely
jne check_closing

stop_motor
jmp garage_is_closed

open_garage_door:
start_remote_timer
motor_anticlockwise
start_door_timer
check_open:
in al, inputs
and al, 00100000b
cmp al, 00100000b       ; waiting until the door is opening completely
jne check_open

stop_motor
jmp open_garage

entering:
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for remote press
je close_garage_door


mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for timer to finish its 5 minutes timeout
je close_garage_door


mov bl, al
and bl, 00000100b
cmp bl, 00000100b           ; checking if the object is a car or not
jne NotCar_instance1

mov ah, 1
NotCar_instance1:
mov bl, al
and bl, 00001000b
cmp bl, 00001000b       ; checkin for the triggering of inner IR
jne entering
cmp ah, 1


jne YesCar_instance1
inc car_count
call update_lcd


YesCar_instance1:
in al, inputs
mov bl, al
and bl, 00001000b
cmp bl, 00001000b 			; debounce delay
je YesCar_instance1
jmp open_garage

exiting:
in al, inputs
mov bl, al
and bl, 00000001b
cmp bl, 00000001b           ; checking for the remote press
je close_garage_door
mov bl, al
and bl, 00010000b
cmp bl, 00010000b           ; checking for the timer for 5 minutes timeout
je close_garage_door
mov bl, al
and bl, 00000100b
cmp bl, 00000100b           ; checking if the object is a car or not
jne NotCar_instance2
mov ah, 1
NotCar_instance2:
mov bl, al
and bl, 00000010b
cmp bl, 00000010b       ; checking if the outer IP is triggered or not
jne exiting
cmp ah, 1
jne YesCar_instance2
dec car_count
call update_lcd
YesCar_instance2:
in al, inputs
mov bl, al
and bl, 00000010b
cmp bl, 00000010b 				; debounce_delay
je YesCar_instance2
jmp open_garage

;all the macros

lcd_mode macro
		in al, lcd_motor_control
		and al, 00011111b
		or al, bl
		out lcd_motor_control, al
endm

initialize_lcd macro
		mov al, 00001111b
		out lcd_data, al
		mov bl, 00100000b
lcd_mode
		mov bl, 00000000b
lcd_mode
endm

lcd_add_ch macro
		push ax
		out lcd_data,al
		mov bl,10100000b
lcd_mode
		mov bl,10000000b
lcd_mode
		pop ax
endm

lcd_display_word macro
		mov ch,0
		mov cl, word_length
putting:
		mov al, [di]
lcd_add_ch
		inc di
		loop putting
endm

clear_lcd macro
		mov al, 00000001b
out lcd_data, al
		mov bl,00100000b
lcd_mode
		mov bl,00000000b
lcd_mode
endm

lcd_bin_to_bcd macro
		mov ax, car_count
		mov cx, 0
	converting:
		mov bl, 10
		div bl
		add ah, '0'
		mov bl, ah
		mov bh, 0
		push bx
		inc cx
		mov ah, 0
		cmp ax, 0
		jne converting
printing:
pop ax
lcd_add_ch
loop printing
endm

start_door_timer macro
		mov al, 10110000b
 		out control_timer, al
		mov al, 0F4h
		out door_timer, al
		mov al, 01h
		out door_timer, al
endm

start_remote_timer macro
mov al, 01110000b
out control_timer, al
mov al, 30h
out remote_timer, al
mov al, 75h
out remote_timer, al
endm

motor_clockwise macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000001b
out lcd_motor_control, al
endm

motor_anticlockwise macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000010b
out lcd_motor_control, al
endm

stop_motor macro
in al, lcd_motor_control
and al, 11111100b
or al, 00000000b
out lcd_motor_control, al
endm


		update_lcd proc near
		clear_lcd
		mov al, ' '
		lcd_add_ch
		cmp car_count, 0
		jnz notempty
		lea di, empty
		mov word_length, 5
		jmp loaded
		notempty:
		cmp car_count, 2000
		jl notfull
		lea di, full
		mov word_length, 4
		jmp loaded
		notfull:
		lcd_bin_to_bcd
		ret
		loaded:
		lcd_display_word
		ret
		update_lcd endp
