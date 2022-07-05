module Sorting_tb;

parameter DWIDTH_TB = 16;
parameter MAX_PKT_LEN_TB = 16;

bit              clk_i_tb;
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

initial 
  begin
    snk_data_i_tb <= 16'h0;
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
    
    ##1;
    snk_data_i_tb <= 16'h16;
    snk_startofpacket_i_tb <= 1;
    snk_valid_i_tb <= 1;

    ##1;
    snk_data_i_tb <= 16'h15;
    snk_startofpacket_i_tb <= 0;

    ##1;
    snk_data_i_tb <= 16'h13;

    ##1;
    snk_data_i_tb <= 16'h02;
    snk_endofpacket_i_tb <= 1;

    ##1;
    snk_endofpacket_i_tb <= 0;
    snk_valid_i_tb <= 0;
    
    ##20;
    $stop();

  end

endmodule