`timescale 1ns / 1ps
`default_nettype none


module pdm(
            input wire clk_in,
            input wire rst_in,
            input wire signed [7:0] level_in,
            input wire tick_in,
            output logic pdm_out
  );
  //your code here!
   logic signed [8:0] 	 history;
   logic signed [7:0] 	 threshold;
   logic signed [8:0] 	 sigma;

   
   assign threshold = (history[8] ? 8'b1000_0000 : 8'b0111_1111);
   assign pdm_out = threshold[0];

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 sigma <= 9'd0;
	 history <= 8'd0;
      end else if(tick_in) begin
	 history <= sigma;
	 sigma <= history + level_in - threshold;
	 
      end
   end
   
endmodule


`default_nettype wire
