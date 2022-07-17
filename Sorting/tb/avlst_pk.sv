package  avlst_pk;

typedef logic [15:0] pkt_t [$];  //////////////should override parameter

class pk_avalon_st #(
  parameter DWIDTH_PK    = 16,
  parameter WIDTH_MAX_PK = 20
);
                                                
mailbox #( pkt_t ) tx_fifo;   

// mailbox #( logic[DWIDTH_PK-1:0] ) tx_fifo;

virtual avalon_st avlst_if;

`define cb @( posedge avlst_if.clk );

// clocking cb
//   @( posedge avlst_if.clk );
// endclocking

function new( virtual avalon_st _avlst_if, mailbox #( pkt_t ) _tx_fifo  );
  this.avlst_if = _avlst_if;
  this.tx_fifo  = _tx_fifo;
endfunction

//Send multiple pk to snk
task send_pk( );

pkt_t new_tx_fifo;
int total_data;

int sop_random;
int eop_random;

while( tx_fifo.num() != 0 )
  begin
    tx_fifo.get( new_tx_fifo );
    // avlst_if.data = new_tx_fifo;
    total_data = new_tx_fifo.size();
    sop_random = $urandom_range( 5,2 );
    eop_random = $urandom_range( 4,2 );

    for( int i = 0; i < new_tx_fifo.size(); i++ )
      begin
        avlst_if.data = new_tx_fifo[i];
        if( avlst_if.ready )
          begin
            if( i == sop_random )
              begin
                avlst_if.sop   = 1'b1;
                avlst_if.valid = 1'b1;
                `cb;
                avlst_if.sop = 1'b0;
              end
            else if( i == total_data - eop_random )
              begin
                avlst_if.eop   = 1'b1;
                avlst_if.valid = 1'b1;
                `cb;
                avlst_if.eop = 1'b0;
              end
            else 
              begin
                avlst_if.sop   = 1'b0;
                avlst_if.eop   = 1'b0;
                avlst_if.valid = $urandom_range(1,0);
                `cb;
              end
          end
      end

    //Delay between packets
    for( int i =0; i< total_data*total_data + 2*total_data+5; i++ )
      `cb;

  end

endtask

task receive_pk();
endtask

endclass

endpackage
