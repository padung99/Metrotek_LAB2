`timescale 1 ps / 1 ps
module scfifo_tb;

parameter DWIDTH_TB             = 16;
parameter AWIDTH_TB             = 4;
parameter SHOWAHEAD_TB          = "OFF";
parameter ALMOST_FULL_VALUE_TB  = 2**AWIDTH_TB-3;
parameter ALMOST_EMPTY_VALUE_TB = 3;
parameter REGISTER_OUTPUT_TB    = "OFF";

parameter MAX_DATA_SEND         = 100;

bit   clk_i_tb;

logic                 srst_i_tb;
logic [DWIDTH_TB-1:0] data_i_tb;

logic                 wrreq_i_tb;
logic                 rdreq_i_tb;
logic [DWIDTH_TB-1:0] q_o_tb;
logic                 empty_o_tb;
logic                 full_o_tb;
logic [AWIDTH_TB:0] usedw_o_tb;

logic                 almost_full_o_tb;  
logic                 almost_empty_o_tb;
int cnt_wr_data;

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @ (posedge clk_i_tb);
endclocking

scfifo #(
  .add_ram_output_register ( REGISTER_OUTPUT_TB     ),
  .almost_empty_value      ( ALMOST_EMPTY_VALUE_TB  ),
  .almost_full_value       ( ALMOST_FULL_VALUE_TB   ),
  .intended_device_family  ( ""                     ), //////////
  .lpm_hint                ("RAM_BLOCK_TYPE=M10K"   ),
  .lpm_numwords            ( 2**AWIDTH_TB           ),
  .lpm_showahead           ( SHOWAHEAD_TB           ),
  .lpm_type                ( "scfifo"               ),
  .lpm_width               ( DWIDTH_TB              ),
  .lpm_widthu              ( AWIDTH_TB              ),
  .overflow_checking       ( "ON"                   ),
  .underflow_checking      ( "ON"                   ),
  .use_eab                 ( "ON"                   )
) golden_model (
  .clock        ( clk_i_tb          ),
  .data         ( data_i_tb         ),
  .rdreq        ( rdreq_i_tb        ),
  .sclr         ( srst_i_tb         ),
  .wrreq        ( wrreq_i_tb        ),
  .almost_empty ( almost_empty_o_tb ),
  .almost_full  ( almost_full_o_tb  ),
  .empty        ( empty_o_tb        ),
  .full         ( full_o_tb         ),
  .q            ( q_o_tb            ),
  .usedw        ( usedw_o_tb        ),
  .aclr         (                   ),
  .eccstatus    (                   )
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
int pause_wr;

while( _gen_data.num() != 0 )
  begin
    if( pause_wr == 0 )
      begin
        cnt_wr_data++;
        _gen_data.get( data_wr );
        pause_wr   = $urandom_range( 6,1 );
        wrreq_i_tb = $urandom_range( 1,0 );
      end

    if( full_o_tb == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_s.put( data_wr );
        data_i_tb = data_wr;
      end
    pause_wr--;
    ##1;
  end
endtask

task rd_fifo ( mailbox #( logic [DWIDTH_TB-1:0] ) _rd_data );

int pause_rd;
int i;
i = 0;
while( cnt_wr_data < MAX_DATA_SEND )
  begin
    if( pause_rd == 0 )
      begin
        pause_rd   = $urandom_range( 6,1 );
        rdreq_i_tb = $urandom_range( 1,0 );
      end
    //Using conditon q_o_tb >= (DWIDTH_TB)'(0) to ignore Unknow value 'X' when change parameter showahead to "OFF"
    if( empty_o_tb == 1'b0 && rdreq_i_tb == 1'b1 && q_o_tb >= (DWIDTH_TB)'(0) ) 
      _rd_data.put( q_o_tb );
    pause_rd--;
    ##1;

  end
endtask

task testing ( mailbox #( logic [DWIDTH_TB-1:0] ) _rd_data,
               mailbox #( logic [DWIDTH_TB-1:0] ) _data_s
             );
logic [DWIDTH_TB-1:0] new_rd_data;
logic [DWIDTH_TB-1:0] new_data_s;
int total_data_send;
total_data_send = _data_s.num();

while( _rd_data.num() != 0 && _data_s.num() != 0 )
  begin
    _rd_data.get( new_rd_data );
    _data_s.get( new_data_s );
    $display("[%0d] Send: %x, read: %x",_rd_data.num(), new_data_s, new_rd_data );

    if( new_rd_data != new_data_s )
      begin
        $display("Module runs with errors!!!!\n");
        // $stop();
      end
    else
      $display( "Module runs correctly!!!\n" );
  end

$display( "Total data send: %0d", total_data_send - _data_s.num() );

if( _data_s.num() != 0 )
  begin
    $display("%0d more data in sending mailbox!!!", _data_s.num() );
    while( _data_s.num() != 0 )
      begin
        _data_s.get( new_data_s );
        $display("%x", new_data_s );
      end      
  end
else
  $display("Sending mailbox is empty!!!");

if( _rd_data.num() != 0 )
  begin
    $display("%0d more data in reading mailbox!!!", _rd_data.num() );
    while( _rd_data.num() != 0 )
      begin
        _rd_data.get( new_rd_data );
        $display("%x", new_rd_data );
      end  
  end
else
  $display("Reading mailbox is empty!!!");
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