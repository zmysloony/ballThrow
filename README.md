# ballThrow
Works perfectly under **MIPS** [simulator MARS](http://courses.missouristate.edu/KenVollmar/mars/). Draws the flight path of a ball thrown with given *time-zero* parameters, such as position and speed, while taking into account **air resistance**.

Detects collision with the floor and draws bounces with predefined energy loss. The result is written to *res.bmp* file, which in case of running it under MARS simulator, will be located in the same folder as MARS executable. You can modify gravity (and other) constants in the assembly file, although it might cause instability or erroneous results.

*BallThrow* doesn't use the floating-point MIPS co-processor for multiplication and division, because I've implemented a radix  point (decimal or more precisely binary point) *mul* and *sub* operations. I've had to cheat with the square root function and data input from keyboard, so it does sometimes use the floating-point co-processor.
