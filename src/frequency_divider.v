// These modules only work with even clock dividers!

module const_frequency_divider 
 #(parameter C_BITS = 8, C_N = 16, C_OFFSET = 0) (
    input wire i_clk,  // clock
    input wire i_rst,
    output reg o_clk = 0
  );

  reg [C_BITS-1:0] r_counter = (C_N / 2) - C_OFFSET;

  /* Sequential Logic */
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_counter <= (C_N >> 1) - 1;
      o_clk <= 0;
    end else begin
      
      if(r_counter == 1) begin
      
        r_counter <= (C_N / 2);
        o_clk <= ~o_clk;
      
      end else begin 
        r_counter <= r_counter - 1;
      end
    
    end
    
  end
    
  
  
endmodule

// Just in case we need to change the frequency, use this.
module var_frequency_divider #(parameter C_BITS = 8) (
    input wire i_clk,  // clock
    input wire i_rst,
    input wire [C_BITS-1:0] i_N,
    output reg o_clk = 0
  );

  reg [C_BITS-1:0] r_counter = 1;
  reg [C_BITS-1:0] last_N = 0;
  wire [C_BITS-2:0] r_div;
  
  assign r_div = (i_N >> 1);

  /* Sequential Logic */
  always @(posedge i_clk) begin
  
    last_N <= i_N;
    
    if((last_N != i_N) || i_rst) begin
      // This tick plus r_div - 1 = r_div!
      r_counter <= r_div - 1;
      o_clk <= 0;
    end else begin
      
      if(r_counter == 1) begin
        r_counter <= r_div;
        o_clk <= ~o_clk;
      
      end else begin 
        r_counter <= r_counter - 1;
      end
    
    end
    
    end
    
  
  
endmodule
