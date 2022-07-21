interface avalon_st #( 
  parameter symbolsPerBeat = 4 //bytes
) ( input clk );
  
  parameter DATA_W = 8*symbolsPerBeat; //bits
  
  logic              valid;
  logic              ready;
  logic [DATA_W-1:0] data;
  logic              sop;
  logic              eop;

  modport sink( input data, valid, sop, eop, output ready );
  modport source( input ready, output data, valid, sop, eop );

endinterface