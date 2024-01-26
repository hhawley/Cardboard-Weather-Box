// My own PWM modules.

// Constant duty cycle. No reset
module constant_pwm_module 
#(parameter C_RES = 8, C_DUTY_CYCLE=2**(C_RES-2))
(

		input i_clk,  // clock
		input i_en,
		output wire o_clk
		
	);
	
	localparam C_MIN_DUTY_CYCLE = ~C_DUTY_CYCLE;
	
	reg r_state = 0;
	reg[C_RES-1:0] r_pwn_counter = 1;
	
	assign o_clk = r_state && i_en;

	always @(posedge i_clk) begin

		if(r_pwn_counter == 1) begin
		
			r_state <= ~r_state;
			r_pwn_counter <= r_state ? C_MIN_DUTY_CYCLE : C_DUTY_CYCLE;
		
		end else begin
			r_pwn_counter <= r_pwn_counter - 1;
		end          
		
	end
	
endmodule

// Used if duty cycle can change at run time.
module var_pwm_module 
#(parameter C_RES = 8)(

		input i_clk,  // clock
		input i_en,
		input [C_RES-1:0] i_duty_cycle,

		output wire o_clk

	);
	
	// A duty cycle of 0 is not allowed.
	wire [C_RES-1:0] w_duty_cycle;
	assign w_duty_cycle = i_duty_cycle == 0 ? 1 : i_duty_cycle;
	
	// Binary complementary of the duty cycle
	// 1- DUTY_CYCLE
	wire [C_RES-1:0] w_comp_duty_cycle;
	assign w_comp_duty_cycle = ~w_duty_cycle;
	
	reg r_state = 0;
	reg[C_RES-1:0] r_pwn_counter = 1;
	reg[C_RES-1:0] r_last_duty_cycle = 1;
	
	assign o_clk = r_state && i_en;

	always @(posedge i_clk) begin    
	
		r_last_duty_cycle <= w_duty_cycle;
		
		if(r_last_duty_cycle != w_duty_cycle) begin

			// The extra minus one is required to account for the
			// clock tick used by the reset.
			r_pwn_counter <= w_comp_duty_cycle - 1;
			r_state <= 0;

		end else begin

			if(r_pwn_counter == 1) begin
			
				r_state <= ~r_state;
				r_pwn_counter <= r_state ? w_comp_duty_cycle : w_duty_cycle;
			
			end else begin
				r_pwn_counter <= r_pwn_counter - 1;
			end

		end     
		
	end
	
endmodule

