`timescale 1 ps / 1 ps
module top_tb;

parameter DWIDTH_TOP             = 16;
parameter AWIDTH_TOP             = 4;
parameter SHOWAHEAD_TOP          = "ON";
parameter ALMOST_FULL_VALUE_TOP  = 2**AWIDTH_TOP-3;
parameter ALMOST_EMPTY_VALUE_TOP = 3;
parameter REGISTER_OUTPUT_TOP    = "OFF";

parameter WRITE_UNTIL_FULL       = 2**AWIDTH_TOP + 5;
parameter MAX_DATA_RANDOM        = 100;

parameter MANY_WRITE_QUERIES     = 100;
parameter MANY_READ_QUERIES      = 100;

parameter MAX_DATA_SEND          = WRITE_UNTIL_FULL + MANY_WRITE_QUERIES + MANY_READ_QUERIES;
parameter READ_UNTIL_EMPTY       = WRITE_UNTIL_FULL;

logic                  srst_i_tb;
logic [DWIDTH_TOP-1:0] data_i_tb;

bit                  wrreq_i_tb;
bit                  rdreq_i_tb;

logic [DWIDTH_TOP-1:0] q_o_top, q_o_top2;
logic                  empty_o_top, empty_o_top2;
logic                  full_o_top, full_o_top2;
logic [AWIDTH_TOP:0]   usedw_o_top, usedw_o_top2;

logic                  almost_full_o_top, almost_full_o_top2;  
logic                  almost_empty_o_top, almost_empty_o_top2;

// bit q_o_error;
// bit empty_o_error;
// bit full_o_error;
// bit usedw_o_error;
// bit almost_full_o_error;
// bit almost_empty_o_error;

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
  .srst_i         ( srst_i_tb          ),
  .data_i         ( data_i_tb          ),

  .wrreq_i        ( wrreq_i_tb         ),
  .rdreq_i        ( rdreq_i_tb         ),
  .q_o            ( q_o_top            ),
  .empty_o        ( empty_o_top        ),
  .full_o         ( full_o_top         ),
  .usedw_o        ( usedw_o_top        ),

  .almost_full_o  ( almost_full_o_top  ),
  .almost_empty_o ( almost_empty_o_top )
);

scfifo #(
  .add_ram_output_register ( REGISTER_OUTPUT_TOP     ),
  .almost_empty_value      ( ALMOST_EMPTY_VALUE_TOP  ),
  .almost_full_value       ( ALMOST_FULL_VALUE_TOP   ),
  .intended_device_family  ( "Cyclone V"             ),
  .lpm_hint                ("RAM_BLOCK_TYPE=M10K"    ),
  .lpm_numwords            ( 2**AWIDTH_TOP           ),
  .lpm_showahead           ( SHOWAHEAD_TOP           ),
  .lpm_type                ( "scfifo"                ),
  .lpm_width               ( DWIDTH_TOP              ),
  .lpm_widthu              ( AWIDTH_TOP              ),
  .overflow_checking       ( "ON"                    ),
  .underflow_checking      ( "ON"                    ),
  .use_eab                 ( "ON"                    )
) dut2 (
  .clock        ( clk_i_top           ),
  .data         ( data_i_tb           ),
  .rdreq        ( rdreq_i_tb          ),
  .sclr         ( srst_i_tb           ),
  .wrreq        ( wrreq_i_tb          ),
  .almost_empty ( almost_empty_o_top2 ),
  .almost_full  ( almost_full_o_top2  ),
  .empty        ( empty_o_top2        ),
  .full         ( full_o_top2         ),
  .q            ( q_o_top2            ),
  .usedw        ( usedw_o_top2        ),
  .aclr         (                     ),
  .eccstatus    (                     )
);

mailbox #( logic [DWIDTH_TOP-1:0] ) data_gen   = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_write = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_read  = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) full_data_wr = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_rd_qr = new();
mailbox #( logic [DWIDTH_TOP-1:0] ) data_wr_qr = new();

task gen_data( mailbox #( logic [DWIDTH_TOP-1:0] ) _data,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _full_wr,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _rd,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _wr
             );

logic [DWIDTH_TOP-1:0] data_s;

  for( int i = 0; i < WRITE_UNTIL_FULL; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TOP-1,0 );
      _full_wr.put( data_s );
    end

  for( int i = 0; i < MANY_WRITE_QUERIES; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TOP-1,0 );
      _wr.put( data_s );
    end

  for( int i = 0; i < MANY_READ_QUERIES; i++ )
    begin
      data_s = $urandom_range( 2**DWIDTH_TOP-1,0 );
      _rd.put( data_s );
    end
endtask

task wr_until_full( mailbox #( logic [DWIDTH_TOP-1:0] ) _full_wr,
                    mailbox #( logic [DWIDTH_TOP-1:0] ) _data_wr
                  );
logic [DWIDTH_TOP-1:0] data_wr;

while( _full_wr.num() != 0 )
  begin
    cnt_wr_data++;
    _full_wr.get( data_wr );
    wrreq_i_tb = 1'b1;
    // $display("cnt_wr_data: %0d, wr_data: %x", cnt_wr_data, data_wr);
    if( full_o_top == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_wr.put( data_wr );
        data_i_tb = data_wr;
        // $display("[%0d] write: %x",_full_wr.num(), data_i_tb);
      end
    ##1;
  end
wrreq_i_tb = 1'b0;
endtask

task rd_until_empty( mailbox #( logic [DWIDTH_TOP-1:0] ) _data_rd );

// int i;
// i = 0;
for( int i = 0; i < READ_UNTIL_EMPTY; i++ )
  begin
    // $display("cnt_wr_data: %0d", cnt_wr_data);
    cnt_wr_data++;
    rdreq_i_tb = 1'b1;
    if( empty_o_top == 1'b0 && rdreq_i_tb == 1'b1 )
      begin
        _data_rd.put( q_o_top );
        // $display("[%0d] read: q_o: %x", i, q_o_top);
      end
    ##1;
  end
endtask

task wr_queries ( input int _lower_wr,
                        int _upper_wr, 
                  mailbox #( logic [DWIDTH_TOP-1:0] ) _wr,
                  mailbox #( logic [DWIDTH_TOP-1:0] ) _data_wr
                );

logic [DWIDTH_TOP-1:0] data_wr;
int pause_wr;
int cnt_wr;

while( _wr.num() != 0 )
  begin

    if( pause_wr == 0 )
      begin
        // $display("cnt_wr_data: %0d, wr_data: %x", cnt_wr_data, data_wr);
        cnt_wr_data++;
        _wr.get( data_wr );
        pause_wr   = $urandom_range( _upper_wr,_lower_wr );
        wrreq_i_tb = 0;
      end
    else
      begin
        wrreq_i_tb = 1;
      end

    if( full_o_top == 1'b0 && wrreq_i_tb == 1'b1 )
      begin
        _data_wr.put( data_wr );
        data_i_tb = data_wr;
        // $display("[%0d] write: %x",_wr.num(), data_i_tb );
      end
    pause_wr--;
    ##1;
    // $display("[%0d] data_wr: %x", _wr.num(), data_wr );
  end
  // $display("Write done!!");
endtask

task rd_fifo ( input int cnt_data_rd,
                     int _lower_rd,
                     int _upper_rd,
                mailbox #( logic [DWIDTH_TOP-1:0] ) _data_rd
              );

int pause_rd;
int i;
i = 0;
while( cnt_wr_data < cnt_data_rd )
  begin
    // $display("cnt_wr_data: %0d", cnt_wr_data);
    if( pause_rd == 0 )
      begin
        pause_rd   = $urandom_range( _upper_rd,_lower_rd );
        rdreq_i_tb = 0;
      end
    else
      rdreq_i_tb = 1;
    //Using conditon q_o_tb >= (DWIDTH_TB)'(0) to ignore Unknow value 'X' when change parameter showahead to "OFF"
    if( empty_o_top == 1'b0 && rdreq_i_tb == 1'b1 )
      begin
        _data_rd.put( q_o_top );
        // $display("read: %x", q_o_top );
      end
    pause_rd--;
    ##1;
  end
  // $display("Read done!!");
endtask

task compare_ouput( input int cnt_data, string task_name );

bit q_error;
bit empty_error;
bit full_error;
bit usedw_error;
bit almost_full_error;
bit almost_empty_error;

  forever
    begin
      ##1;
      if( q_o_top != q_o_top2 )
        begin
          q_error = 1;
          $error("q mismatch");
        end
      // else
      //   q_error = 1;
      //   $display("q: fifo: %x, scfifo: %x",q_o_top, q_o_top2 );

      if( almost_empty_o_top != almost_empty_o_top2 )
      begin
        almost_empty_error = 1;
        $error("almost_empty mismatch");
      end
      // else
      //   // $display("almost_empty: fifo: %x, scfifo: %x",almost_empty_o_top, almost_empty_o_top2 );

      if( almost_full_o_top != almost_full_o_top2 )
        begin
          almost_full_error = 1;
          $error("almost_full mismatch");
        end
      // else
      //   almost_full_error = 0;
      //   // $display("almost_full: fifo: %x, scfifo: %x",almost_full_o_top, almost_full_o_top2 );

      if( full_o_top != full_o_top2 )
        begin
          full_error = 1;
          $error("full mismatch");
        end
      // else
      //   full_error = 0;
      //   // $display("full: fifo: %x, scfifo: %x",full_o_top, full_o_top2 );

      if( empty_o_top != empty_o_top2 )
        begin
          empty_error = 1;
          $error("empty mismatch");
        end
      // else
      //   empty_error = 0;
      //   // $display("empty: fifo: %x, scfifo: %x",empty_o_top, empty_o_top2 );

      if( usedw_o_top != usedw_o_top2 )
        begin
          usedw_error = 1;
          $error("usedw mismatch");
        end
      // else
      //   usedw_error = 0;
      //   // $display("usedw: fifo: %x, scfifo: %x",usedw_o_top, usedw_o_top2 );

      if (cnt_wr_data >= cnt_data)
        break;
    end
  
  if( !q_error && !almost_empty_error && !almost_full_error && !full_error && !empty_error && !usedw_error )
    $display( "%s: Output match", task_name );
    

endtask;

task testing ( mailbox #( logic [DWIDTH_TOP-1:0] ) _rd_data,
               mailbox #( logic [DWIDTH_TOP-1:0] ) _data_s
             );
logic [DWIDTH_TOP-1:0] new_rd_data;
logic [DWIDTH_TOP-1:0] new_data_s;
int total_data_send;
bit data_error;

total_data_send = _data_s.num();

while( _rd_data.num() != 0 && _data_s.num() != 0 )
  begin
    _rd_data.get( new_rd_data );
    _data_s.get( new_data_s );
    // $display("[%0d] Send: %x, read: %x",_rd_data.num(), new_data_s, new_rd_data );

    if( new_rd_data != new_data_s )
      begin
        // $error("Module runs with errors!!!!\n");
        data_error = 1;
        // $stop();
      end

  end

if( !data_error )
  begin
    $display( "Test completed - No error!!!\n" );
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
    

    gen_data( data_gen, full_data_wr, data_rd_qr, data_wr_qr );
    fork
      wr_until_full( full_data_wr, data_write );
      compare_ouput(WRITE_UNTIL_FULL, "Write data until full");
    join

    cnt_wr_data = 0;

    fork
      rd_until_empty( data_read );
      compare_ouput( READ_UNTIL_EMPTY, "Read data from fifo until empty" );
    join

    cnt_wr_data = 0;

    fork
      wr_queries( 4,6, data_wr_qr, data_write );
      rd_fifo( MANY_WRITE_QUERIES, 1,2, data_read );
      compare_ouput( MANY_WRITE_QUERIES, "Write queries more than read queries" );
    join
  
    cnt_wr_data = 0;


    fork
      wr_queries( 1,2, data_rd_qr, data_write );
      rd_fifo( MANY_READ_QUERIES, 4,6, data_read );
      compare_ouput( MANY_READ_QUERIES, "Read queries more than write queries" );
    join
    
    $display("###Start testing write data and read data");
    testing( data_read, data_write );

    $display( "Test done!" );

    $stop();
  end
endmodule