interface avalon_st (input clk_i_tb );
  logic valid;
  logic ready;
  logic [15:0] data;
  logic sop;
  logic eop;

  modport sink( input data, valid, sop, eop output ready );
  modport source( input ready, output data, valid, sop, eop );

endinterface