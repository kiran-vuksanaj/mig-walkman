`timescale 1ns / 1ps
`default_nettype none

module parse_wav
  (
   input wire 	       clk_in,
   input wire 	       rst_in,

   input wire [7:0]    wavbyte_in,
   input wire 	       wavbyte_valid_in,

   output logic [7:0]  sample_out,
   output logic        sample_valid_out,

   // debugging
   output logic        chunk_named_data_debug,
   output logic [2:0]  wstate,
   output logic [31:0] chunk_name_debug,
   output logic [31:0] remaining_length_debug
   );

   typedef enum {IDLE, TYPEDEF, CHUNK_NAME, CHUNK_LENGTH, CHUNK_BODY} chunk_state;
   chunk_state state;
   assign wstate = state;

   logic [7:0] 	chunk_name[3:0];
   logic [7:0] 	chunk_length[3:0];

   logic [31:0] chunk_name_packed;
   logic [31:0] chunk_length_packed;
   assign chunk_name_packed = {chunk_name[0],chunk_name[1],chunk_name[2],chunk_name[3]};
   assign chunk_length_packed = {chunk_length[0],chunk_length[1],chunk_length[2],chunk_length[3]};
   assign chunk_name_debug = chunk_name_packed;
   
   logic 	chunk_named_data;
   assign chunk_named_data = (chunk_name[3] == "d") && (chunk_name[2] == "a") && (chunk_name[1] == "t") && (chunk_name[0] == "a");
   assign chunk_named_data_debug = chunk_named_data;
   
   logic [31:0] remaining_length;
   assign remaining_length_debug = remaining_length;

   // typedef: "RIFFnnnnWAVE" ; 12 total bytes
   // format chunk: "fmt nnnn[contents]"

   always_ff @(posedge clk_in) begin

      if (rst_in) begin

	 for(integer i=0; i<4; i+=1) begin
	    chunk_name[i] <= 8'b0;
	    chunk_length[i] <= 8'b0;
	 end
	 state <= IDLE;
	 remaining_length <= 0;
	 sample_valid_out <= 0;
      end else begin

	 if (wavbyte_valid_in) begin
	    case(state)

	      IDLE: begin
		 state <= TYPEDEF;
		 remaining_length <= 10; // byte index 11 just came in ("R"), so up next is byte 10
	      end
	      TYPEDEF: begin
		 if (remaining_length == 0) begin
		    state <= CHUNK_NAME;
		    remaining_length <= 3;
		 end else begin
		    remaining_length <= remaining_length - 1;
		 end
	      end
	      CHUNK_NAME: begin
		 // TODO: check endianness
		 chunk_name[ remaining_length ] <= wavbyte_in;
		 if (remaining_length == 0) begin
		    remaining_length <= 3;
		    state <= CHUNK_LENGTH;
		 end else begin
		    remaining_length <= remaining_length - 1;
		 end
	      end
	      CHUNK_LENGTH: begin
		 chunk_length[ remaining_length ] <= wavbyte_in;
		 if (remaining_length == 0) begin
		    // TODO: check endianness
		    remaining_length <= { wavbyte_in, chunk_length[1], chunk_length[2], chunk_length[3] } - 1;
		    state <= CHUNK_BODY;
		 end else begin
		    remaining_length <= remaining_length - 1;
		 end
		 
	      end
	      CHUNK_BODY: begin
		 sample_valid_out <= chunk_named_data;
		 sample_out <= wavbyte_in;
		 if (remaining_length == 0) begin
		    state <= CHUNK_NAME;
		    remaining_length <= 3;
		 end else begin
		    remaining_length <= remaining_length - 1;
		 end
	      end
	    endcase // case (state)
	 end else begin // if (wavbyte_valid_in)
	    sample_valid_out <= 0;
	 end
      end
   end

endmodule

`default_nettype wire
