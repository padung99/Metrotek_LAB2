module fifo #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 8,
  parameter SHOWAHEAD          = "ON",
  parameter ALMOST_FULL_VALUE  = 2**AWIDTH-3,
  parameter ALMOST_EMPTY_VALUE = 3,
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

(* ramstyle = "M10K" *) logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];//Inferring mem to block RAM type M10K

logic              valid_rd;
logic              valid_wr;

logic [AWIDTH-1:0] wr_delay_1_clk;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      wr_addr <= (AWIDTH+1)'(0);
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
      empty_o <= 1'b1;
    else
      begin
        if( valid_rd )
          begin
            if( usedw_o == 1 )
              empty_o <= 1'b1;
            else
              empty_o <= 1'b0;
          end
        else
          begin
            if( rd_addr[AWIDTH-1:0] == wr_delay_1_clk )
              empty_o <= 0;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( valid_rd )
      q_o <= mem[next_rdaddr[AWIDTH-1:0]];
    
    if( rd_addr[AWIDTH-1:0] == wr_delay_1_clk )
      q_o <= mem[wr_delay_1_clk];
  end

always_ff @( posedge clk_i )
  begin
    if( valid_wr )
      wr_delay_1_clk <= wr_addr[AWIDTH-1:0];
  end

always_ff @( posedge clk_i )
  begin
    if( valid_wr )
      mem[wr_addr[AWIDTH-1:0]] <= data_i;
  end

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );
assign full_o         = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                        ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule