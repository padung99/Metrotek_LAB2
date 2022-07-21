module Sorting #(
  parameter DWIDTH      = 8,
  parameter MAX_PKT_LEN = 250
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

localparam AWIDTH = $clog2(MAX_PKT_LEN);

logic [AWIDTH-1:0] wr_addr;
logic [AWIDTH:0] rd_addr;

logic              sending;

logic              start_sending_out;

logic              detect_only_1_elm;

logic [AWIDTH-1:0] addr_a;
logic [AWIDTH-1:0] addr_b;

logic [AWIDTH-1:0] tmp_addr_a;
logic [AWIDTH-1:0] tmp_addr_b;

logic [AWIDTH-1:0] data_received;
logic [AWIDTH:0]   cnt;
logic [AWIDTH:0]   i;
logic [AWIDTH:0]   tmp_i0;
logic [AWIDTH:0]   tmp_i1;

logic [DWIDTH-1:0] data_a;
logic [DWIDTH-1:0] data_b;

logic [DWIDTH-1:0] tmp_data_a;
logic [DWIDTH-1:0] tmp_data_b;


logic              wr_en_a;
logic              wr_en_b;

logic [DWIDTH-1:0] q_a;
logic [DWIDTH-1:0] q_b;

logic              last_sort;
logic              delay_odd_cycle;
logic              delay_even_cycle;
logic              end_writing;
logic              begin_writing;
logic              data_received_even;
logic              data_received_odd;

enum logic [2:0] {
  IDLE_S,
  WRITE_S,
  SORT_READ_S,
  SORT_WRITE_S,
  SORT_READ_NEXT_S,
  READ_S
} state, next_state;

mem2 #(
  .DWIDTH_MEM     ( DWIDTH  ),
  .DWIDTH_MAX_PKT ( AWIDTH  )
) mem2_inst (
	.address_a      ( addr_a  ),
	.address_b      ( addr_b  ),
	.clock          ( clk_i   ),
	.data_a         ( data_a  ),
	.data_b         ( data_b  ),
	.wren_a         ( wr_en_a ),
	.wren_b         ( wr_en_b ),
	.q_a            ( q_a     ),
	.q_b            ( q_b     )
);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      wr_addr <= '0;
    else
      begin
        if( snk_valid_i )
          wr_addr <= wr_addr + (AWIDTH)'(1);

        if( snk_valid_i && snk_startofpacket_i )
          wr_addr <= (AWIDTH)'(1);

        if( snk_valid_i && snk_endofpacket_i )
          begin
            wr_addr       <= (AWIDTH)'(0);
            data_received <= wr_addr;
          end
        
      end
  end 

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 )
      rd_addr <= rd_addr + (AWIDTH)'(1);

    if( snk_valid_i && snk_startofpacket_i )
      rd_addr <= (AWIDTH)'(0);

      if( detect_only_1_elm == 1'b1 )
        begin
          if( rd_addr == 2 )
            rd_addr <= 0; //Reset rd addr
        end
  end

always_ff @( posedge clk_i )
  begin
    if( snk_valid_i && snk_startofpacket_i )
      sending <= 1'b1;
    else if( snk_valid_i && snk_endofpacket_i )
      sending <= 1'b0;
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      start_sending_out <= 1'b0;
    else
      begin
        if( rd_addr > data_received )  /////////
          start_sending_out <= 1'b0;

        if( cnt >= data_received+1 )
          start_sending_out <= 1'b1;
      
      //Detect only 1 element received
      if( snk_valid_i && snk_endofpacket_i )
        begin
          if( wr_addr == '0 )
            start_sending_out <= 1'b1;
        end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= IDLE_S;
    else
      state <= next_state;
  end

//Condition when sorting is running to last cycle
//Ex: With bubble sort: N = 8, last cycle is the situation when i = 8 and j = 8
//The condition bellow is used for parallel sorting
assign last_sort        = ( cnt == data_received + 1 ) && ( i > data_received );

assign delay_odd_cycle  = ( i <=  data_received + 2*(cnt%2) );
assign delay_even_cycle = ( i <=  data_received + (cnt[0] ^ 1'b1) );
assign begin_writing    = ( snk_valid_i ) && ( wr_addr < MAX_PKT_LEN-1 );
assign end_writing      = ( sending == 1'b0 ) &&
                          ( start_sending_out != 1'b1 ) &&
                          ( cnt <= data_received );

//Check odd/even
assign data_received_even  = !data_received[0];
assign data_received_odd   = data_received[0];

always_comb
  begin
    next_state = state;
    case( state )
    //////////////////////////Waiting valid signal///////////////////////////
      IDLE_S:
        begin
          if( begin_writing ) 
            next_state = WRITE_S;
        end
  
      /////////////////////Writing input data to RAM ////////////////////////
      WRITE_S:
        begin
          if( end_writing )
            next_state = SORT_READ_S;

          //Use this condition when detecting 1 element
          //When module detects only 1 element sended
          //FSM will run only 3 states: WRITE_S and READ_S and IDLE_S 
          if( start_sending_out == 1'b1 )
            begin
              if( rd_addr <= data_received )
                next_state = READ_S;
            end
        end

      /////////////////////////Sorting states///////////////////////////
      //1) SORT_READ_S: Read value q_a and q_b (RAM's output) when addr_a = 0 and addr_b =  1(first 2 addresses)
      //Ex: q_a = mem[0]; q_b = mem[1]

      //2) SORT_WRITE_S: Write value back to RAM when 2 data has been swaped
      //Ex: if( mem[i] > mem[i+1] ) { swap(mem[i], mem[i+1] }    (1)
      //"i"and "i+1" are addr_a and addr_b of RAM, mem[i] is q_a, mem[i+1] is q_b
      //(1) is equivalent to  if( q_a > q_b ) { addr_a <= i+1, addr_b <= i }

      //3) SORT_READ_NEXT_S: Read value q_a, q_b (RAM's output) when addr_a = i and addr_b = i+1 (i != 0)
      //Ex: q_a = mem[i]; q_b = mem[i+1]
      SORT_READ_S:
        begin
          next_state = SORT_WRITE_S;

          if( last_sort )
            next_state = READ_S;
        end
      
      SORT_WRITE_S:
        begin
          next_state = SORT_READ_NEXT_S;
          if( last_sort )
            next_state = READ_S;
        end

      //"cnt" is counter of big loop, "i" is sub-counter(counter of small loop inside big loop)
      //When data_received is even (Ex: data_received = 8)
      //"even" cycle (cnt is even) will be: i = 0 (swap 0/1), 2(swap 2/3), 4(swap 4/5),6(swap 6/7), 8 will remain unchange
      //"odd" cycle (cnt is odd) will be: 0 will remain unchange, i = 1(swap 1/2),3(swap 3/4),5 (swap 5/6),7 (swap 7/8)
      //if we want to swap 2 elements
      //we need 2 clk (1 for jumping to SORT_WRITE_S state, and 1 for swapping(nonblocking assginment will delay 1 clk))
      //In "odd" cycle i = 1,3,5,7 swap(1/2) will be when i = 5 (in one clk, i will increase by 2)
      //and swap(7/8) will be when i =  11
      //Similarly when data_received is odd

      //SUMMARY:
      //When data_received is even, delay 2 clk will be in "ODD" cycle
      //When data_received is odd, delay 2 clk will be in "EVEN" cycle
      SORT_READ_NEXT_S:
        begin
          if( ( data_received_even && delay_odd_cycle ) || ( data_received_odd && delay_even_cycle ) )
            next_state = SORT_WRITE_S; 
          else
            next_state = SORT_READ_S;
      
          if( last_sort )
            next_state = READ_S;
        end
      READ_S:
        begin
          if( src_endofpacket_o )
            next_state = IDLE_S;
        end
    endcase
  end

//Control counter
always_ff @( posedge clk_i )
  begin
    if( srst_i )
      cnt <= '0;
    else
      begin
        if( snk_valid_i && snk_startofpacket_i )
          cnt <= '0;
        if( state == IDLE_S )
          cnt <= '0;
        else if( state == SORT_READ_NEXT_S  )
          begin
            if( data_received_even )
              begin
                if( !delay_odd_cycle ) //i > data_received  + 2*(cnt%2)
                  cnt <= cnt + (AWIDTH+1)'(1);
              end
            else if( data_received_odd )
              begin
                if( !delay_even_cycle ) 
                  cnt <= cnt + (AWIDTH+1)'(1);
              end
          end
      end
  end

//Control sub-counter
always_ff @( posedge clk_i )
  begin
    if( state == SORT_WRITE_S )
      i <= i + (AWIDTH+1)'(2);
    else if( state == SORT_READ_S )
      i <= cnt % (AWIDTH+1)'(2);
  end

////When module received only 1 element at the input
always_ff @( posedge clk_i )
  begin
  //When only 1 element
    if( snk_valid_i && snk_endofpacket_i )
      begin
        if( wr_addr == '0 )
          detect_only_1_elm <= 1'b1;
      end

    if( detect_only_1_elm == 1'b1 )
      begin
        if( rd_addr == 2 )
          detect_only_1_elm  <= 1'b0; 
      end
  end


////////////////////////////////////Control RAM//////////////////////////////
//Using parallel sorting

//Control wr_en_a and wr_en_b (Write enable signal of RAM)
always_ff @( posedge clk_i )
  begin
    if( state == IDLE_S )
      wr_en_a <= 1;
    else if( state == WRITE_S )
      begin
        if( snk_ready_o == 1'b1 )
          wr_en_a <= 1;

        if( snk_ready_o == 1'b0 )
          begin
            wr_en_a <= 1'b0;
            wr_en_b <= 1'b0;
          end
      end
    else if( state == SORT_READ_S )
      begin
        wr_en_a <= 1'b0;
        wr_en_b <= 1'b0;
      end
    else if( state == SORT_WRITE_S )
      begin
        if( tmp_data_a > tmp_data_b )
          begin
            wr_en_a <= 1'b1;
            wr_en_b <= 1'b1;
          end
      end
    else if( state == SORT_READ_NEXT_S )
      begin
        wr_en_a <= 1'b0;
        wr_en_b <= 1'b0;
      end
    else if( state == READ_S )
      begin
        if( ( start_sending_out == 1'b1 ) && ( rd_addr <= ( data_received + 2) ) )
          //Delay 2 clk
          // Need only 1 port to read out data
            wr_en_a <= 1'b0; 
      end
  end

////////////////////////////Control delay signal//////////////////////
//DELAY "i" and "i+1"
always_ff @( posedge clk_i )
  begin
    if( state == SORT_READ_S  )
      begin
        tmp_i0 <= cnt % (AWIDTH)'(2);
        tmp_i1 <= ( cnt % (AWIDTH)'(2) ) + (AWIDTH)'(1);
      end
    else if( state == SORT_READ_NEXT_S )
      begin
        if( ( data_received_even && delay_odd_cycle ) || ( data_received_odd && delay_even_cycle ) )
          begin
            tmp_i0 <= tmp_addr_a;
            tmp_i1 <= tmp_addr_b;
          end
      end
  end

//DELAY ADDRESS
always_ff @( posedge clk_i )
  begin
    if( state == SORT_READ_S  )
      begin
        tmp_addr_a <= (AWIDTH)'(cnt % 2);
        tmp_addr_b <= (AWIDTH)'(( cnt % 2 ) + 1);
      end
    else if( state == SORT_READ_NEXT_S )
      begin
        if( ( data_received_even && delay_odd_cycle ) || ( data_received_odd && delay_even_cycle ) )
          begin
            tmp_addr_a <= i[AWIDTH-1:0];
            tmp_addr_b <= i[AWIDTH-1:0]+ (AWIDTH)'(1);
          end
      end
  end

//Control tmp_data (data delay)
always_ff @( posedge clk_i )
  begin
    if( state == SORT_READ_S  )
      begin
        //Reset data
        tmp_data_a <= (DWIDTH)'(0);
        tmp_data_b <= (DWIDTH)'(0);
      end
    else if( state == SORT_READ_NEXT_S )
      begin
        if( ( data_received_even && delay_odd_cycle ) || ( data_received_odd && delay_even_cycle ) )
          begin
            //Delay data
            tmp_data_a <= q_a;
            tmp_data_b <= q_b;
          end
      end
  end

////////////////////////////////////Control RAM's data input //////////////////////
always_ff @( posedge clk_i )
  begin
    if( state == IDLE_S )
      data_a <= snk_data_i;
    else if( state == WRITE_S )
      begin
        //Begin writing data to RAM
        if( snk_ready_o == 1'b1 )
          data_a <= snk_data_i;
      end
    else if( state == SORT_WRITE_S )
      begin
        if( tmp_data_a > tmp_data_b )
          begin
            data_a  <= tmp_data_b;
            data_b  <= tmp_data_a;
          end
      end
        
  end

//Control address
always_ff @( posedge clk_i )
  begin
    if( state == IDLE_S )
      addr_a <= wr_addr;
    else if( state == WRITE_S )
      begin
        if( snk_ready_o == 1'b1 )
          addr_a <= wr_addr;
      end
    else if( state == SORT_READ_S )
      begin
        //Reset addresses depend on cnt (odd/even)
        addr_a <= (AWIDTH)'(cnt % 2);
        addr_b <= (AWIDTH)'(( cnt % 2 ) + 1);
      end
    else if( state == SORT_WRITE_S )
      begin
        if( tmp_data_a > tmp_data_b )
          begin
            addr_a <= tmp_i0[AWIDTH-1:0];
            addr_b <= tmp_i1[AWIDTH-1:0];
          end
      end
    else if( state == SORT_READ_NEXT_S )
      begin
        addr_a <= i[AWIDTH-1:0];
        addr_b <= i[AWIDTH-1:0]+ (AWIDTH)'(1); 
      end

    else if( state == READ_S )
      begin
        if( start_sending_out == 1'b1 )
          begin
            //Delay 2 clk
            if( rd_addr <= ( data_received + 2 ) )
              addr_a <= rd_addr;
          end
      end
  end

//////////////////////////////////Module's ouputs/////////////////////////////
always_ff @( posedge clk_i )
  begin
    if( state == READ_S )
      begin
        if( ( start_sending_out == 1'b1 ) && ( rd_addr <= ( data_received + 2 ) ) )
          src_data_o <= q_a;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      snk_ready_o <= 1'b1;
    else
      begin
        if( snk_endofpacket_i == 1'b1 )
          snk_ready_o <= 1'b0;
        
        if( rd_addr >= ( data_received + 5 ) ) //Delay 2 clk after receiving all output data
          snk_ready_o <= 1'b1;
        
        //Special case when module detect only 1 element received at the input
        if( detect_only_1_elm && rd_addr == 2 )
          snk_ready_o <= 1'b1;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_startofpacket_o <= 1'b0;
    else
      begin
        if( start_sending_out == 1'b1 )
          begin
            //Delay 2 clk
            if( rd_addr == 0 + 2 )
              src_startofpacket_o <= 1'b1;
            if( rd_addr == 1 + 2 )
              src_startofpacket_o <= 1'b0;
          end

      //Detect only 1 element received
      if( detect_only_1_elm == 1'b1 )
        begin
          if( rd_addr == 1 )
            src_startofpacket_o <= 1'b1;

          if( rd_addr == 2 )
            src_startofpacket_o <= 1'b0;
        end
      end
  end 

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      src_endofpacket_o <= 1'b0;
    else
      begin
        if( start_sending_out == 1'b1 )
          begin
            if( rd_addr ==  ( data_received + 2 ) )
              src_endofpacket_o <= 1'b1;
            if( rd_addr >  ( data_received + 2 ) )
              src_endofpacket_o <= 1'b0;
          end

        if( detect_only_1_elm == 1'b1 )
          begin
            if( rd_addr == 1 )
              src_endofpacket_o <= 1'b1;  

            if( rd_addr == 2 )
              src_endofpacket_o <= 1'b0;
          end
      end

  end

always_ff @( posedge clk_i )
  begin
    if( start_sending_out == 1'b1 && rd_addr == 2 )
      src_valid_o <= 1'b1;

    if( rd_addr >  ( data_received + 2 ) )
      src_valid_o <= 1'b0;

    if( detect_only_1_elm == 1'b1 )
      begin
        if( rd_addr == 1 )
          src_valid_o <= 1'b1;  

        if( rd_addr == 2 )
          src_valid_o <= 1'b0;
      end
  end

endmodule