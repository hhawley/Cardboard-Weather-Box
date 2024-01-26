// Driver based on
// https://eater.net/datasheets/HD44780.pdf

module lcd_driver (
		// Global parameters
		input wire i_clk,				// global clock
		input wire i_rst,				// global reset

		// Driver connections
		input  wire [7:0] i_data_in,	// Data value from the RAM
		output reg [9:0] o_addr_out,	// Address to read from RAM
		output wire o_ready,			// Dictates if its ready to display
		input wire i_standby,			// If enabled, goes to standby.

		// Physical wire connections
		output reg o_rst = 0,					// LCD reset
		output reg o_rw = 0,					// LCD read/write
		output wire o_en,						// LDC en, active low
		output reg[7:0] o_lcd_d = 8'b00000000	// LDC Bus
	);
	
// LCD Driver Machine States
localparam c_INIT        = 4'b0000;
localparam c_INIT_WRITE  = 4'b0001;
localparam c_STANDBY     = 4'b0010;
localparam c_WAIT        = 4'b0011;
localparam c_READ		 = 4'b0100;
reg [3:0] r_state = c_INIT;
// At power up, we start at FUNC_SET, at restart, at CLEAR_SET
reg [3:0] r_prog_counter = 4'b1111;

// LCD commands. Requires RS to be OFF
localparam LINE_SET    = 8'b11000000;  // Sets to start of second line
localparam FUNC_SET    = 8'b00111000;  // 8 bit mode, 2 line display mode, 5x8 display font
localparam CURSOR_SET  = 8'b00011100;  // Shift display to the right. Cursor follows the display shift.
localparam DISPLAY_SET = 8'b00001110;  // Display on; curson on; blink off
localparam ENTRY_SET   = 8'b00000110;  // Increments display at write, no display shift
localparam HOME_SET    = 8'b00000010;  // Returns home
localparam CLEAR_SET   = 8'b00000001;  // Clears screen

// Write params
localparam SIZE_BUFFER = 16;

// So the text corresponds to the things read from memory
// Index 0 -> u (right most char)
reg [(8*SIZE_BUFFER-1):0] r_buffer = "Hello world, uwu";

// Line Regs
reg [7:0] r_curr_pos = 0;

// Which line we are at
wire w_curr_line;
assign w_curr_line = r_curr_pos[6];


/// * TIMER REGION * ///
/// Makes the driver wait for each command.
localparam C_CLK_FREQ = 50000000;
localparam C_LCD_FREQ = C_CLK_FREQ;
localparam C_TIMER_LENGTH = 28;
	
// Be careful with the freq from last
// All other commands require 37+4us min, but it def changes
// depending if 1 line of 2 line. 200us work if 2 line, 60us if 1 line
localparam C_INT_37US = C_LCD_FREQ*200e-6;    
// Return home requires more than 4.1ms min, see page 45
localparam C_INT_1MS52 = C_LCD_FREQ*5e-3; 
localparam C_INT_5S = C_LCD_FREQ*5;
localparam C_INT_1S = C_LCD_FREQ*1;
localparam C_REFRESH_RATE = C_LCD_FREQ*40e-3;
	
reg [C_TIMER_LENGTH-1:0] r_timer_freq = C_INT_1S;
wire w_timer_en, w_code_en;
	
// These freq divider and timer are to allow the LCD to finish with its command
// or misc wait times!
wire r_toggle;
var_frequency_divider #(C_TIMER_LENGTH) m_fq (i_clk, i_rst, r_timer_freq, r_toggle);
var_time_interval     #(C_TIMER_LENGTH) m_ti (i_clk, i_rst, 1, r_timer_freq, w_code_en);
	
// ASSIGN PART
// Shows when the state is in standby.
assign o_ready = (r_state == c_READ) ;
// Enabled unless we are in the standby mode.
assign o_en = ~r_toggle;

always @(posedge i_clk) begin
	
	// Always low
	o_rw <= 0;
  
	if (i_rst) begin

		o_rst <= 0;
		o_lcd_d <= 8'b00000000;
			
		r_state <= c_INIT;
		r_prog_counter <= 4'b1111;
		r_timer_freq <= C_INT_1S;
		r_curr_pos <= 0;
	
	end else begin

		if(w_code_en) begin
			case (r_state)
			
			// Inits the display
			c_INIT : begin
					
				o_rst <= 0;
				o_addr_out <= 0;
							
				case (r_prog_counter)
					4'b1111: begin
						o_lcd_d <= CLEAR_SET;
						// Clear set needs 1.52 ms
						r_timer_freq <= C_INT_1MS52;
					end 4'b1110: begin
						o_lcd_d <= FUNC_SET;
						// From now on we can stick with 37us
						r_timer_freq <= C_INT_37US;
					end 4'b1101: begin
						o_lcd_d <= DISPLAY_SET;
						r_timer_freq <= C_INT_37US;
					end 4'b1100: begin
						o_lcd_d <= ENTRY_SET;
						r_timer_freq <= C_INT_37US;
					end default: begin
						o_lcd_d <= 0;
						r_timer_freq <= C_INT_37US;
					end
				endcase	
					
				if (r_prog_counter == 4'b1100) begin
					r_state <= c_INIT_WRITE;
					r_prog_counter <= 4'b1111;
				end else begin
					r_prog_counter <= r_prog_counter - 1;
				end
		  
				// Writes welcome screen
			end c_INIT_WRITE : begin
				
				o_rst <= 1;
				o_addr_out <= 0;
				o_lcd_d <= r_buffer[r_prog_counter*8+: 8];
				r_timer_freq <= C_INT_37US;
				r_curr_pos <= r_curr_pos + 1;
					
				if (r_prog_counter == 0) begin
					r_prog_counter <= 4'b1111;
					r_state <= c_WAIT;
					
				end else begin

					r_prog_counter <= r_prog_counter - 1;

				end
					
			// Just waits 1 seconds, show welcome screen, be nice, and then clear screen
			end c_WAIT : begin

				r_curr_pos <= 8'b00000000;
				o_rst <= 0;
				o_addr_out <= 0;

		  		if(r_prog_counter ==  4'b1111) begin
		  			o_lcd_d <= 0;
		  			r_timer_freq <= C_INT_1S;
		  			r_prog_counter <= 4'b1110;
		  		end else begin
		  			// Reset counter, clear screen, wait the req time and change state
		  			r_prog_counter <= 4'b1111;
		  			o_lcd_d <= CLEAR_SET;
		  			r_timer_freq <= C_INT_1MS52;
		  			r_state <= i_standby ? c_STANDBY : c_READ;
		  		end
		  
		  	end c_STANDBY: begin
			
				// Just wait 5 second and do nothing
		  		o_rst <= 0;
		  		o_lcd_d <= 0;
		  		r_timer_freq <= C_INT_5S;
		  		o_addr_out <= 0;

				// if(r_curr_pos == 8'b01010000) begin
				// 	o_lcd_d <= LINE_SET;
				// 	o_rst <= 0;
				// 	r_timer_freq <= C_INT_37US;
				// 	r_curr_pos <= 8'b01000000;
				// end else begin
				
				// 	o_lcd_d <= r_xmax_buffer[(r_prog_counter)*8+: 8];
				// 	o_rst <= 1;
				// 	r_timer_freq <= C_INT_1S;
				// 	r_curr_pos <= r_curr_pos + 1;
				  
				// 	if (r_prog_counter == 0) begin
								
				// 		r_prog_counter <= 4'b1111;
								
				// 	end else begin
				   
				// 		r_prog_counter <= r_prog_counter - 1;
					
				// 	end
				// end
						
			end c_READ: begin

				case (r_prog_counter)
					// On first tick of the counter, we write addr to read memory
					// and wait ~200us
					4'b1111: begin
						o_rst <= 0;
						o_lcd_d <= 0;
						r_timer_freq <= C_INT_37US;
						o_addr_out <= {2'b00, r_curr_pos};

					// Then we read the value, wait ~200us again
					end 4'b1110: begin
						o_rst <= 1;
						o_lcd_d <= i_data_in;
						r_timer_freq <= C_INT_37US;

					// We then increase the counter, if counter max, we go home.
					end 4'b1101: begin
						o_rst <= 0;
						if(r_curr_pos == 31) begin

							o_lcd_d <= HOME_SET;
							r_curr_pos <= 0;
							r_timer_freq <= C_REFRESH_RATE;

						end else if(r_curr_pos == 15) begin

							o_lcd_d <= LINE_SET;
							r_curr_pos <= r_curr_pos + 1;
							r_timer_freq <= C_INT_37US;

						end else begin

							o_lcd_d <= 0;
							r_curr_pos <= r_curr_pos + 1;
							r_timer_freq <= C_INT_37US;

						end

					end default: begin
						o_rst <= 0;
						o_lcd_d <= 0;
						r_timer_freq <= C_INT_37US;
					end
				endcase	

				if (r_prog_counter == 4'b1101) begin

					r_prog_counter <= 4'b1111;
					
				end else begin

					r_prog_counter <= r_prog_counter - 1;

				end

			end
			
			endcase 
		
		end
  
	end
end

endmodule