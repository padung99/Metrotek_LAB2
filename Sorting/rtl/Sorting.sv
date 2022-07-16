module Sorting #(
  parameter DWIDTH      = 16,
  parameter MAX_PKT_LEN = 1000
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
parameter MAX_INDEX = (MAX_PKT_LEN >> 1)+1;

logic [AWIDTH-1:0] wr_addr;
logic [AWIDTH-1:0] rd_addr;

logic              sending;

logic              start_sending_out;

integer word_received;
// integer first_loop_ind;
// logic [DWIDTH-1:0] tmp;

logic [DWIDTH-1:0] sort_mem [MAX_PKT_LEN+2:0];

integer index;
int     cnt;
integer i;
integer tmp_i;
integer tmp_i1;
// integer index;

logic [AWIDTH-1:0] addr_a;
logic [AWIDTH-1:0] addr_b;

logic [AWIDTH-1:0] tmp_addr_a;
logic [AWIDTH-1:0] tmp_addr_b;

logic [DWIDTH-1:0] data_a;
logic [DWIDTH-1:0] data_b;

logic [DWIDTH-1:0] tmp_data_a;
logic [DWIDTH-1:0] tmp_data_b;


logic              rd_en_a;
logic              rd_en_b;

logic              wr_en_a;
logic              wr_en_b;

logic [DWIDTH-1:0] q_a;
logic [DWIDTH-1:0] q_b;

logic [DWIDTH-1:0] q_tmp_a;
logic [DWIDTH-1:0] q_tmp_b;

logic [MAX_PKT_LEN-1:0] [AWIDTH-1:0] tmp_index;


enum logic [2:0] {
  IDLE_S,
  WRITE_S,
  // SORT_COMPARE_S,
  SORT_READ_S,
  SORT_WRITE_S,
  SORT_READ_NEXT_S,
  // SORT_INCREASE_S,
  // SORT_DELAY_S,
  READ_S
} state, next_state;

mem2 #(
  .DWIDTH_MEM ( DWIDTH ),
  .DWIDTH_MAX_PKT ( AWIDTH )
) mem2_inst (
	.address_a( addr_a ),
	.address_b( addr_b ),
	.clock( clk_i ),
	.data_a( data_a ),
	.data_b( data_b ),
	.wren_a( wr_en_a ),
	.wren_b( wr_en_b ),
	.q_a( q_a ),
	.q_b( q_b )
);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        wr_addr       <= '0;
      end
    else
      begin
        if( snk_valid_i )
          wr_addr <= wr_addr + (AWIDTH)'(1);
        if( snk_valid_i && snk_startofpacket_i )
          begin
            wr_addr <= (AWIDTH)'(1);
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
    if( start_sending_out == 1'b1 &&  src_ready_i )
      rd_addr <= rd_addr + (AWIDTH)'(1);

    if( snk_valid_i && snk_startofpacket_i )
      begin
        rd_addr <= (AWIDTH)'(0);
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

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      start_sending_out <= 1'b0;
    else
      begin
        if( rd_addr > word_received )
          start_sending_out <= 1'b0;
        // if( snk_valid_i && snk_startofpacket_i )
        //   start_sending_out <= 1'b0;
        // if( src_endofpacket_o )
        //   start_sending_out <= 1'b0;
        if( cnt == word_received+1 ) /////////
          start_sending_out <= 1'b1;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= IDLE_S;
    else
      state <= next_state;
  end

always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S:
        begin
          if( snk_valid_i && ( wr_addr < MAX_PKT_LEN-1 ) )
            next_state = WRITE_S;
        end
      
      WRITE_S:
        begin
          if( sending == 1'b0 && start_sending_out != 1'b1 )
            begin
              if( cnt <= word_received ) //////////////
                begin
                  next_state = SORT_READ_S;
                end
            end

          if( start_sending_out == 1'b1 )
            begin
              if( rd_addr <= word_received )
                next_state = READ_S;
            end
        end

      SORT_READ_S:
        begin
          next_state = SORT_WRITE_S;
        end
      
      SORT_WRITE_S:
        begin
          next_state = SORT_READ_NEXT_S;
        end

      SORT_READ_NEXT_S:
        begin
          if( i <=  word_received + (cnt % 2) )
            next_state = SORT_WRITE_S;
          else
            next_state = SORT_READ_S;
          
          if( cnt == word_received && i > cnt )
            next_state = READ_S;
        end
      READ_S:
        begin
          if( src_endofpacket_o )
            next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i || snk_valid_i && snk_startofpacket_i )
      cnt <= 0;

    if( state == IDLE_S )
      begin
        wr_en_a <= 1;
        addr_a  <= wr_addr;
        data_a  <= snk_data_i;
        cnt <= 0;
        index <= 0;
      end
    else if( state == WRITE_S )
      begin
        if( snk_ready_o == 1'b1 )
          begin
            wr_en_a <= 1;
            addr_a  <= wr_addr;
            data_a  <= snk_data_i;
          end

        if( snk_ready_o == 1'b0 )
          begin
            wr_en_a <= 1'b0;
            wr_en_b <= 1'b0;
          end
      end
    else if( state == SORT_READ_S )
      begin
        i <= cnt % 2;
        wr_en_a <= 1'b0;
        addr_a  <= cnt % 2;
        tmp_i <= cnt % 2;
        tmp_addr_a <= cnt % 2;
        tmp_data_a <= 0;


        wr_en_b <= 1'b0;
        addr_b  <= ( cnt % 2 ) + 1;
        tmp_i1 <= ( cnt % 2 ) + 1;
        tmp_addr_b <= cnt % 2 + 1;
        tmp_data_b <= 0;

        // $display("[%d] %d, [%d] %d",addr_a, q_a, addr_b, q_b );
      end
    else if( state == SORT_WRITE_S )
      begin
        if( tmp_data_a > tmp_data_b )
          begin
            wr_en_a <= 1'b1;
            addr_a  <= tmp_i;
            data_a  <= tmp_data_b;

            wr_en_b <= 1'b1;
            addr_b  <= tmp_i1;
            data_b  <= tmp_data_a;
          end

        i <= i + 2;

      end
    else if( state == SORT_READ_NEXT_S )
      begin
        wr_en_a <= 1'b0;
        addr_a  <= i;
        if( i <= word_received + (cnt % 2) )
          begin
            tmp_addr_a <= i;
            tmp_i <= tmp_addr_a;
            tmp_data_a <= q_a;
          end

        wr_en_b <= 1'b0;
        addr_b  <= i+1;

        if( i <= word_received + (cnt % 2))
          begin
            tmp_addr_b <= i+1;
            tmp_i1 <= tmp_addr_b;
            tmp_data_b <= q_b;
          end

        if( i > word_received + (cnt % 2)) ///////////////
          cnt <= cnt + 1;
      end

    else if( state == READ_S )
      begin
        if( start_sending_out == 1'b1 )
          begin
            if( rd_addr <= word_received +2)
              begin
                wr_en_a    <= 1'b0;
                addr_a     <= rd_addr;
                src_data_o <= q_a;
              end
          end
      end


  end

// always_ff @( posedge clk_i )
//   begin
//     if( srst_i || snk_valid_i && snk_startofpacket_i )
//       cnt <= 0;
//   end

// always_ff @( posedge clk_i )
//   begin
//     if( srst_i || snk_valid_i && snk_startofpacket_i )
//       cnt <= 0;
//     else
//       begin
//         if( sending == 1'b0 && start_sending_out != 1'b1 )
//           begin
//             if( cnt <= MAX_PKT_LEN )
//               begin
//                 for( int i = cnt % 2; i <= MAX_PKT_LEN; i=i+2 )
//                   if( sort_mem[i] > sort_mem[i+1] )
//                     begin
//                       sort_mem[i] <= sort_mem[i+1];
//                       sort_mem[i+1] <= sort_mem[i];
//                     end

//                 cnt <= cnt + 1;
//               end
//           end
//       end

//     if( snk_valid_i && ( wr_addr < MAX_PKT_LEN-1 ) )
//       sort_mem[wr_addr] <= snk_data_i;
    
//     if( start_sending_out == 1'b1 )
//       begin
//         if( rd_addr <= word_received )
//           src_data_o <= sort_mem[rd_addr];
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
          if( rd_addr == 0 + 2 )
            src_startofpacket_o <= 1'b1;
          if( rd_addr == 1 + 2 )
            src_startofpacket_o <= 1'b0;
        end
  end 

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_endofpacket_o <= 1'b0;
    else
      if( start_sending_out == 1'b1 )
        begin
          if( rd_addr == word_received + 2 )
            src_endofpacket_o <= 1'b1;
          if( rd_addr > word_received + 2 )
            src_endofpacket_o <= 1'b0;
        end
  end

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 && rd_addr == 2 )
      begin
        src_valid_o <= 1'b1;
      end

    if( rd_addr > word_received + 2)
      begin
        src_valid_o <= 1'b0;
      end
  end

endmodule