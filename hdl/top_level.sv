`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire 	       clk_100mhz,
   input wire 	       uart_rxd,
   input wire [3:0]    btn,
   input wire [15:0]   sw,
   // output logic        uart_txd,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   output logic [3:0]  ss0_an,
   output logic [3:0]  ss1_an,
   output logic [6:0]  ss0_c,
   output logic [6:0]  ss1_c,
   output logic [15:0] led,
   output logic [7:0]  pmoda,
   output logic spkl, spkr,
   // DDR3 ports
   inout wire [15:0]   ddr3_dq,
   inout wire [1:0]    ddr3_dqs_n,
   inout wire [1:0]    ddr3_dqs_p,
   output wire [12:0]  ddr3_addr,
   output wire [2:0]   ddr3_ba,
   output wire 	       ddr3_ras_n,
   output wire 	       ddr3_cas_n,
   output wire 	       ddr3_we_n,
   output wire 	       ddr3_reset_n,
   output wire 	       ddr3_ck_p,
   output wire 	       ddr3_ck_n,
   output wire 	       ddr3_cke,
   output wire [1:0]   ddr3_dm,
   output wire 	       ddr3_odt
   );
   localparam CLOCK_SPEED = 100_000_000;
   
   localparam SAMPLE_RATE = 12_000;
   localparam STORAGE_SECONDS = 5;
   localparam AUDIO_BRAM_DEPTH = SAMPLE_RATE*STORAGE_SECONDS;
   localparam AUDIO_BRAM_ADDR = $clog2(AUDIO_BRAM_DEPTH);
   
   localparam BAUD = 57600;
   

   logic 	       sys_rst;
   assign sys_rst = btn[0];
   
   logic 	       sys_clk;
   logic 	       clk_migref;
   
   clk_wiz_mig_clk_wiz clocking_wizard
     (.clk_in1(clk_100mhz),
      .clk_default(sys_clk),
      .clk_mig(clk_migref), // 200MHz
      .reset(0));

   assign rgb1 = 0;
   assign rgb0 = 0;

   logic [7:0] 	       data_uart;
   logic 	       uart_valid;

   logic [15:0]        count_valids;

   logic [2:0] 	       ustate;

   // CHAPTER: MIG INITIALIZATION

   // mig module
   // user interface signals
   logic [26:0]        app_addr;
   logic [2:0] 	       app_cmd;
   logic 	       app_en;
   logic [127:0]       app_wdf_data;
   logic 	       app_wdf_end;
   logic 	       app_wdf_wren;
   logic [127:0]       app_rd_data;
   logic 	       app_rd_data_end;
   logic 	       app_rd_data_valid;
   logic 	       app_rdy;
   logic 	       app_wdf_rdy;
   logic 	       app_sr_req;
   logic 	       app_ref_req;
   logic 	       app_zq_req;
   logic 	       app_sr_active;
   logic 	       app_ref_ack;
   logic 	       app_zq_ack;
   logic 	       ui_clk; // ** CLOCK FOR MIG INTERACTIONS!! **
   logic 	       ui_clk_sync_rst;
   logic [15:0]        app_wdf_mask;
   logic 	       init_calib_complete;
   logic [11:0]        device_temp;

   logic 	       sys_rst_ui;
   assign sys_rst_ui = ui_clk_sync_rst;

   ddr3_mig ddr3_mig_inst 
     (
      .ddr3_dq(ddr3_dq),
      .ddr3_dqs_n(ddr3_dqs_n),
      .ddr3_dqs_p(ddr3_dqs_p),
      .ddr3_addr(ddr3_addr),
      .ddr3_ba(ddr3_ba),
      .ddr3_ras_n(ddr3_ras_n),
      .ddr3_cas_n(ddr3_cas_n),
      .ddr3_we_n(ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p(ddr3_ck_p),
      .ddr3_ck_n(ddr3_ck_n),
      .ddr3_cke(ddr3_cke),
      .ddr3_dm(ddr3_dm),
      .ddr3_odt(ddr3_odt),
      .sys_clk_i(clk_migref),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_wdf_data(app_wdf_data),
      .app_wdf_end(app_wdf_end),
      .app_wdf_wren(app_wdf_wren),
      .app_rd_data(app_rd_data),
      .app_rd_data_end(app_rd_data_end),
      .app_rd_data_valid(app_rd_data_valid),
      .app_rdy(app_rdy),
      .app_wdf_rdy(app_wdf_rdy), 
      .app_sr_req(app_sr_req),
      .app_ref_req(app_ref_req),
      .app_zq_req(app_zq_req),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),
      .ui_clk(ui_clk), 
      .ui_clk_sync_rst(ui_clk_sync_rst),
      .app_wdf_mask(app_wdf_mask),
      .init_calib_complete(init_calib_complete),
      .device_temp(device_temp),
      .sys_rst(!sys_rst) // active low
      );
   
   

   // CHAPTER: UART RECEIVER + WAV FILE PARSER

   logic 	       uart_rxd_buf0;
   logic 	       uart_rxd_buf1;

   always_ff @(posedge sys_clk) begin
      uart_rxd_buf0 <= uart_rxd;
      uart_rxd_buf1 <= uart_rxd_buf0;
   end
   
   uart_rcv
     #(.BAUD_RATE(BAUD),
       .CLOCK_SPEED(100_000_000))
   urm
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .uart_rx(uart_rxd_buf1),
      .valid_out(uart_valid),
      .data_out(data_uart),
      .ustate(ustate));

   logic [7:0] 	       sample_write;
   logic 	       sample_write_valid;

   logic 	       chunk_named_data;
   logic [2:0] 	       wstate;
   logic [31:0]        chunk_name_debug;
   logic [31:0]        remaining_length;
      
   parse_wav wavfile_parser
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .wavbyte_in(data_uart),
      .wavbyte_valid_in(uart_valid),
      .sample_out(sample_write),
      .sample_valid_out(sample_write_valid),
      .chunk_named_data_debug(chunk_named_data),
      .wstate(wstate),
      .chunk_name_debug(chunk_name_debug),
      .remaining_length_debug(remaining_length));
   
   // CHAPTER: MIG INTERACTION

   logic [127:0]       phrase_axis;
   logic 	       phrase_ready;
   logic 	       phrase_valid;
   logic 	       phrase_tuser;
   
   build_wr_data
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .valid_in(sample_write_valid),
      .ready_in(),
      .data_in(sample_write),
      .newframe_in(),
      .valid_out(phrase_valid),
      .ready_out(phrase_ready),
      .data_out(phrase_axis),
      .tuser_out(phrase_tuser));


   logic 	       write_axis_valid;
   logic 	       write_axis_ready;
   logic [127:0]       write_axis_phrase;
   logic 	       write_axis_tuser;

   logic 	       small_pile;
   
   ddr_fifo sample_write_fifo
     (.s_axis_aresetn(~sys_rst),
      .s_axis_aclk(sys_clk),
      .s_axis_tvalid(phrase_valid),
      .s_axis_tready(phrase_ready),
      .s_axis_tdata(phrase_axis),
      .s_axis_tuser(phrase_tuser),
      .m_axis_aclk(ui_clk),
      .m_axis_tvalid(write_axis_valid),
      .m_axis_tready(write_axis_ready), // ready will spit you data! use in proper state
      .m_axis_tdata(write_axis_phrase),
      .m_axis_tuser(write_axis_tuser),
      .prog_empty(small_pile));

   logic [127:0] read_axis_data;
   logic 	 read_axis_valid;
   logic 	 read_axis_af;
   logic 	 read_axis_ready;
   logic 	 read_axis_tuser;

   logic [2:0] 	 tg_state;

   traffic_generator tg
     (.clk_in(ui_clk),
      .rst_in(sys_rst_ui),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_wdf_data(app_wdf_data),
      .app_wdf_end(app_wdf_end),
      .app_wdf_wren(app_wdf_wren),
      .app_wdf_mask(app_wdf_mask),
      .app_rd_data(app_rd_data),
      .app_rd_data_valid(app_rd_data_valid),
      .app_rdy(app_rdy),
      .app_wdf_rdy(app_wdf_rdy),
      .app_sr_req(app_sr_req),
      .app_ref_req(app_ref_req),
      .app_zq_req(app_zq_req),
      .app_sr_active(app_sr_active),
      .app_ref_ack(app_ref_ack),
      .app_zq_ack(app_zq_ack),
      .init_calib_complete(init_calib_complete),
      .write_axis_data(write_axis_phrase),
      .write_axis_valid(write_axis_valid),
      .write_axis_ready(write_axis_ready),
      .write_axis_smallpile(small_pile),
      .write_axis_tuser(write_axis_tuser),
      .read_axis_data(read_axis_data),
      .read_axis_valid(read_axis_valid),
      .read_axis_af(read_axis_af),
      .read_axis_ready(read_axis_ready),
      .read_axis_tuser(read_axis_tuser),
      .state_out(tg_state)
      );

   logic 	 outphrase_axis_valid;
   logic 	 outphrase_axis_ready;
   logic [127:0] outphrase_axis_data;
   logic 	 outphrase_axis_tuser;

   ddr_fifo playback_read
     (.s_axis_aresetn(~sys_rst_ui),
      .s_axis_aclk(ui_clk),
      .s_axis_tvalid(read_axis_valid),
      .s_axis_tready(read_axis_ready),
      .s_axis_tdata(read_axis_data),
      .s_axis_tuser(read_axis_tuser),
      .prog_full(read_axis_af),
      .m_axis_aclk(sys_clk),
      .m_axis_tvalid(outphrase_axis_valid),
      .m_axis_tready(outphrase_axis_ready),
      .m_axis_tdata(outphrase_axis_data),
      .m_axis_tuser(outphrase_axis_tuser));

   logic [7:0] 	 playback_sample;
   logic 	 playback_sample_ready;
   logic 	 playback_sample_valid;
   logic 	 playback_sample_rollover;

   digest_phrase
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .valid_phrase(outphrase_axis_valid),
      .ready_phrase(outphrase_axis_ready),
      .phrase_data(outphrase_axis_data),
      .phrase_tuser(outphrase_axis_tuser),
      .valid_word(playback_sample_valid),
      .ready_word(playback_sample_ready),
      .newframe_out(playback_sample_rollover),
      .word(playback_sample));
   
   logic 	 read_addr_incr;
   localparam SAMPLE_PERIOD = 100_000_000 / 12_000;
   addr_increment
     #(.ROLLOVER(SAMPLE_PERIOD))
   aim_r0
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .calib_in(btn[1]),
      .incr_in(1'b1),
      .rollover_out(read_addr_incr));

   assign playback_sample_ready = read_addr_incr;

   // CHAPTER: BRAM INTERACTION

   // logic [AUDIO_BRAM_ADDR-1:0] write_addr;
   // addr_increment
   //   #(.ROLLOVER(SAMPLE_RATE*STORAGE_SECONDS)) 
   // aim0
   //   (.clk_in(sys_clk),
   //    .rst_in(sys_rst),
   //    .calib_in(btn[1]),
   //    .incr_in(sample_write_valid),
   //    .addr_out(write_addr));

   
   // logic [31:0] 	       read_addr;

   // logic 		       read_addr_incr;
   // localparam SAMPLE_PERIOD = 100_000_000 / 12_000;
   // addr_increment
   //   #(.ROLLOVER(SAMPLE_PERIOD))
   // aim_r0
   //   (.clk_in(sys_clk),
   //    .rst_in(sys_rst),
   //    .calib_in(btn[1]),
   //    .incr_in(1'b1),
   //    .rollover_out(read_addr_incr));

   // addr_increment
   //   #(.ROLLOVER(12_000*5))
   // aim1
   //   (.clk_in(sys_clk),
   //    .rst_in(sys_rst),
   //    .calib_in(btn[1]),
   //    .incr_in(read_addr_incr),
   //    .addr_out(read_addr));
   
   // // assign read_addr = sw[15:0];
   // logic signed [7:0] read_value;

		
   // xilinx_true_dual_port_read_first_2_clock_ram
   //   #(.RAM_WIDTH(8),
   //     .RAM_DEPTH(12_000*5)) // five seconds of 12ksps audio
   // audio_bram
   //   (.addra(write_addr),
   //    .clka(sys_clk),
   //    .wea(sample_write_valid),
   //    .dina(sample_write),
   //    .ena(1'b1),
   //    .regcea(1'b1),
   //    .rsta(sys_rst),
   //    .douta(),
   //    .addrb(read_addr),
   //    .clkb(sys_clk),
   //    .web(1'b0),
   //    .dinb(),
   //    .enb(1'b1),
   //    .regceb(1'b1),
   //    .rstb(sys_rst),
   //    .doutb(read_value)
   //    );


   // CHAPTER : PWM OUTPUT
   
   logic 		       out_signal;

   logic 		       pwm_valid;
   logic [1:0] 		       pwm_period;
   always_ff @(posedge sys_clk) begin
      if( sys_rst ) begin
	 pwm_period <= 0;
      end else begin
	 pwm_period <= pwm_period + 1;
      end
   end
   assign pwm_valid = (pwm_period == 0);


   logic [7:0] pwm_value = {~playback_sample[7],playback_sample[6:0]};
   
   pwm mpwm
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .level_in(pwm_value),
      .tick_in(pwm_valid),
      .pwm_out(out_signal)
      );
   
   assign spkl = out_signal;
   assign spkr = out_signal;

   logic [7:0] count_samples;
   
   always_ff @(posedge sys_clk) begin
      if (sys_rst) begin
	 count_valids <= 0;
	 count_samples <= 0;
      end
      else begin
	 count_valids <= count_valids + uart_valid;
	 count_samples <= count_samples + (outphrase_axis_valid && outphrase_axis_ready);
      end
   end


   logic [31:0] 	       val_to_display;
   // assign val_to_display = {read_addr,data_uart,read_value};
   assign val_to_display = btn[3] ? chunk_name_debug : (btn[2] ? {24'b0, data_uart} : remaining_length);
   // assign val_to_display = btn[3] ? (btn[2] ? read_axis_data[31:0] : app_rd_data[31:0]) : (btn[2] ? write_axis_phrase[31:0] : app_wdf_data[31:0]);
   // assign val_to_display = {playback_sample,outphrase_axis_data[7:0],sample_write,phrase_axis[7:0]};

   logic [6:0] 		       ss_c;
   assign ss0_c = ss_c;
   assign ss1_c = ss_c;
   
   seven_segment_controller ssc
     (.clk_in(sys_clk),
      .rst_in(sys_rst),
      .val_in(val_to_display),
      .en_in(1'b1),
      .cat_out(ss_c),
      .an_out({ss0_an,ss1_an}));
   
   
   // assign led[7:0] = count_valids;
   // assign led[10:8] = wstate;
   // assign led[11] = chunk_named_data;
   // assign led[14:12] = ustate;

   assign led[15] = chunk_named_data;
   assign led[14:12] = tg_state;
   // assign led[10] = playback_sample_valid;
   // assign led[9] = playback_sample_ready;
   // assign led[8] = count_samples > 10;
   // assign led[7] = phrase_valid;
   // assign led[6] = phrase_ready;
   // assign led[5] = write_axis_valid;
   // assign led[4] = write_axis_ready;
   // assign led[3] = read_axis_valid;
   // assign led[2] = read_axis_ready;
   // assign led[1] = outphrase_axis_valid;
   // assign led[0] = outphrase_axis_ready;
   assign led[7:0] = count_samples;
   assign led[11] = sample_write_valid;
   assign led[10] = phrase_valid;
   assign led[9] = phrase_ready;
   assign led[8] = write_axis_valid;
   
   // assign led[15:8] = count_samples;
   // assign led[15:8] = write_addr;
   // assign led[15] = read_addr_incr;

   assign pmoda[0] = uart_rxd;
   assign pmoda[3:1] = ustate;
   
   // assign pmoda[1] = (ustate == 0);
   // assign pmoda[2] = (ustate == 1);
   // assign pmoda[3] = (ustate == 2);
   // assign pmoda[4] = (ustate == 3);

endmodule // top_level

   
