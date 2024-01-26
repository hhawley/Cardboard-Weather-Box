module main (
	// 50MHz clock input
	input clk,
	// Input from reset button (active low)
	input rst_n,
	// cclk input from AVR, high when AVR is ready
	input cclk,
	// Outputs to the 8 onboard LEDs
	output[7:0]led,
	// AVR SPI connections
	output spi_miso,
	input spi_ss,
	input spi_mosi,
	input spi_sck,
	// AVR ADC channel select
	output [3:0] spi_channel,
	// Serial connections
	input avr_tx, // AVR Tx => FPGA Rx
	output avr_rx, // AVR Rx => FPGA Tx
	input avr_rx_busy, // AVR Rx buffer full
	
	output LCD_RS,
	output LCD_RW,
	output LCD_EN,
	output[7:0] LCD_D
	);

wire rst;
wire w_half_sec_sq;
wire pwm_clk;

// these signals should be high-z when not used
assign spi_miso = 1'bz;
assign spi_channel = 4'bzzzz;

// On the mojo v3 we need to wait until 
// cclk has been on for at least 512 cycles.
localparam WAIT_COUNT = 512;
reg[9:0] r_cclk = 10'b1000000000;
wire cclk_ready;
assign cclk_ready = (r_cclk == 0);
always @(posedge clk) begin
	if(r_cclk != 0) begin
		r_cclk <= r_cclk - 1;
	end else begin
		r_cclk <= 0;
	end 
end

// Allows AVR_RX on only when cclk has been on for at least 512 cycles.
wire w_avr_rx;
assign avr_rx = cclk_ready ? w_avr_rx : 1'bz;

// Debouncer for the reset button
debouncer inst_rst_debouncer(clk, rst_n, rst);

// A half a second clock. I just like to see the LED flash.
const_frequency_divider #(32, 25000000) inst_divider(clk, rst, w_half_sec_sq);

// LCD Module
wire w_lcd_en, w_not_lcd_en;
wire [9:0] w_lcd_addr_out;
wire [7:0] w_lcd_data_in;

lcd_driver inst_lcd_driver
	(
		.i_clk      (clk),
		.i_rst      (rst),
		.i_data_in  ( w_lcd_data_in ),
		.o_addr_out ( w_lcd_addr_out ),
		.o_ready    ( w_lcd_en ),
		.i_standby  (0),
		.o_rst      (LCD_RS),
		.o_rw       (LCD_RW),
		.o_en       (LCD_EN),
		.o_lcd_d    (LCD_D)
	);

// LED / PWM Modules
//var_pwm_module pwm_01(clk, rst, r_duty_cycle, led[0]);
//var_pwm_module pwm_02(clk, w_half_sec_sq, r_duty_cycle, led[1]);
//var_pwm_module pwm_03(clk, w_lcd_en, r_duty_cycle, led[2]);
//var_pwm_module pwm_04(clk, 1, r_duty_cycle, led[3]);

reg[7:0] r_duty_cycle = 8'b00100000;
reg [7:0] duty_cycle_low = 8'b00010000;
wire w_flashy;
wire [7:0] led0, led1, led2, led3, led4, led5, led6, led7;
const_frequency_divider #(32, 10000000) inst_divider_01(clk, 0, w_flashy);

assign led0 = r_duty_cycle % 8'b00100000;
var_pwm_module pwm_00(clk, 1, led0, led[0]);

assign led1 = (r_duty_cycle - 5) % 8'b00100000 ;
var_pwm_module pwm_01(clk, 1, led1, led[1]);

assign led2 = (r_duty_cycle - 10) % 8'b00100000 ;
var_pwm_module pwm_02(clk, 1, led2, led[2]);

assign led3 = (r_duty_cycle - 15) % 8'b00100000 ;
var_pwm_module pwm_03(clk, 1, led3, led[3]);

assign led4 = (r_duty_cycle - 20) % 8'b00100000 ;
var_pwm_module pwm_04(clk, 1, led4, led[4]);

assign led5 = (r_duty_cycle - 25) % 8'b00100000 ;
var_pwm_module pwm_05(clk, 1, led5, led[5]);

assign led[6] = 0;

var_pwm_module pwm_07(clk, w_half_sec_sq, duty_cycle_low, led[7]);

always @(posedge w_flashy) begin
	if(r_duty_cycle == 0) begin
		r_duty_cycle <= 8'b00100000;
	end else begin
		r_duty_cycle <= r_duty_cycle - 1;
	end
end

wire [15:0] w_addrb;
wire [7:0] w_dina, w_dinb,  w_douta;
wire w_uart_write_en;

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
dual_bram inst_dual_bram
	(
		.clka  ( clk ),
		.rsta  ( rst ),
		.ena   ( w_lcd_en ),
		.wea   ( 1'b0 ),
		.addra ( w_lcd_addr_out ),
		.dina  ( ),
		.douta ( w_lcd_data_in ),
		.clkb  ( clk ),
		.enb   ( 1'b1 ),
		.web   ( w_uart_write_en ),
		.addrb ( w_addrb[9:0] ),
		.dinb  ( w_dinb ),
		.doutb ( )
	);
// INST_TAG_END ------ End INSTANTIATION Template ---------


// UART

uart2bus_top inst_uart2bus_top
    (
        .clock       ( clk ),
        .reset       ( rst ),
        .ser_in      ( avr_tx ),
        .ser_out     ( w_avr_rx ),
        .int_address ( w_addrb ),
        .int_wr_data ( w_dinb ),
        .int_write   ( w_uart_write_en ),
        .int_rd_data ( 8'h42 ),
        .int_read    ( ),
        .int_req     ( ),
        .int_gnt     ( 1 )
    );


endmodule