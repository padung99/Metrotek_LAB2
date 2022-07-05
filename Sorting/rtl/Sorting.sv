module Sorting #(
  parameter DWIDTH      = 16,
  parameter MAX_PKT_LEN = 16
) (
  input  logic              clk_i,
  input  logic              srst_i,

  input  logic [DWIDTH-1:0] snk_data_i,
  input  logic              snk_startofpacket_i,
  input  logic              snk_endofpacket_i,
  input  logic              snk_valid_i,
  output logic              snk_ready_o,

  output logic [DWIDTH-1:0] src_data_o,
  output logic              src_startofpacket_o,
  output logic              src_endofpacket_o,
  output logic              src_valid_o,
  input  logic              src_ready_i
);

localparam AWIDTH = $clog2(MAX_PKT_LEN) + 1 ;

logic [AWIDTH-1:0] wr_addr;
logic              sending;
logic              end_sending;
logic              wr_en;
integer            word_received;
logic [DWIDTH-1:0] sort_mem [MAX_PKT_LEN-1:0];
logic              sort_complete;
int                k;

// altsyncram #(
//   .clock_enable_input_a          ( "BYPASS"                ),
//   .clock_enable_output_a         ( "BYPASS"                ),
//   .intended_device_family        ( "Cyclone V"             ),
//   .lpm_hint                      ( "ENABLE_RUNTIME_MOD=NO" ),
//   .lpm_type                      ( "altsyncram"            ),
//   .numwords_a                    ( MAX_PKT_LEN             ),
//   .operation_mode                ( "SINGLE_PORT"           ),
//   .outdata_aclr_a                ( "NONE"                  ),
//   .outdata_reg_a                 ( "CLOCK0"                ),
//   .power_up_uninitialized        ( "FALSE"                 ),
//   .ram_block_type                ( "M10K"                  ),
//   .read_during_write_mode_port_a ( "DONT_CARE"             ),
//   .widthad_a                     ( AWIDTH                  ),
//   .width_a                       ( DWIDTH                  ),
//   .width_byteena_a               ( 1                       )
// ) mem_10K(
//   .address_a      ( addr        ),
//   .clock0         ( clk_i       ),
//   .data_a         ( snk_data_i  ),
//   .rden_a         ( src_ready_i ),
//   .wren_a         ( wr_en ),
//   .q_a            ( src_data_o  ),
//   .aclr0          ( 1'b0        ),
//   .aclr1          ( 1'b0        ),
//   .address_b      ( 1'b1        ),
//   .addressstall_a ( 1'b0        ),
//   .addressstall_b ( 1'b0        ),
//   .byteena_a      ( 1'b1        ),
//   .byteena_b      ( 1'b1        ),
//   .clock1         ( 1'b1        ),
//   .clocken0       ( 1'b1        ),
//   .clocken1       ( 1'b1        ),
//   .clocken2       ( 1'b1        ),
//   .clocken3       ( 1'b1        ),
//   .data_b         ( 1'b1        ),
//   .eccstatus      (             ),
//   .q_b            (             ),
//   .rden_b         ( 1'b1        ),
//   .wren_b         ( 1'b0        )
// );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        // src_data_o <= '0;
        wr_addr       <= '0;
      end
    else
      if( wr_en )
        wr_addr <= wr_addr + 1;
  end 

always_comb
  begin
    if( snk_valid_i && snk_startofpacket_i )
      sending = 1'b1;
    else if( snk_valid_i && snk_endofpacket_i )
      sending = 1'b0;
      
  end

always_ff @( posedge clk_i )
  begin
    if( snk_valid_i && snk_endofpacket_i )
      begin
        // sending <= 1'b0;
        end_sending <= 1'b1;
        snk_ready_o <= 1'b0; ///////
        k <= 0;
      end
  end

// assign end_sending = snk_valid_i && snk_endofpacket_i;
assign  wr_en = sending && snk_valid_i;


always_comb
  begin
    if( wr_en )
      sort_mem[wr_addr] = snk_data_i;
  end

//Sorting 
always_comb
  begin
    if( end_sending == 1'b1 )
      begin
        word_received = wr_addr;
        for( int i = 0; i <= word_received; i++ )
          begin
            for( int j = 0; j < word_received - i; j++ ) ///
              begin
                if( sort_mem[j] > sort_mem[j+1] )
                  begin
                    logic [DWIDTH-1:0] tmp;
                    tmp           = sort_mem[j];
                    sort_mem[j]   = sort_mem[j+1];
                    sort_mem[j+1] = tmp;
                  end
              end
          end
          sort_complete = 1'b1;
      end
  end

// always_ff @( posedge clk_i )
//   begin
//     if( sort_complete == 1'b1 )
//       begin
//         while( k < word_received )
//           begin
//             src_data_o  <= sort_mem[k]; 
//             src_valid_o <= 1'b1;
//             k <= k + 1;
//           end
//       end
//   end

// always_ff @( posedge clk_i )
//   begin
//     if( sort_complete == 1'b1 )
//       begin
//         if( k == 0 )
//           begin
//             src_startofpacket_o <= 1'b1;
//             snk_ready_o <= 1'b0;
//           end
//         else
//           src_startofpacket_o <= 1'b0;
//         //sending done
//         if( k == word_received-1 )
//           begin
//             src_endofpacket_o <= 1'b1;
//             // sort_complete <= 1'b0;
//             src_valid_o   <= 1'b0;
//             k <= 0;
//             snk_ready_o <= 1'b1;
//           end
//         else
//           src_endofpacket_o <= 1'b0;
//       end
//   end
endmodule
