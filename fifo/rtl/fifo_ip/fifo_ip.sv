module fifo_ip #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 8,
  parameter SHOWAHEAD          = "ON",
  parameter ALMOST_FULL_VALUE  = 240,
  parameter ALMOST_EMPTY_VALUE = 15,
  parameter REGISTER_OUTPUT    = "OFF"
) (
  input  logic              clk_i,
  input  logic              srst_i,
  input  logic [DWIDTH-1:0] data_i,

  input  logic              wrreq_i,
  input  logic              rdreq_i,
  output logic [DWIDTH-1:0] q_o,
  output logic              empty_o,
  output logic              full_o,
  output logic [AWIDTH:0]   usedw_o,

  output logic              almost_full_o,
  output logic              almost_empty_o
);

logic [AWIDTH:0]   wr_addr;
logic [AWIDTH:0]   rd_addr;
logic [AWIDTH:0]   next_rdaddr;
logic [AWIDTH:0]   next_wraddr;
logic [AWIDTH:0]   first_valid_word;

logic              valid_rd;
logic              valid_wr;

logic [AWIDTH:0]   rd_addr_mem;
logic              valid_rd_mem;

mem #(
  .DWIDTH_MEM ( DWIDTH ),
  .AWIDTH_MEM ( AWIDTH )
) mem_inst (
  .clock     ( clk_i                   ),
	.data      ( data_i                  ),
	.rdaddress ( rd_addr_mem[AWIDTH-1:0] ), 
	.rden      ( valid_rd_mem            ), 
	.wraddress ( wr_addr[AWIDTH-1:0]     ),
	.wren      ( valid_wr                ),
	.q         ( q_o                     )
);


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      wr_addr <= ( AWIDTH+1 )'(0);
    else
      if( valid_wr )
        wr_addr <= next_wraddr;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      rd_addr <= (AWIDTH+1)'(0);
    else
      if( valid_rd )
        rd_addr <= next_rdaddr;
  end

assign valid_rd         = rdreq_i  && !empty_o;
assign valid_wr         = wrreq_i  && !full_o;
assign next_rdaddr      = rd_addr + ( AWIDTH+1 )'(1);
assign next_wraddr      = wr_addr + ( AWIDTH+1 )'(1);

//first_valid_word = 1 only at the begining
//(when FIFO received first valid word, this word will be read out from fifo, when rdreq_i is asserted, fifo will read out next word )
assign first_valid_word = ( ( usedw_o == (AWIDTH+1)'(1) ) && ( valid_wr ) && ( !empty_o ) ) ? (AWIDTH)'(1): (AWIDTH)'(0);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      usedw_o <= (AWIDTH+1)'(0);
    else
      if( valid_wr && !valid_rd )
        usedw_o <= usedw_o + (AWIDTH+1)'(1);
      else if( valid_rd && !valid_wr )
        usedw_o <= usedw_o - (AWIDTH+1)'(1);
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      if (REGISTER_OUTPUT == "ON")
          q_o <= (DWIDTH)'(0);
      else
          q_o <= {DWIDTH{1'bX}};
  end

always_comb
  begin
    if( SHOWAHEAD == "ON" )
      begin
        rd_addr_mem  = next_rdaddr[AWIDTH-1:0]-first_valid_word;
        valid_rd_mem = valid_rd || first_valid_word == (AWIDTH)'(1);
      end
    else
      begin
        rd_addr_mem  = rd_addr[AWIDTH-1:0];
        valid_rd_mem = valid_rd;
      end
  end

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );
assign empty_o        = ( wr_addr == rd_addr );
assign full_o         = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                        ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule
