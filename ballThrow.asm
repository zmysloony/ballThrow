.macro sqrt(%dest, %s)
#	andi	$t5, %s, 0xFFFF0000
#	sra	$t5, $t5, 16
#	mtc1	$t5, $f0
#	mtc1	$t6, $f1
#	cvt.s.w	$f0, $f0
#	cvt.s.w	$f1, $f1
#	div.s	$f1, $f1, $f2
#	add.s	$f0, $f0, $f1
#	sqrt.s	$f0, $f0
#	cvt.w.s	$f0, $f0
	#round.w.s $f0, $f0
#	mfc1	%dest, $f0
	mtc1	%s, $f0
	cvt.s.w	$f0, $f0
	sqrt.s	$f0, $f0
	cvt.w.s	$f0, $f0
	mfc1	%dest, $f0
	sll	%dest, %dest, 8
.end_macro
.macro muls (%dest, %a, %b)
	beqz	%a, endM2
	mult	%a, %b
	mflo	%dest
	srl	%dest, %dest, 16
	mfhi	$t5
	sll	$t5, $t5, 16
endM2:	or	%dest, %dest, $t5
.end_macro
.macro divs (%dest, %a, %b)
	beqz	%a, endM1
	andi	%dest, %a, 0xFFFF0000
	div	%dest, %dest, %b
	sll	%dest, %dest, 16
	andi	$t5, %a, 0x0000FFFF
	sll	$t5, $t5, 16
	divu	$t5, $t5, %b
	andi	$t5, $t5, 0x0000FFFF
endM1:	or	%dest, $t5, %dest
.end_macro
#input macros
.macro	getInput (%dest, %sourcestring)
	li	$v0, 4
	la	$a0, %sourcestring
	syscall
	li	$v0, 6
	syscall
	mul.s	$f0, $f0, $f2
	round.w.s $f0, $f0
	mfc1	%dest, $f0
.end_macro
.macro	toQ16 (%dest, %label)
	l.s	$f0, %label
	mul.s	$f0, $f0, $f2
	round.w.s $f0, $f0
	mfc1	%dest, $f0
.end_macro

	.data
outputf:.asciiz "res.bmp"
give_x:	.asciiz "Starting x position(0-1024):"
give_y: .asciiz "Starting y position(0-1024):"
give_vx:.asciiz	"Starting horizontal velocity: "
give_vy:.asciiz	"Starting vertical velocity: "
header:	.word	0x4d420000
	.word	131134 0 62 40 1024 1024
	.half	1 1
	.word	0 0 2 0 2 0
	.word	0x00eeeeee 0x00000000	#first - background colour, second - line colour
pxdata:	.space	131072
	


#below are real values of constants multiplied by 100
constdr:.float	0.16	#p*A*C/2 - explained below (we assume air density at 25 Celsius, 0.35 drag coefficient and ball with diameter of 1 metre)
gravity:.float	9.87	#[m/s^2]
mass:	.float	30	#[kg]
vx:	.float	20	#[m/s]
vy:	.float	35	#[m/s]
xstart:	.float	420	#[m]
ystart: .float	900	#[m]
stepT:	.float	0.02	#[s] time between simulation steps
conv:	.float	65536
bounceE:.float	0.6
	.text
	.globl main
	
	#air friction formula  F_d = (pv^2AC/2)
	#where:	p - air density
	#	v - total velocity
	#	A - cross-sectional area
	#	C - drag coefficient
	
	#horizontal velocity formula  v_x(t) = v_x - abs((F_d*v_x)/(v*m))*dt
	#vertical velocity formula  v_y(t) = v_y - abs((F_d*v_y)/(v*m))*dt - g*dt
	#	dt - time step
	
main:
	l.s	$f2, conv
	getInput ($t2, give_x)
	getInput ($t3, give_y)
	getInput ($t0, give_vx)
	getInput ($t1, give_vy)
	move	$a2, $t2
	move	$a3, $t3
	move	$a0, $t0
	move	$a1, $t1
	
	
	#initialize constants
	toQ16(	$t6, bounceE)
	toQ16(	$t9, gravity)
	toQ16(	$t8, stepT)
	toQ16(	$s7, mass)
	toQ16(	$s6, constdr)
	muls	($s5, $t9, $t8)		#s5 - velocity change due to gravity (per step)
	muls	($s4, $s5, $t8)	#s4 - above * step - used to detect when the ball should stop
	jal	beginStep
	
	#here executes the calculation loop
	
	#begin file operations
	li	$v0, 13
	la	$a0, outputf
	li	$a1, 1
	syscall
	move	$s3, $v0
	
	li	$v0, 15
	move	$a0, $s3
	la	$a1, header+2
	li	$a2, 131134
	syscall
	
	li	$v0, 16
	syscall
	#file closed and bitmap saved
	li	$v0, 10
	syscall
	#PROGRAM ENDS
	
bounceCheck:
	abs	$t2, $a1
	ble	$t2, $s5, endSimulation
	li	$t0, 1
	sub	$a1, $t0, $a1
	muls	($a1, $a1, $t6)	#multiply v_x and v_y by a value from 0 to 1, to
	muls	($a0, $a0, $t6)	#represent energy loss upon impact
	li	$a3, 0
beginStep:
	add	$s3, $s3, $t8		#s3 - total simulation time (not used in calculations, just for fun)
	muls	($t0, $a0, $a0)		#t0 = v_x*v_x
	muls	($t1, $a1, $a1)		#t1 = v_y*v_y
	addu	$t0, $t0, $t1
	#we have to use coproc 1 for quick sqrt
	sqrt	($t0, $t0)
	bnez	$t0, skip01
	move 	$t0, $s5
skip01:
	#mulu	$t0, $t0, 10		#t0 - total velocity	
	muls	($t1, $t0, $t0)
	muls	($t1, $t1, $s6)		#t1 - total air stopping force
	muls	($t0, $t0, $s7)		#t0 - v*m
	#check if total velocity==0, if true, then set it to (grav.acceleration*time_quantum)
	
	#calculate change in v_x due to air drag
	muls	($t2, $t1, $a0)	#air drag*v_x
	divs	($t2, $t2, $t0)	#(air drag*v_x) / (v*m)
	#abs	$t2, $t2
	muls	($t2, $t2, $t8)	#t2 - change in horizontal velocity
	sub	$a0, $a0, $t2	#v_x = v_x - change in horizontal velocity
	muls	($t2, $a0, $t8)
	addu	$a2, $a2, $t2	#x updated
	
	#calculate change in v_y due to gravity and air drag
	muls	($t2, $t1, $a1)	#same as above
	divs	($t2, $t2, $t0)
	abs	$t2, $t2
	muls	($t2, $t2, $t8)	#t2 - v_y change due to air friction
	subu	$a1, $a1, $t2
	subu	$a1, $a1, $s5	#taking gravity into calculations
	muls	($t2, $a1, $t8)
	addu	$a3, $a3, $t2
	#calculations done, now we calculate position on the 1024x1024 bitmap
	srl	$t3, $a2, 16
	srl	$t4, $a3, 16
	bltz	$t3, dontwrite
	bgt	$t3, 1024, dontwrite
	blez	$t4, dontwrite
	bgt	$t4, 1024, dontwrite
	mulu	$t0, $t4, 1024
	subu	$t0, $t0, 1024
	addu	$t0, $t0, $t3
	remu	$t1, $t0, 8
	sra	$t0, $t0, 3
	lb	$s1, pxdata($t0)
	li	$t2, 0x80
	srlv	$t2, $t2, $t1
	or	$s1, $s1, $t2
	sb	$s1, pxdata($t0)
dontwrite:
	ble	$a3, $s4, bounceCheck
	j	beginStep
endSimulation:
	jr	$ra
