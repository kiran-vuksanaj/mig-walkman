`timescale 1ns / 1ps
`default_nettype none

module uart_tb();

   logic clk_in;
   logic rst_in;

   logic uart_rx;
   
   logic valid_out;
   logic [7:0] data_out;


   uart_rcv
     #(.BAUD_RATE(25_000_000),
       .CLOCK_SPEED(100_000_000))
   dut
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .uart_rx(uart_rx),
      .valid_out(valid_out),
      .data_out(data_out));

   always begin
      #5;
      clk_in = !clk_in;
   end

   initial begin
      $dumpfile("uart.vcd");
      $dumpvars(0,uart_tb);
      $display("starting sim");

      clk_in = 0;
      rst_in = 0;
      uart_rx = 1;
      #6;
      rst_in = 1;
      #10;
      rst_in = 0;
      #10;
      uart_rx = 0;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 0;
      #40;
      uart_rx = 0;
      #40;
      uart_rx = 1;      
      #40;
      uart_rx = 1;
      #100;
      // blip of wrong stuff
      uart_rx = 0;
      #10;
      uart_rx = 1;
      #10;
      // correct stuff
      uart_rx = 0;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 1;
      #40;
      uart_rx = 0;
      #40;
      uart_rx = 0;
      #40;
      uart_rx = 1;      
      #40;
      uart_rx = 1;
      #500;
      $display("finishing sim");
      $finish;
   end

endmodule
`default_nettype wire
      
