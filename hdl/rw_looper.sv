`timescale 1ns / 1ps


module rw_looper
  #(parameter MAX_ADDRESS = 2048)
  (
   input wire 		clk_in, // should be ui clk of DDR3!
   input wire 		rst_in,
   // MIG UI --> generic outputs
   output logic [26:0] 	app_addr,
   output logic [2:0] 	app_cmd,
   output logic 	app_en,
   // MIG UI --> write outputs
   output logic [127:0] app_wdf_data,
   output logic 	app_wdf_end,
   output logic 	app_wdf_wren,
   output logic [15:0] 	app_wdf_mask,
   // MIG UI --> read inputs
   input wire [127:0] 	app_rd_data,
   input wire 		app_rd_data_end,
   input wire 		app_rd_data_valid,
   // MIG UI --> generic inputs
   input wire 		app_rdy,
   input wire 		app_wdf_rdy,
   // MIG UI --> misc
   output logic 	app_sr_req, // ??
   output logic 	app_ref_req,// ??
   output logic 	app_zq_req, // ??
   input wire 		app_sr_active,
   input wire 		app_ref_ack,
   input wire 		app_zq_ack,
   input wire 		init_calib_complete,
   // Write AXIS FIFO input
   input wire [127:0] 	write_axis_data,
   input wire 		write_axis_tuser,
   input wire 		write_axis_valid,
   // no smallpile
   output logic 	write_axis_ready,
   // Read AXIS FIFO output
   output logic [127:0] read_axis_data,
   output logic 	read_axis_tuser,
   output logic 	read_axis_valid,
   // no almost_empty
   input wire 		read_axis_ready
   );

   localparam CMD_WRITE = 3'b000;
   localparam CMD_READ = 3'b001;

   // unused signals
   assign app_sr_req = 0;
   assign app_ref_req = 0;
   assign app_zq_req = 0;
   assign app_wdf_mask = 16'b0;

   typedef enum {RST,           // X000 / 0,8
		 WAIT_INIT,     // X001 / 1,9
		 ISSUE_RD,
		 RD_RESPONSE,
		 ISSUE_WR
		 } tg_state;
   tg_state state;

   logic 	issue_rd_cmd, issue_wr_cmd;

   assign issue_rd_cmd = read_axis_ready && (state == ISSUE_RD) && app_rdy;
   assign write_axis_ready = app_rdy && app_wdf_rdy && (state == ISSUE_WR);
   assign issue_wr_cmd = write_axis_ready && write_axis_valid;
   
   logic [26:0] wr_addr;
   logic 	rollover_wr_addr;
   
   addr_increment #(.ROLLOVER(MAX_ADDRESS)) aiwa
     (.clk_in(clk_in),
      .rst_in(rst_in),
      // calib_in ?
      .incr_in( issue_wr_cmd ),
      .addr_out( wr_addr ),
      .rollover_out( rollover_wr_addr ));

   logic [26:0] rd_addr;
   logic 	rollover_rd_addr;

   addr_increment #(.ROLLOVER(MAX_ADDRESS)) aira
     (.clk_in(clk_in),
      .rst_in(rst_in),
      // calib_in ?
      .incr_in( app_rd_data_valid ),
      .addr_out( rd_addr ),
      .rollover_out( rollover_rd_addr ));

   assign read_axis_valid = app_rd_data_valid;
   assign read_axis_data = app_rd_data;
   // read_axis_tuser?

   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 state <= RST;
      end else begin
	 case(state)
	   RST: begin
	     state <= WAIT_INIT;
	   end
	   WAIT_INIT: begin
	      state <= init_calib_complete ? ISSUE_RD : WAIT_INIT;
	   end
	   ISSUE_RD: begin
	      state <= app_rdy ? (issue_rd_cmd ? RD_RESPONSE : ISSUE_WR) : ISSUE_RD;
	   end
	   RD_RESPONSE: begin
	      state <= app_rd_data_valid ? ISSUE_WR : RD_RESPONSE;
	   end
	   ISSUE_WR: begin
	      state <= (app_rdy && app_wdf_rdy) ? ISSUE_RD : ISSUE_WR;
	   end
	 endcase // case (state)
      end
   end // always_ff @ (posedge clk_in)

   always_comb begin
      case(state)
	RST, WAIT_INIT, RD_RESPONSE: begin
	   app_addr = 0;
	   app_cmd = 0;
	   app_en = 0;
	   app_wdf_data = 0;
	   app_wdf_end = 0;
	   app_wdf_wren = 0;
	end
	ISSUE_WR: begin
	   app_addr = wr_addr << 7;
	   app_cmd = CMD_WRITE;
	   app_en = issue_wr_cmd;
	   app_wdf_wren = issue_wr_cmd;
	   app_wdf_data = write_axis_data;
	   app_wdf_end = issue_wr_cmd;
	end
	ISSUE_RD: begin
	   app_addr = rd_addr << 7;
	   app_cmd = CMD_READ;
	   app_en = issue_rd_cmd;
	   app_wdf_wren = 0;
	   app_wdf_data = 0;
	   app_wdf_end = 0;
	end
      endcase // case (state)
   end // always_comb

endmodule
