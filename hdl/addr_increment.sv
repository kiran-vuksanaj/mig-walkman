`timescale 1ns / 1ps
`default_nettype none

module addr_increment
  #(parameter ROLLOVER = 128,
    parameter RST_ADDR = 0,
    parameter INCR_AMT = 1
    )
   (
    input wire 				clk_in,
    input wire 				rst_in,
    input wire 				calib_in,
    input wire 				incr_in,
    output logic [$clog2(ROLLOVER)-1:0] addr_out,
    output logic 			rollover_out
    );

   // for each cycle that incr_in is high, increment address register--never reach rollover, turn it back to 0.
   // ON THE CYCLE THAT calib_in is cycled,
   // (so it probably needs to be a little combinational)
   
   logic [$clog2(ROLLOVER):0] 		next_addr; // deliberately include extra bit!

   assign addr_out = calib_in ? RST_ADDR : next_addr;

   always @(posedge clk_in) begin
      if (rst_in) begin
	 next_addr <= RST_ADDR;
	 rollover_out <= 0;
      end else if (calib_in) begin
	 next_addr <= RST_ADDR + INCR_AMT;
	 rollover_out <= 0;
      end else if (incr_in) begin
	 next_addr <= (next_addr+INCR_AMT >= ROLLOVER) ? RST_ADDR : next_addr+INCR_AMT;
	 rollover_out <= next_addr+INCR_AMT >= ROLLOVER || next_addr+INCR_AMT==0;
      end else begin
	 rollover_out <= 0;
      end
   end
endmodule // addr_increment

`default_nettype wire
