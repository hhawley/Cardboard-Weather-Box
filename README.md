This was a fun project that I started with the purpose of gaining some knowledge of Verilog, FPGAs, and APIs.

The board used is a [Mojo3](https://www.sparkfun.com/products/retired/11953) connected to a 16x2 LCD display.

Software requirements:
	* ISE 14.7
	* make
	* A copy of the (this Makefile)[https://github.com/duskwuff/Xilinx-ISE-Makefile]. Place it under the main directory.
	* Python w/ pyowm installed

The python script communicates with the board and updates the text displayed.