`timescale 1 ps / 1 ps
module fifo_tb;

parameter DWIDTH_TB             = 8;
parameter AWIDTH_TB             = 2;
parameter SHOWAHEAD_TB          = 1;
parameter ALMOST_FULL_VALUE_TB  = 2**AWIDTH_TB-1;
parameter ALMOST_EMPTY_VALUE_TB = 1;
parameter REGISTER_OUTPUT_TB    = 0;

parameter MAX_DATA_SEND         = 100;

bit   clk_i_tb;
bit   rst_done;

logic                 srst_i_tb;
logic [DWIDTH_TB-1:0] data_i_tb;

logic                 wrreq_i_tb;
logic                 rdreq_i_tb;
logic [DWIDTH_TB-1:0] q_o_tb;
logic                 empty_o_tb;
logic                 full_o_tb;
logic [AWIDTH_TB-1:0] usedw_o_tb;

logic                 almost_full_o_tb;  
logic                 almost_empty_o_tb;

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @ (posedge clk_i_tb);
endclocking

fifo #(
  .DWIDTH             ( DWIDTH_TB             ),
  .AWIDTH             ( AWIDTH_TB             ),
  .SHOWAHEAD          ( SHOWAHEAD_TB          ),
  .ALMOST_FULL_VALUE  ( ALMOST_FULL_VALUE_TB  ),
  .ALMOST_EMPTY_VALUE ( ALMOST_EMPTY_VALUE_TB ),
  .REGISTER_OUTPUT    ( REGISTER_OUTPUT_TB    )
) fifo_dut (
  .clk_i          ( clk_i_tb          ),
  .srst_i         ( srst_i_tb         ),
  .data_i         ( data_i_tb         ),

  .wrreq_i        ( wrreq_i_tb        ),
  .rdreq_i        ( rdreq_i_tb        ),
  .q_o            ( q_o_tb            ),
  .empty_o        ( empty_o_tb        ),
  .full_o         ( full_o_tb         ),
  .usedw_o        ( usedw_o_tb        ),

  .almost_full_o  ( almost_full_o_tb  ),
  .almost_empty_o ( almost_empty_o_tb )
);

mailbox #( logic [DWIDTH_TB-1:0] ) data_gen   = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_write = new();
mailbox #( logic [DWIDTH_TB-1:0] ) data_read  = new();

task gen_data( mailbox #( logic [DWIDTH_TB-1:0] ) _data );

logic [DWIDTH_TB-1:0] data_s;

  for( int i = 0; i < MAX_DATA_SEND; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TB-1,0 );
      _data.put( data_s );
    end
endtask

task wr_fifo ( mailbox #( logic [DWIDTH_TB-1:0] ) _gen_data,
               mailbox #( logic [DWIDTH_TB-1:0] ) _data_s
             );
logic [DWIDTH_TB-1:0] data_wr;
while( _gen_data.num() != 0 )
  begin
    _gen_data.get( data_wr );
    wrreq_i_tb = $urandom_range( 1,0 );

    if( full_o_tb == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_s.put( data_wr );
        data_i_tb = data_wr;
      end
    ##1;
  end
endtask

task rd_fifo ( mailbox #( logic [DWIDTH_TB-1:0] ) _rd_data );

for( int i = 0; i < MAX_DATA_SEND; i++ )
  begin
    
    rdreq_i_tb = $urandom_range( 1,0 );
    if( empty_o_tb == 1'b0 && rdreq_i_tb == 1'b1 )
      begin
        _rd_data.put( q_o_tb );
      end
    ##1;
  end

endtask

task testing ( mailbox #( logic [DWIDTH_TB-1:0] ) _rd_data,
               mailbox #( logic [DWIDTH_TB-1:0] ) _data_s
             );

while( _rd_data.num() != 0 && _data_s.num() != 0 )
  begin
    logic [DWIDTH_TB-1:0] new_rd_data;
    logic [DWIDTH_TB-1:0] new_data_s;
    _rd_data.get( new_rd_data );
    _data_s.get( new_data_s );
    $display("[%0d] Send: %x, receive: %x",_rd_data.num(), new_data_s, new_rd_data );

    if( new_rd_data != new_data_s )
      begin
        $display("Data error!!!!\n");
      end
    else
      begin
        $display( "Module runs correctly!!!\n" );
      end
  end

if( _data_s.num() != 0 )
  $display("%0d more data in sending mailbox!!!", _data_s.num() );
else
  $display("Sending mailbox is empty!!!");

if( _rd_data.num() != 0 )
  $display("%0d more data in receiving mailbox!!!", _rd_data.num() );
else
  $display("Receiving mailbox is empty!!!");
endtask

initial
  begin
    srst_i_tb <= 1'b1;
    ##1;
    srst_i_tb <= 1'b0;

    gen_data( data_gen );

    fork
      wr_fifo( data_gen, data_write );
      rd_fifo( data_read );
    join
    testing( data_read, data_write );

    $display( "Test done!" );
    $stop();
  end

endmodule