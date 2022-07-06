`timescale 1 ps / 1 ps
module top_tb;

parameter DWIDTH_TOP             = 16;
parameter AWIDTH_TOP             = 4;
parameter SHOWAHEAD_TOP          = "ON";
parameter ALMOST_FULL_VALUE_TOP  = 2**AWIDTH_TOP-3;
parameter ALMOST_EMPTY_VALUE_TOP = 3;
parameter REGISTER_OUTPUT_TOP    = "OFF";

parameter MAX_DATA_SEND         = 100;

logic                 srst_i_tb;
logic [DWIDTH_TOP-1:0] data_i_tb;

logic                 wrreq_i_tb;
logic                 rdreq_i_tb;

logic [DWIDTH_TOP-1:0] q_o_top, q_o_top2;
logic                  empty_o_top, empty_o_top2;
logic                  full_o_top, full_o_top2;
logic [DWIDTH_TOP:0]   usedw_o_top, usedw_o_top2;

logic                  almost_full_o_top, almost_full_o_top2;  
logic                  almost_empty_o_top, almost_empty_o_top2;

bit q_o_error;
bit empty_o_error;
bit full_o_error;
bit usedw_o_error;
bit almost_full_o_error;
bit almost_empty_o_error;

bit clk_i_top;
int cnt_wr_data;
initial
  forever
    #5 clk_i_top = !clk_i_top;

default clocking cb
  @ (posedge clk_i_top);
endclocking

fifo #(
  .DWIDTH             ( DWIDTH_TOP             ),
  .AWIDTH             ( AWIDTH_TOP             ),
  .SHOWAHEAD          ( SHOWAHEAD_TOP          ),
  .ALMOST_FULL_VALUE  ( ALMOST_FULL_VALUE_TOP  ),
  .ALMOST_EMPTY_VALUE ( ALMOST_EMPTY_VALUE_TOP ),
  .REGISTER_OUTPUT    ( REGISTER_OUTPUT_TOP    )
) dut1(
  .clk_i          ( clk_i_top          ),
  .srst_i         ( srst_i_tb         ),
  .data_i         ( data_i_tb         ),

  .wrreq_i        ( wrreq_i_tb        ),
  .rdreq_i        ( rdreq_i_tb        ),
.q_o            ( q_o_top            ),
.empty_o        ( empty_o_top        ),
.full_o         ( full_o_top         ),
.usedw_o       ( usedw_o_top        ),

.almost_full_o  ( almost_full_o_top  ),
.almost_empty_o ( almost_empty_o_top )
);

scfifo #(
  .add_ram_output_register ( REGISTER_OUTPUT_TOP     ),
  .almost_empty_value      ( ALMOST_EMPTY_VALUE_TOP  ),
  .almost_full_value       ( ALMOST_FULL_VALUE_TOP   ),
  .intended_device_family  ( ""         ), //////////
  .lpm_hint                ("RAM_BLOCK_TYPE=M10K"),
  .lpm_numwords            ( 2**AWIDTH_TOP           ),
  .lpm_showahead           ( SHOWAHEAD_TOP           ),
  .lpm_type                ( "scfifo"            ),
  .lpm_width               ( DWIDTH_TOP              ),
  .lpm_widthu              ( AWIDTH_TOP              ),
  .overflow_checking       ( "ON"                ),
  .underflow_checking      ( "ON"                ),
  .use_eab                 ( "ON"                )
) dut2 (
  .clock        ( clk_i_top          ),
  .data         ( data_i_tb         ),
  .rdreq        ( rdreq_i_tb        ),
  .sclr         ( srst_i_tb         ),
  .wrreq        ( wrreq_i_tb        ),
  .almost_empty ( almost_empty_o_top2 ),
  .almost_full  ( almost_full_o_top2  ),
  .empty        ( empty_o_top2        ),
  .full         ( full_o_top2         ),
  .q            ( q_o_top2            ),
  .usedw        ( usedw_o_top2        ),
  .aclr         (                   ),
  .eccstatus    (                   )
);

// scfifo_tb #(
//   .DWIDTH_TB             ( DWIDTH_TOP             ),
//   .AWIDTH_TB             ( AWIDTH_TOP             ),
//   .SHOWAHEAD_TB          ( SHOWAHEAD_TOP          ),
//   .ALMOST_FULL_VALUE_TB  ( ALMOST_FULL_VALUE_TOP  ),
//   .ALMOST_EMPTY_VALUE_TB ( ALMOST_EMPTY_VALUE_TOP ),
//   .REGISTER_OUTPUT_TB    ( REGISTER_OUTPUT_TOP    )
// ) dut2(
// .q_o_tb            ( q_o_top2            ),
// .empty_o_tb        ( empty_o_top2        ),
// .full_o_tb         ( full_o_top2         ),
// .usedw_o_tb        ( usedw_o_top2        ),

// .almost_full_o_tb  ( almost_full_o_top2  ),
// .almost_empty_o_tb ( almost_empty_o_top2 )
// );

mailbox #( logic [DWIDTH_TOP-1:0] ) data_gen   = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_write = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_read  = new();

task gen_data( mailbox #( logic [DWIDTH_TOP-1:0] ) _data );

logic [DWIDTH_TOP-1:0] data_s;

  for( int i = 0; i < MAX_DATA_SEND; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TOP-1,0 );
      _data.put( data_s );
    end
endtask

task wr_fifo ( mailbox #( logic [DWIDTH_TOP-1:0] ) _gen_data,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _data_s
             );
logic [DWIDTH_TOP-1:0] data_wr;
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

    if( full_o_top == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_s.put( data_wr );
        data_i_tb = data_wr;
      end
    pause_wr--;
    ##1;
  end
endtask

task rd_fifo ( mailbox #( logic [DWIDTH_TOP-1:0] ) _rd_data );

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
    if( empty_o_top == 1'b0 && rdreq_i_tb == 1'b1 && q_o_top >= (DWIDTH_TOP)'(0) ) 
      _rd_data.put( q_o_top );
    pause_rd--;
    ##1;

  end
endtask

task testing ( mailbox #( logic [DWIDTH_TOP-1:0] ) _rd_data,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _data_s
             );
logic [DWIDTH_TOP-1:0] new_rd_data;
logic [DWIDTH_TOP-1:0] new_data_s;
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
    // testing( data_read, data_write );

    // $display( "Test done!" );
    $stop();
  end
endmodule