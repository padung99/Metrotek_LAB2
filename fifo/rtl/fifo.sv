module fifo #(
  parameter DWIDTH             = 10,
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
logic [AWIDTH:0]   first_addr;

(* ramstyle = "M10K" *) logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];

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

assign valid_rd         = rdreq_i  && !empty_o;
assign valid_wr         = wrreq_i  && !full_o;
assign next_rdaddr      = rd_addr + ( AWIDTH+1 )'(1);
assign next_wraddr      = wr_addr + ( AWIDTH+1 )'(1);
assign first_valid_word = ( ( usedw_o == 1 ) && ( valid_wr ) && ( !empty_o ) ) ? (AWIDTH)'(1): (AWIDTH)'(0);
assign first_addr       = next_rdaddr - first_valid_word;
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

always_ff @( posedge clk_i )
  begin
    if( SHOWAHEAD == "ON")
      begin
        if( valid_rd || first_valid_word == (AWIDTH)'(1) )
          q_o <= mem[next_rdaddr[AWIDTH-1:0]-first_valid_word];

        // if( !valid_rd && valid_wr && !empty_o )
        // if( valid_wr && !empty_o &&  !rdreq_i )
        //   q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
      end
    // else if( SHOWAHEAD == "ON" && usedw_o == 1 )
    //   if( valid_wr && !empty_o )
    //     q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
    else
      if( valid_rd )
        q_o <= mem[rd_addr[AWIDTH-1:0]];

  end

// always_ff @( posedge clk_i )
//   begin
//     if( valid_rd )
//       begin
//         if( SHOWAHEAD == "ON" )
//           q_o <= mem[next_rdaddr[AWIDTH-1:0]];
//         // else
//         //   q_o <= mem[rd_addr[AWIDTH-1:0]];
//       end
//     else if( !valid_rd && SHOWAHEAD != "ON")
//       begin
//         q_o <= mem[rd_addr[AWIDTH-1:0]];
//       end
//     else
//       if( SHOWAHEAD == "ON" )
//         if( valid_wr && !empty_o )
//           q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
      
//   end

always_ff @( posedge clk_i )
  begin
    if( valid_wr )
      mem[wr_addr[AWIDTH-1:0]] <= data_i;
      // if( SHOWAHEAD == "ON" )
      //   if( valid_rd && !empty_o )
      //     q_o <= mem[rd_addr[AWIDTH-1:0]]; //Ouput the first word of valid data
  end

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );
assign empty_o        = ( wr_addr == rd_addr );
assign full_o         = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                        ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule
