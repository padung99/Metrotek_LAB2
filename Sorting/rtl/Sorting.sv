module Sorting #(
  parameter DWIDTH      = 16,
  parameter MAX_PKT_LEN = 13
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

parameter AWIDTH = $clog2(MAX_PKT_LEN) + 1 ;

logic [AWIDTH-1:0] wr_addr;
logic [AWIDTH-1:0] rd_addr;

logic              sending;
// logic              delay_sending;

logic              start_sending_out;

integer word_received;
integer first_loop_ind;
logic [DWIDTH-1:0] tmp;
// logic              delay_valid_output;
logic [DWIDTH-1:0] sort_mem [MAX_PKT_LEN+2:0];

integer index;
integer cnt;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        wr_addr       <= '0;
        // index <= 0;
        // cnt <= 0;
        // snk_ready_o <= 1'b1;
      end
    else
      begin
        if( snk_valid_i )
          wr_addr <= wr_addr + (AWIDTH)'(1);
        if( snk_valid_i && snk_startofpacket_i )
          begin
            wr_addr <= (AWIDTH)'(1);
            // rd_addr <= (AWIDTH)'(0);
          end
        if( snk_valid_i && snk_endofpacket_i )
          begin
            wr_addr <= (AWIDTH)'(0);
            word_received <= wr_addr;
            // first_loop_ind <= wr_addr;
          end
        
      end
  end 

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 &&  src_ready_i )
      rd_addr <= rd_addr + (AWIDTH)'(1);

    if( snk_valid_i && snk_startofpacket_i )
      begin
        rd_addr <= (AWIDTH)'(0);
        // cnt <= 0;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( snk_valid_i && snk_startofpacket_i )
      begin
        sending <= 1'b1;
      end
    else if( snk_valid_i && snk_endofpacket_i )
      sending <= 1'b0;
  
  end

// always_ff @( posedge clk_i )
//   begin
//     if( snk_valid_i && ( wr_addr < MAX_PKT_LEN-1 ) )
//       sort_mem[wr_addr] <= snk_data_i;
//   end

always_ff @( posedge clk_i )
  begin
    // if( sending == 1'b0 )
    //   start_sending_out <= 1'b1;
    if( rd_addr > word_received )
      start_sending_out <= 1'b0;
    if( snk_valid_i && snk_startofpacket_i )
      start_sending_out <= 1'b0;
    if( src_endofpacket_o )
      start_sending_out <= 1'b0;
    if( cnt == MAX_PKT_LEN )
      start_sending_out <= 1'b1;
  end

// always_ff @( posedge clk_i )
//   begin
//     if( snk_valid_i && snk_startofpacket_i )
//       start_sending_out <= 1'b0;
//   end

//Sorting 
// always_ff @( posedge clk_i )
//   begin
//     if( sending == 1'b0 )
//       begin
//         //bubble sort
//         for( int i = 0;  i <= MAX_PKT_LEN; i++ )
//           begin
//             for( int j = 0; j < MAX_PKT_LEN - i; j++ ) ///
//               begin
//                 if( sort_mem[j] > sort_mem[j+1] )
//                   begin
//                     // tmp           = sort_mem[j];
//                     sort_mem[j]   <= sort_mem[j+1];
//                     sort_mem[j+1] <= sort_mem[j];
//                   end
//               end
//           end
//       end
    
//   end

// always_ff @( posedge clk_i )
//   begin
//     if( first_loop_ind > 0 )
//       begin
//         if( index < word_received )
//           begin
//             if( sort_mem[index] > sort_mem[index+1] )
//               begin
//                 sort_mem[index]   <= sort_mem[index+1];
//                 sort_mem[index+1] <= sort_mem[index];
//               end
//             index <= index + 1;
//           end
//         else
//           begin
//             first_loop_ind <= first_loop_ind - 1;
//             index <= 0;
//           end
//       end
//     else if( first_loop_ind == 0 && src_endofpacket_o != 1'b1 )
//       begin
//         start_sending_out <= 1'b1;
//         // rd_addr <= 0;
//       end
//   end

always_ff @( posedge clk_i )
  begin
    if( srst_i || snk_valid_i && snk_startofpacket_i )
      cnt <= 0;
    else
      begin
        if( sending == 1'b0 && start_sending_out != 1'b1 )
          begin
            if( cnt <= MAX_PKT_LEN )
              begin
                if( cnt % 2 == 0 )
                  begin
                    for( int i = 0; i <= MAX_PKT_LEN; i=i+2 )
                      if( sort_mem[i] > sort_mem[i+1] )
                        begin
                          sort_mem[i] <= sort_mem[i+1];
                          sort_mem[i+1] <= sort_mem[i];
                        end
                  end
                else
                  begin
                    for( int i = 1; i <= MAX_PKT_LEN; i=i+2 )
                      if( sort_mem[i] > sort_mem[i+1] )
                        begin
                          sort_mem[i] <= sort_mem[i+1];
                          sort_mem[i+1] <= sort_mem[i];
                        end
                  end
                cnt <= cnt + 1;
              end
          end
        // else if( snk_valid_i && snk_startofpacket_i )
        //   cnt <= 0;
      end

    if( snk_valid_i && ( wr_addr < MAX_PKT_LEN-1 ) )
      sort_mem[wr_addr] <= snk_data_i;
    
    if( start_sending_out == 1'b1 )
      begin
        if( rd_addr <= word_received )
          src_data_o <= sort_mem[rd_addr];
      end

    // if( srst_i || snk_valid_i && snk_startofpacket_i )
    //   cnt <= 0;
      
    // if( snk_valid_i && snk_startofpacket_i )
    //   begin
    //     // rd_addr <= (AWIDTH)'(0);
    //     cnt <= 0;
    //   end

  end

// always_ff @( posedge clk_i )
//   begin
//     if( cnt == word_received )
//       begin
//         start_sending_out <= 1'b1;
//       end
//   end 

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      snk_ready_o <= 1'b1;
    else
      begin
        if( snk_endofpacket_i == 1'b1 )
          snk_ready_o <= 1'b0;
        
        if( src_endofpacket_o == 1'b1 )
          snk_ready_o <= 1'b1;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_startofpacket_o <= 1'b0;
    else
      if( start_sending_out == 1'b1 )
        begin
          if( rd_addr == 0 )
            src_startofpacket_o <= 1'b1;
          if( rd_addr == 1 )
            src_startofpacket_o <= 1'b0;
        end
  end 

// always_ff @( posedge clk_i )
//   begin
//     if( start_sending_out == 1'b1 )
//       begin
//         if( rd_addr <= word_received )
//           src_data_o <= sort_mem[rd_addr];
//       end
//   end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_endofpacket_o <= 1'b0;
    else
      if( start_sending_out == 1'b1 )
        begin
          if( rd_addr == word_received )
            src_endofpacket_o <= 1'b1;
          if( rd_addr > word_received  )
            src_endofpacket_o <= 1'b0;
        end
      // if( rd_addr > word_received  )
      //   src_endofpacket_o <= 1'b0;
  end

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 )
      begin
        src_valid_o <= 1'b1;
      end

    if( rd_addr > word_received )
      begin
        src_valid_o <= 1'b0;
      end
  end

endmodule