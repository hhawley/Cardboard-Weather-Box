// These modules only work with even clock dividers!

// Sends a single pulse of the width of the clk @ interval i_t
// Meant to be used with time sensitive items.
module const_time_interval 
#(parameter C_BITS = 8, C_F = 16, C_OFFSET = 0) (
    input i_clk,  // clock
    input i_rst,    // reset
    input i_en,
   
    output o_timer
  );
 
  reg r_state = 0;
  reg[C_BITS-1:0] r_pwn_counter = C_F - 1 - C_OFFSET;
  
  assign o_timer = r_state && i_en;
 
  always @(posedge i_clk) begin
      if(i_rst) begin
        r_pwn_counter <= C_F - 1;
        r_state <= 0;
      end else begin
        if(r_pwn_counter == 1) begin
        
          r_state <= ~r_state;
          r_pwn_counter <= r_state ? C_F - 1: 1;
        
        end else begin
          r_pwn_counter <= r_pwn_counter - 1;
        end
      end          
    
  end
  
  
endmodule

module var_time_interval #(parameter C_BITS = 8) (
    input i_clk,  // clock
    input i_rst,    // reset
    input i_en,
    
    input [C_BITS-1:0] i_f,     // 1/i_t
    output o_timer
  );

  
  reg r_state = 0;
  reg[C_BITS-1:0] r_pwn_counter = 1;
  reg[C_BITS-1:0] last_f = 0;
  
  assign o_timer = r_state && i_en;
 
  always @(posedge i_clk) begin
  
      last_f <= i_f;
  
      if((last_f != i_f) || i_rst) begin
        r_pwn_counter <= i_f - 1;
        r_state <= 0;
      end else begin
        if(r_pwn_counter == 1) begin
        
          r_state <= ~r_state;
          r_pwn_counter <= r_state ? i_f - 1: 1;
        
        end else begin
          r_pwn_counter <= r_pwn_counter - 1;
        end
      end          
    
  end
  
  
endmodule

