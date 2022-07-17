`timescale 1 ps / 1 ps

import avlst_pk::*;
parameter MAX_PACKET = 105;

module Sorting_tb;

parameter DWIDTH_TB = 16;
parameter MAX_PKT_LEN_TB = 14;


bit                clk_i_tb;
logic              srst_i_tb;


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

//Declare objects
pk_avalon_st #(
  .PACKET       ( MAX_PACKET     )
) avalon_st_p_send;

pk_avalon_st #(
  .PACKET       ( MAX_PACKET     )
) avalon_st_p_receive;


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

mailbox #( pkt_t ) tx_fifo       = new();
mailbox #( pkt_t ) rx_fifo       = new(); 
mailbox #( pkt_t ) valid_tx_fifo = new();
mailbox #( pkt_t ) valid_input   = new();

task gen_package( mailbox #( pkt_t ) _tx_fifo );


pkt_t                 pk_new;

int                   number_of_data;

for( int i = 0; i < MAX_PACKET; i++ )
  begin
    logic [DWIDTH_TB-1:0] data_new;
    number_of_data = $urandom_range( MAX_PKT_LEN_TB,6 );
    for( int j = 0; j < number_of_data; j++ )
      begin
        data_new = $urandom_range( 2**DWIDTH_TB-1,0 );
        pk_new.push_back( data_new );
      end
    _tx_fifo.put( pk_new );
    pk_new = {};
  end
endtask;

task sort_queue( mailbox #( pkt_t ) _valid_tx_fifo,
                 mailbox #( pkt_t ) _valid_input
               );
pkt_t   pk_new;

while( _valid_tx_fifo.num() != 0 )
  begin
    _valid_tx_fifo.get( pk_new );
    pk_new.sort();
    _valid_input.put( pk_new );
  end

endtask

task compare_result( mailbox #( pkt_t ) _rx_fifo,
                     mailbox #( pkt_t ) _valid_input
                   );

pkt_t   pk_new_s;
pkt_t   pk_new_r;

int number_of_pk;

bit _error;

number_of_pk =_valid_input.num();

$display("Packet sended: %0d, packet received: %0d", _valid_input.num(), _rx_fifo.num());
if( _valid_input.num() != _rx_fifo.num() )
  begin
    $error("Number of packets mismatch!!");
    _error = 1;
  end
else
  begin
    while( _valid_input.num() != 0 )
      begin
        _valid_input.get( pk_new_r );
        _rx_fifo.get( pk_new_s );
        if( pk_new_r != pk_new_s )
          begin
            $error("Number of data in packet %0d mismatches", number_of_pk-_valid_input.num());
            _error = 1;
          end
        else
          begin
            for( int i = 0; i < pk_new_r.size(); i++ )
              begin
                if( pk_new_r[i] != pk_new_s[i] )
                  begin
                    $error("%0d element of packet %0d mismatches", i, number_of_pk-_valid_input.num());
                    _error = 1;
                  end
              end
          end
      end
    if( _error != 1'b1 )
      $display("No error!!!");
  end

endtask

initial 
  begin
    
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
    ast_source_if.ready <= 1'b1;

    gen_package( tx_fifo );
    avalon_st_p_send    = new( ast_sink_if, tx_fifo, valid_tx_fifo, rx_fifo );
    avalon_st_p_receive = new( ast_source_if, tx_fifo, valid_tx_fifo,rx_fifo );

    fork
      avalon_st_p_send.send_pk();
      avalon_st_p_receive.receive_pk();
    join

    sort_queue( valid_tx_fifo, valid_input );

    compare_result( rx_fifo, valid_input );
    $display("Test done!!!!");
    $stop();

  end

endmodule