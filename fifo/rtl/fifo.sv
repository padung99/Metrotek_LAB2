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
  output logic [AWIDTH:0]   usedw_o,

  output logic              almost_full_o,  
  output logic              almost_empty_o
);

logic [AWIDTH:0]   wr_addr;
logic [AWIDTH:0]   rd_addr;
logic [AWIDTH:0]   next_rdaddr;
logic [AWIDTH:0]   next_wraddr;

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

assign valid_rd = rdreq_i  && !empty_o;
assign valid_wr = wrreq_i  && !full_o;
assign next_rdaddr = rd_addr + ( AWIDTH+1 )'(1);
assign next_wraddr = wr_addr + ( AWIDTH+1 )'(1);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      usedw_o <= (AWIDTH+1)'(0);
    else
      if( valid_wr && !valid_rd )
        usedw_o <= usedw_o + 1;
      else if( valid_rd && !valid_wr )
        usedw_o <= usedw_o - 1;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      if (REGISTER_OUTPUT == "ON")
          q_o <= (DWIDTH)'(0);
      else
          q_o <= {DWIDTH{1'bX}};
  end

always_ff @( posedge clk_i )
  begin
    if( valid_rd )
      begin
        if( SHOWAHEAD == "ON" )
          q_o <= mem[next_rdaddr[AWIDTH-1:0]];
        else
          q_o <= mem[rd_addr[AWIDTH-1:0]];
        // if( rd_addr[AWIDTH-1:0] >=  (1<<AWIDTH )-1 ) //rd_addr[AWIDTH-1:0] = 1111
        //   begin
        //     if (SHOWAHEAD == "ON")
        //       begin
        //         if ( ( usedw_o == 1 ) && !full_o )
        //           begin
        //             if ( valid_wr )
        //               q_o <= data_i; //Ouput the first word of valid data
        //             else
        //               q_o <= (DWIDTH)'(0);
        //           end
        //         else
        //           // q_o <= mem[rd_addr[AWIDTH-1:0]]; /////////////q_o <= mem[0]
        //           q_o <= mem[0];
        //       end
        //     else
        //       q_o <= mem[next_rdaddr[AWIDTH-1:0]];
        //   end
        // else
        //   begin
        //     if( SHOWAHEAD == "ON" )
        //       begin
        //         if( ( usedw_o == 1 ) && !full_o )
        //           q_o <= {DWIDTH{1'bX}};
        //         else
        //           q_o <= mem[next_rdaddr[AWIDTH-1:0]]; //////////
        //       end
        //     else
        //       q_o <= mem[rd_addr[AWIDTH-1:0]];
        //   end
      end
    else
      if( SHOWAHEAD == "ON" )
        if( valid_wr && !empty_o )
          q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
      
  end

always_ff @( posedge clk_i )
  begin
    if( valid_wr )
      begin
        mem[wr_addr[AWIDTH-1:0]] <= data_i;
        // if( SHOWAHEAD == "ON" )
        //   if ((!empty_o) && (!valid_rd))
        //     q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
      end
  end

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );
assign empty_o        = ( wr_addr == rd_addr );
assign full_o         = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                        ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule
