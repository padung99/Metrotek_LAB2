module fifo #(
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
  output logic [AWIDTH:0] usedw_o,

  output logic              almost_full_o,  
  output logic              almost_empty_o
);

logic [AWIDTH:0]   wr_addr;
logic [AWIDTH:0]   rd_addr;

logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];

int                first_write;
logic              valid_rd;
logic              valid_wr;
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      wr_addr <= ( AWIDTH+1 )'(0);
    else
      if( valid_wr ) //
        wr_addr <= wr_addr + ( AWIDTH+1 )'(1);
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      rd_addr <= (AWIDTH+1)'(0);
    else
      if( valid_rd )
        rd_addr <= rd_addr + ( AWIDTH+1 )'(1);
  end

assign valid_rd = rdreq_i  && !empty_o;
assign valid_wr = wrreq_i  && !full_o;

always_ff @( posedge clk_i )
  begin
    if( srst_i || first_write == 0)
      usedw_o <= (AWIDTH+1)'(0);
    else
      if( valid_wr && !valid_rd )
        usedw_o <= usedw_o + 1;
      else if( valid_rd && !valid_wr )
        usedw_o <= usedw_o - 1;
  end

always_comb
  begin
    if( wrreq_i == 1'b1 )
      first_write = first_write + 1; 
  end

always_ff @( posedge clk_i )
  begin
    if( SHOWAHEAD == "ON" )
      begin
        if( usedw_o == 1 && !full_o )
          begin
              if (valid_wr)
                  q_o <= data_i;
              else
                  q_o <= 0;
          end 
        else
          q_o <= mem[0];
      end
    else
      q_o <= mem[rd_addr[AWIDTH-1:0]];
      
  end

always_ff @( posedge clk_i )
  begin
    if( SHOWAHEAD == "ON" )
      if ((!empty_o) && (!valid_rd))
        begin
            q_o <= mem_data[rd_addr[AWIDTH-1:0]];
        end
  end

always_ff @( posedge clk_i )
  begin
    if( rdreq_i )
      q_o <= mem[rd_addr[AWIDTH-1:0]];
  end

always_ff @( posedge clk_i )
  begin
    if( wrreq_i )
      mem[wr_addr[AWIDTH-1:0]] <= data_i;
  end

assign empty_o = ( wr_addr == rd_addr );
assign full_o  = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                 ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule
