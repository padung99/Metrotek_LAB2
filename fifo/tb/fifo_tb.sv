`timescale 1 ps / 1 ps
module fifo_tb;

parameter DWIDTH_TB             = 16;
parameter AWIDTH_TB             = 8;
parameter SHOWAHEAD_TB          = 1;
parameter ALMOST_FULL_VALUE_TB  = 240;
parameter ALMOST_EMPTY_VALUE_TB = 15;
parameter REGISTER_OUTPUT_TB    = 0;

parameter TEST_CNT              = 100;

bit   clk_i_tb;
bit   rst;
bit   rst_done;

logic              clk_i_tb_i_tb;
logic              srst_i_tb;
logic [DWIDTH_TB-1:0] data_i_tb;

logic              wrreq_i_tb;
logic              rdreq_i_tb;
logic [DWIDTH_TB-1:0] q_o_tb;
logic              empty_o_tb;
logic              full_o_tb;
logic              usedw_o_tb;

logic              almost_full_o_tb;  
logic              almost_empty_o_tb;

//////////////////////////
// logic               wrreq_i_tb;
// logic [DWIDTH_TB-1:0]  data_i_tb;
// logic               full;

// logic               rdreq_i_tb;
// logic [DWIDTH_TB-1:0]  q_o_tb;
// logic               empty;

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @ (posedge clk_i_tb);
endclocking

initial
 begin
   srst_i_tb <= 1'b0;
   ##1;
   srst_i_tb <= 1'b1;
   ##1;
   srst_i_tb <= 1'b0;
   rst_done = 1'b1;
 end

fifo #(
  .DWIDTH             ( DWIDTH_TB             ),
  .AWIDTH             ( AWIDTH_TB             ),
  .SHOWAHEAD          ( SHOWAHEAD_TB          ),
  .ALMOST_FULL_VALUE  ( ALMOST_FULL_VALUE_TB  ),
  .ALMOST_EMPTY_VALUE ( ALMOST_EMPTY_VALUE_TB ),
  .REGISTER_OUTPUT    ( REGISTER_OUTPUT_TB    )
) fifo_dut (
  .clk_i          ( clk_i_tb          ),
  .srt_i          ( srt_i_tb          ),
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

int                             cnt;
mailbox #( logic [DWIDTH_TB-1:0] ) generated_data = new();
mailbox #( logic [DWIDTH_TB-1:0] ) sended_data    = new();
mailbox #( logic [DWIDTH_TB-1:0] ) read_data      = new();

task gen_data(  input  int                      cnt,
                mailbox #( logic [DWIDTH_TB-1:0] ) data );

logic [DWIDTH_TB-1:0] data_to_send;

  for( int i = 0; i < cnt; i++ )
    begin
      data_to_send = $urandom_range(2**DWIDTH_TB-1,0);
      data.put( data_to_send );
    end

endtask

task fifo_wr( mailbox #( logic [DWIDTH_TB-1:0] ) data,
              mailbox #( logic [DWIDTH_TB-1:0] ) sended_data,
              input  bit                      burst = 0
            );

  logic [DWIDTH_TB-1:0] word_to_wr;
  int                pause;
  while( data.num() )
    begin
      data.get(word_to_wr);
      if( burst )
        pause = 0;
      else
        pause = $urandom_range(10,0);

      data_i_tb <= word_to_wr;
      wrreq_i_tb  <= 1'b1;
      ##1;

      if( !full_o_tb )
        sended_data.put( word_to_wr );

      if( pause != 0 )
        begin
          wrreq_i_tb  <= 1'b0;
          ##pause;
        end
    end
  wrreq_i_tb <= 1'b0;
endtask

task fifo_rd( mailbox #( logic [DWIDTH_TB-1:0] ) read_data,
              input  int                      empty_timeout,
              input  bit                      burst = 0
            );

  int no_empty_counter;
  int pause;

  forever
    begin
      if( !empty_o_tb )
        begin
          if( burst )
            pause = 0;
          else
            pause = $urandom_range(10,0);

          no_empty_counter  = 0;

          rdreq_i_tb           <= 1'b1;
          ##1;
          read_data.put( q_o_tb );
          if( pause != 0 )
            begin
              rdreq_i_tb <= 0;
              ##pause;
            end
        end
      else
        begin

          if( no_empty_counter == empty_timeout )
            return;
          else
            no_empty_counter += 1;

          ##1;
        end
    end
endtask

task compare_data( mailbox #( logic [DWIDTH_TB-1:0] ) ref_data,
                   mailbox #( logic [DWIDTH_TB-1:0] ) dut_data
                 );

logic [DWIDTH_TB-1:0] ref_data_tmp;
logic [DWIDTH_TB-1:0] dut_data_tmp;

  if( ref_data.num() != dut_data.num() )
    begin
      $display( "Size of ref data: %d", ref_data.num() );
      $display( "And sized of dut data: %d", dut_data.num() );
      $display( "Do not match" );
      $stop();
    end
  else
    begin
      for( int i = 0; i < dut_data.num(); i++ )
        begin
          dut_data.get( dut_data_tmp );
          ref_data.get( ref_data_tmp );
          if( ref_data_tmp != dut_data_tmp )
            begin
              $display( "Error! Data do not match!" );
              $display( "Reference data: %x", ref_data_tmp );
              $display( "Read data: %x", dut_data_tmp );
              $stop();
            end
        end
    end

endtask

initial
  begin
    data_i_tb <= '0;
    wrreq_i_tb  <= 1'b0;
    rdreq_i_tb  <= 1'b0;

    gen_data( TEST_CNT, generated_data );

    wait( rst_done );

    fork
      fifo_wr(generated_data, sended_data);
      fifo_rd(read_data, 1000);
    join

    compare_data(sended_data, read_data);
    $display( "Test done! No errors!" );
    $stop();
  end

endmodule