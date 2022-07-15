`timescale 1 ps / 1 ps
// parameter MAX_PAKET = 13;
// interface avalon_st (input clk_i_tb );
//   logic valid;
//   logic ready;
//   logic [15:0] data;

//   modport sink( input data, valid, output ready );
//   modport source( input ready, output data, valid );

// endinterface

// typedef bit[15:0] packet_t[$];

// class pk_avalon_st( );

//   mailbox #( packet_t ) gen_pk;
  
//   virtual avalon_st avlst_if;

//   task send_pk();
//   endtask

//   task receive_pk();
//   endtask

//   function new( virtual avalon_st avlst_if );
//     this.avlst_if = avlst_if;
//   endfunction

// endclass

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

initial
  forever
  #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @( posedge clk_i_tb );
endclocking

Sorting #(
  .DWIDTH      (DWIDTH_TB),
  .MAX_PKT_LEN (MAX_PKT_LEN_TB)
) dut (
  .clk_i (clk_i_tb),
  .srst_i (srst_i_tb),

  .snk_data_i(snk_data_i_tb),
  .snk_startofpacket_i(snk_startofpacket_i_tb),
  .snk_endofpacket_i(snk_endofpacket_i_tb),
  .snk_valid_i(snk_valid_i_tb),
  .snk_ready_o(snk_ready_o_tb),

  .src_data_o(src_data_o_tb),
  .src_startofpacket_o( src_startofpacket_o_tb ),
  .src_endofpacket_o( src_endofpacket_o_tb ),
  .src_valid_o( src_valid_o_tb ),
  .src_ready_i ( src_ready_i_tb )
);

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
    src_ready_i_tb <= 1'b1;

    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
    
    // send_random_package( 3, data_gen );

      gen_package( data_gen );
      send_package( data_gen );
      ##(MAX_DATA_SEND*MAX_DATA_SEND);

 
      gen_package( data_gen2 );
      send_package( data_gen2 );
      ##(MAX_DATA_SEND*MAX_DATA_SEND);
      

      gen_package( data_gen3 );
      send_package( data_gen3 );

    // gen_package( data_gen );
    // send_package( data_gen );

    // snk_data_i_tb <= 16'h0;
    // ##1;
    // snk_data_i_tb <= 16'h16;
    // snk_startofpacket_i_tb <= 1;
    // snk_valid_i_tb <= 1;

    // ##1;
    // snk_data_i_tb <= 16'h15;
    // snk_startofpacket_i_tb <= 0;

    // ##1;
    // snk_data_i_tb <= 16'h17;

    // ##1;
    // snk_data_i_tb <= 16'h20;
    // snk_endofpacket_i_tb <= 1;
    // ##1;
    // snk_endofpacket_i_tb <= 0;
    // snk_valid_i_tb <= 0;
    // ##1;
    // snk_data_i_tb <= 16'h18;

    // ##1;
    // snk_data_i_tb <= 16'h23;

    // ##1;
    // snk_data_i_tb <= 16'h19;

    // ##1;
    // snk_data_i_tb <= 16'h22;

    // ##1;
    // snk_data_i_tb <= 16'h30;

    // ##1;
    // snk_data_i_tb <= 16'h14;

    // ##1;
    // snk_data_i_tb <= 16'h33;

    // ##1;
    // snk_data_i_tb <= 16'h41;

    // ##1;
    // snk_data_i_tb <= 16'h05;

    // ##1;
    // snk_data_i_tb <= 16'h13;
    
    // ##1;
    // snk_data_i_tb <= 16'h02;
    // snk_endofpacket_i_tb <= 1;

    // ##1;
    // snk_endofpacket_i_tb <= 0;
    // snk_valid_i_tb <= 0;
    
    // ##5;
    // src_ready_i_tb <= 1'b1;

    // ##2;
    // src_ready_i_tb <= 1'b0;
    
    // ##3;
    // src_ready_i_tb <= 1'b1;
    // ##(MAX_DATA_SEND*MAX_DATA_SEND);
    ##(MAX_DATA_SEND*MAX_DATA_SEND);
    $stop();

  end

endmodule