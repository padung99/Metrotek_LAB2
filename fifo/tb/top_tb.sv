module top_tb;

parameter SHOWAHEAD_TOP = "ON";

fifo_tb #(.SHOWAHEAD_TB(SHOWAHEAD_TOP)) dut1();
scfifo_tb #(.SHOWAHEAD_TB(SHOWAHEAD_TOP)) dut2();
endmodule