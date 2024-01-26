module debouncer (
    input wire i_clk,  // clock
    input wire i_rst,  // reset, ACTIVE HIGH
    output wire o_rst
  );

  reg r_last_rst = 1;
  reg r_rst = 1;
  reg rst_en = 0;
  reg [15:0] r_debouncer_counter = 65535;
  assign o_rst = rst_en;
  
  /* Sequential Logic */
  always @( posedge i_clk ) begin
    
    r_rst <= i_rst; 
    r_last_rst <= r_rst;
    
    // If r_last_rst changed
    if(r_last_rst == 1 && r_rst == 0) begin
    
      rst_en <= 1;
    
    end
    
    if(rst_en) begin
    
      if ( r_debouncer_counter == 0) begin
        r_debouncer_counter <= 65535;
        rst_en <= 0;
      end else begin
        r_debouncer_counter <= r_debouncer_counter - 1;
      end
    
    end
    
  end
  
endmodule
