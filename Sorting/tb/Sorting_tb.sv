`timescale 1 ps / 1 ps

import avlst_pk::*;
// parameter MAX_PAKET = 13;

module Sorting_tb;

parameter DWIDTH_TB = 16;
parameter MAX_PKT_LEN_TB = 13;

parameter MAX_DATA_SEND = MAX_PKT_LEN_TB+5;

// localparam AWIDTH_TB = $clog2(MAX_PKT_LEN_TB) + 1;

bit                clk_i_tb;
logic              srst_i_tb;

logic [DWIDTH_TB-1:0] snk_data_i_tb;
logic              snk_startofpacket_i_tb;
logic              snk_endofpacket_i_tb;
logic              snk_valid_i_tb;
logic              snk_ready_o_tb;

logic [DWIDTH_TB-1:0] src_data_o_tb;
logic              src_startofpacket_o_tb;
logic              src_endofpacket_o_tb;
logic              src_ready_i_tb;

mailbox #( logic[DWIDTH_TB-1:0] ) pk_data = new();

initial
  forever
  #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @( posedge clk_i_tb );
endclocking

//Declare 2 instances avalon-st
avalon_st ast_sink_if(
  .clk( clk_i_tb )
);

avalon_st ast_source_if(
  .clk( clk_i_tb )
);

//Declare object 
pk_avalon_st #(
  .DWIDTH_PK    ( DWIDTH_TB      ),
  .WIDTH_MAX_PK ( MAX_PKT_LEN_TB )
) avalon_st_p_send;

pk_avalon_st #(
  .DWIDTH_PK    ( DWIDTH_TB      ),
  .WIDTH_MAX_PK ( MAX_PKT_LEN_TB )
) avalon_st_p_receive;

pk_avalon_st avalon_st_p_receive;

Sorting #(
  .DWIDTH              ( DWIDTH_TB           ),
  .MAX_PKT_LEN         ( MAX_PKT_LEN_TB      )
) dut (
  .clk_i               ( clk_i_tb            ),
  .srst_i              ( srst_i_tb           ),

  .snk_data_i          ( ast_sink_if.data    ),
  .snk_startofpacket_i ( ast_sink_if.sop     ),
  .snk_endofpacket_i   ( ast_sink_if.eop     ),
  .snk_valid_i         ( ast_sink_if.valid   ),
  .snk_ready_o         ( ast_sink_if.ready   ),

  .src_data_o          ( ast_source_if.data  ),
  .src_startofpacket_o ( ast_source_if.sop   ),
  .src_endofpacket_o   ( ast_source_if.eop   ),
  .src_valid_o         ( ast_source_if.valid ),
  .src_ready_i         ( ast_source_if.ready )
);

// Sorting #(
//   .DWIDTH      (DWIDTH_TB),
//   .MAX_PKT_LEN (MAX_PKT_LEN_TB)
// ) dut (
//   .clk_i (clk_i_tb),
//   .srst_i (srst_i_tb),

//   .snk_data_i(snk_data_i_tb),
//   .snk_startofpacket_i(snk_startofpacket_i_tb),
//   .snk_endofpacket_i(snk_endofpacket_i_tb),
//   .snk_valid_i(snk_valid_i_tb),
//   .snk_ready_o(snk_ready_o_tb),

//   .src_data_o(src_data_o_tb),
//   .src_startofpacket_o( src_startofpacket_o_tb ),
//   .src_endofpacket_o( src_endofpacket_o_tb ),
//   .src_valid_o( src_valid_o_tb ),
//   .src_ready_i ( src_ready_i_tb )
// );

mailbox #( logic [DWIDTH_TB-1:0] ) data_gen  = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_gen2 = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_gen3 = new();

task gen_package( mailbox #( logic [DWIDTH_TB-1:0] ) _data_gen );

logic [DWIDTH_TB-1:0] data_new;

for( int i = 0; i < MAX_DATA_SEND; i++ )
  begin
    data_new = $urandom_range( 2**DWIDTH_TB-1,0 );
    _data_gen.put( data_new );
  end
endtask;

task send_package ( mailbox #( logic [DWIDTH_TB-1:0] ) _data_gen );

logic [DWIDTH_TB-1:0] data_new;
int distance_start_end;
int cnt_data_received;

distance_start_end = $urandom_range( MAX_DATA_SEND-3, 2 );

while( ( cnt_data_received != distance_start_end ) )
  begin
    _data_gen.get( data_new );
    snk_data_i_tb = data_new;
    
    if( cnt_data_received == 0 )
      begin
        snk_startofpacket_i_tb = 1'b1;
        snk_valid_i_tb = 1'b1;
        ##1;
        snk_startofpacket_i_tb = 1'b0;
        cnt_data_received++;
      end
    else if( cnt_data_received < distance_start_end )
      begin
        snk_valid_i_tb = $urandom_range( 1,0 );
        if( snk_valid_i_tb )
          cnt_data_received++;
        ##1;
      end
  end
  if( cnt_data_received == distance_start_end )
      begin
        snk_endofpacket_i_tb = 1'b1;
        ##1;
        snk_valid_i_tb = 1'b0;
        snk_endofpacket_i_tb = 1'b0;
      end
  cnt_data_received = 0;
endtask


initial 
  begin
    
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
 
 /////////////////////////////////////////
    ast_source_if.ready <= 1'b1;
    gen_package( data_gen );
    avalon_st_p_send = new( ast_sink_if, data_gen );

    avalon_st_p_send.send_pk();
    ##(MAX_DATA_SEND*MAX_DATA_SEND);
////////////////////////////////////////
    // src_ready_i_tb <= 1'b1;
    // gen_package( data_gen );
    // send_package( data_gen );
    // ##(MAX_DATA_SEND*MAX_DATA_SEND);


    // gen_package( data_gen2 );
    // send_package( data_gen2 );
    // ##(MAX_DATA_SEND*MAX_DATA_SEND);
    

    // gen_package( data_gen3 );
    // send_package( data_gen3 );
    // ##(MAX_DATA_SEND*MAX_DATA_SEND);

    $stop();

  end

endmodule