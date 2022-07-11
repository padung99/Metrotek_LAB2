module Sorting #(
  parameter DWIDTH      = 16,
  parameter MAX_PKT_LEN = 16
) (
  input  logic              clk_i,
  input  logic              srst_i,

  input  logic [DWIDTH-1:0] snk_data_i,
  input  logic              snk_startofpacket_i,
  input  logic              snk_endofpacket_i,
  input  logic              snk_valid_i,
  output logic              snk_ready_o,

  output logic [DWIDTH-1:0] src_data_o,
  output logic              src_startofpacket_o,
  output logic              src_endofpacket_o,
  output logic              src_valid_o,
  input  logic              src_ready_i
);

localparam AWIDTH = $clog2(MAX_PKT_LEN) + 1 ;

logic [AWIDTH-1:0] wr_addr;
logic [AWIDTH-1:0] rd_addr;

logic              sending;
// logic              delay_sending;

logic              start_sending_out;

integer            word_received;
logic              delay_valid_output;
logic [DWIDTH-1:0] sort_mem [MAX_PKT_LEN-1:0];


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        // src_data_o <= '0;
        wr_addr       <= '0;
        snk_ready_o <= 1'b1;
      end
    else
      begin
        if( snk_valid_i )
          wr_addr <= wr_addr + 1;
        if( snk_valid_i && snk_startofpacket_i )
          begin
            wr_addr <= (AWIDTH)'(1);
            rd_addr <= (AWIDTH)'(0);
          end
        if( snk_valid_i && snk_endofpacket_i )
          begin
            wr_addr <= (AWIDTH)'(0);
            word_received <= wr_addr;
          end
        
      end
  end 

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 && rd_addr != word_received &&  src_ready_i )
      rd_addr <= rd_addr + 1;
  end

always_ff @( posedge clk_i )
  begin
    if( snk_valid_i && snk_startofpacket_i )
      begin
        sending <= 1'b1;
        // delay_sending <= 1'b0;
        // delay_valid_output <= 1'b0;
      end
    else if( snk_valid_i && snk_endofpacket_i )
      sending <= 1'b0;
      // delay_sending <= 1'b1;    
  end

// always_ff @( posedge clk_i )
//   begin
//     if( delay_sending )
//       sending <= 1'b0;
//   end


always_ff @( posedge clk_i )
  begin
    if( snk_valid_i && ( wr_addr <= MAX_PKT_LEN -1 ) )
      sort_mem[wr_addr] <= snk_data_i;
  end
always_ff @( posedge clk_i )
  begin
    if( sending == 1'b0 )
      start_sending_out <= 1'b1;
    if( snk_valid_i && snk_startofpacket_i )
      start_sending_out <= 1'b0;  
  end

always_ff @( posedge clk_i )
  begin
    if( ( start_sending_out == 1'b1 ) )
      begin
        if( rd_addr == word_received && src_endofpacket_o != 1'b1 )
          delay_valid_output <= 1'b1; /////////////////
        else if( src_endofpacket_o == 1'b1 )
          delay_valid_output <= 1'b0;
      end
    if( snk_valid_i && snk_startofpacket_i )
      start_sending_out <= 1'b0;
  end
//Sorting 
always_comb
  begin
    if( sending == 1'b0 )
      begin
        // start_sending_out = 1'b1;
        //bubble sort
        for( int i = 0; i <= word_received; i++ )
          begin
            for( int j = 0; j < word_received - i; j++ ) ///
              begin
                if( sort_mem[j] > sort_mem[j+1] )
                  begin
                    logic [DWIDTH-1:0] tmp;
                    tmp           = sort_mem[j];
                    sort_mem[j]   = sort_mem[j+1];
                    sort_mem[j+1] = tmp;
                  end
              end
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( snk_endofpacket_i == 1'b1 )
      snk_ready_o <= 1'b0;
    
    if( src_endofpacket_o == 1'b1 )
      snk_ready_o <= 1'b1;
  end

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 )
      begin
        // snk_ready_o <= 1'b0;

        if( rd_addr == 0 )
          src_startofpacket_o <= 1'b1;
        if( rd_addr == 1 )
          src_startofpacket_o <= 1'b0;
        if( rd_addr == word_received )
          begin
            src_endofpacket_o <= 1'b1;
            // delay_valid_output <= 1'b1;
          end
        src_data_o <= sort_mem[rd_addr];
        src_valid_o <= 1'b1;
      end
  end 

always_ff @( posedge clk_i )
  begin
    if( delay_valid_output )
      begin
        src_valid_o <= 1'b0;
        src_endofpacket_o <= 1'b0;
      end
  end

endmodule
