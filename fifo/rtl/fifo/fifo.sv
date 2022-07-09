module fifo #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 4,
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
// logic [AWIDTH:0]   first_valid_word;
// logic  [DWIDTH-1:0] q_o;
(* ramstyle = "M10K" *) logic [DWIDTH-1:0] mem [2**AWIDTH-1:0];//Inferring mem to block RAM type M10K

logic              valid_rd;
logic              valid_wr;
// logic              top_data_fifo;;

// logic empty_latency1; 
// logic empty_latency2; 

logic [AWIDTH-1:0] wr_delay; 
logic [AWIDTH-1:0] write_latency2;

logic [2**AWIDTH-1:0] data_received;
logic [2**AWIDTH-1:0] data_shown;

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
    // if( SHOWAHEAD == "ON" )
    //   rd_addr <= (1<<AWIDTH) - 1 ;
    // else
      rd_addr <= (AWIDTH+1)'(0);
    else
      if( valid_rd )
        rd_addr <= next_rdaddr;
  end

assign valid_rd         = rdreq_i  && !empty_o;
assign valid_wr         = wrreq_i  && !full_o;
assign next_rdaddr      = rd_addr + ( AWIDTH+1 )'(1);
assign next_wraddr      = wr_addr + ( AWIDTH+1 )'(1);
// assign top_data_fifo    = ( rd_addr[AWIDTH-1:0] == (1<<AWIDTH) - 1 ) && ( usedw_o == 1 );
//first_valid_word = 1 only at the begining
//(when FIFO received first valid word, this word will be read out from fifo, when rdreq_o_i is asserted, fifo will read out next word )
// assign first_valid_word = ( ( usedw_o == (AWIDTH+1)'(1) ) &&
//                             ( valid_wr == 1'b1 ) &&
//                             ( empty_o == 1'b0 ) &&
//                             ( wr_addr[AWIDTH-1:0] == 1 ) ? (AWIDTH)'(1): (AWIDTH)'(0) );

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
    if( valid_rd )
      begin
        if( usedw_o == 1 )
          empty_o <= 1'b1;
        else
          begin
            if (data_shown[wr_delay] == 1'b0)
              empty_o <= 1'b0;
          end
      end
    else
      begin
        if (data_shown[wr_delay]==1'b1)
          begin
            if ((rd_addr[AWIDTH-1:0] == wr_delay))
              empty_o <= 0;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( valid_rd )
      begin
        if ((wr_delay == next_rdaddr[AWIDTH-1:0]) || (data_received[next_rdaddr[AWIDTH-1:0]] == 1'b1))
          begin
            if (data_shown[next_rdaddr[AWIDTH-1:0]] == 1'b1) //Check if data has been writen to mem
              q_o <= mem[next_rdaddr[AWIDTH-1:0]];
          end     
      end

    if (data_shown[wr_delay]==1'b1)
      begin
        if ((rd_addr[AWIDTH-1:0] == wr_delay))
              begin
                // if (wr_delay !== 1'bx)
                //   begin
                    q_o <= mem[wr_delay];
                    // data_shown[wr_delay] <= 1'b0;
                    // data_received[wr_delay] <= 1'b0;

                    // if (!valid_rd)
                    //     // empty_o <= empty_latency1;
                    //     empty_o <= 0;
                  // end
              end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( valid_rd )
      begin
        if ((wr_delay == next_rdaddr[AWIDTH-1:0]) || (data_received[next_rdaddr[AWIDTH-1:0]] == 1'b1))
          begin
            if (data_shown[next_rdaddr[AWIDTH-1:0]] == 1'b1) //Check if data has been writen to mem
              begin
                data_shown[next_rdaddr[AWIDTH-1:0]] <= 1'b0;
                data_received[next_rdaddr[AWIDTH-1:0]] <= 1'b0;
              end
          end          
      end

      if( valid_wr )
        begin
          data_shown[wr_addr[AWIDTH-1:0]] <= 1'b1;
          data_received[wr_addr[AWIDTH-1:0]] <= 1'bx;
        end

      if (write_latency2 !== wr_delay)
        data_received[wr_delay] <= 1'b1; ///////////////

      if (data_shown[wr_delay]==1'b1)
        begin
          if ((rd_addr[AWIDTH-1:0] == wr_delay))
              begin
                // if (wr_delay !== 1'bx)
                //   begin
                    // q_o <= mem[wr_delay];
                    data_shown[wr_delay] <= 1'b0; /////////////////
                    data_received[wr_delay] <= 1'b0; //////////////

                    // if (!valid_rd)
                    //     // empty_o <= empty_latency1;
                    //     empty_o <= 0;
                  // end
              end
        end
      
  end

always_ff @( posedge clk_i )
  begin
    if( valid_wr )
      begin
        mem[wr_addr[AWIDTH-1:0]] <= data_i;
        // empty_latency1 <= 1'b0;
        wr_delay <= wr_addr[AWIDTH-1:0];
        // data_shown[wr_addr[AWIDTH-1:0]] <= 1'b1;
        // data_received[wr_addr[AWIDTH-1:0]] <= 1'bx;
      end
  end

always_ff @( posedge clk_i )
  begin
    write_latency2 <= wr_delay;
    // if (write_latency2 !== wr_delay)
    //   data_received[wr_delay] <= 1'b1; ///////////////

    // if (data_shown[wr_delay]==1'b1)
      // begin
      //   if ((rd_addr[AWIDTH-1:0] == wr_delay))
      //     begin
      //       // if (wr_delay !== 1'bx)
      //       //   begin
      //           // q_o <= mem[wr_delay];
      //           // data_shown[wr_delay] <= 1'b0; /////////////////
      //           // data_received[wr_delay] <= 1'b0; //////////////

      //           // if (!valid_rd)
      //           //     // empty_o <= empty_latency1;
      //           //     empty_o <= 0;
      //         // end
      //     end
      // end 
  end

assign almost_empty_o = ( usedw_o < ALMOST_EMPTY_VALUE );
assign almost_full_o  = ( usedw_o >= ALMOST_FULL_VALUE );
// assign empty_o        = ( wr_addr == rd_addr );
assign full_o         = ( wr_addr[AWIDTH-1:0] == rd_addr[AWIDTH-1:0] ) &&
                        ( wr_addr[AWIDTH] != rd_addr[AWIDTH] );

endmodule
