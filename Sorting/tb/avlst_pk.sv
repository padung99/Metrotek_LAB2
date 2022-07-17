package  avlst_pk;

typedef logic [15:0] pkt_t [$];  //////////////should override parameter


class pk_avalon_st #(
  parameter DWIDTH_PK    = 16,
  parameter WIDTH_MAX_PK = 20,
  parameter PACKET       = 5
);
                                            
mailbox #( pkt_t ) tx_fifo;
mailbox #( pkt_t ) rx_fifo;
mailbox #( pkt_t ) valid_tx_fifo;

// mailbox #( logic[DWIDTH_PK-1:0] ) tx_fifo;

virtual avalon_st avlst_if;

`define cb @( posedge avlst_if.clk );

// clocking cb
//   @( posedge avlst_if.clk );
// endclocking

function new( virtual avalon_st  _avlst_if,
              mailbox #( pkt_t ) _tx_fifo,
              mailbox #( pkt_t ) _valid_tx_fifo,
              mailbox #( pkt_t ) _rx_fifo
              );
  this.avlst_if      = _avlst_if;
  this.tx_fifo       = _tx_fifo;
  this.valid_tx_fifo = _valid_tx_fifo;
  this.rx_fifo       = _rx_fifo;
endfunction

//Send multiple pk to snk
task send_pk( );

pkt_t new_tx_fifo;
pkt_t new_valid_tx_fifo;
int total_data;

int sop_random;
int eop_random;

while( tx_fifo.num() != 0 )
  begin
    tx_fifo.get( new_tx_fifo );
    // avlst_if.data = new_tx_fifo;
    total_data = new_tx_fifo.size();
    sop_random = 0;
    eop_random = total_data;

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
                avlst_if.valid = 1'b0;

                new_valid_tx_fifo.push_back( new_tx_fifo[i] );
                $display( "Send [%0d]: %0d",new_valid_tx_fifo.size(), avlst_if.data );
              end
            else if( i == eop_random -1)
              begin
                avlst_if.eop   = 1'b1;
                avlst_if.valid = 1'b1;
                `cb;
                avlst_if.eop = 1'b0;
                avlst_if.valid = 1'b0;

                new_valid_tx_fifo.push_back( new_tx_fifo[i]);
                $display( "Send [%0d]: %0d",new_valid_tx_fifo.size(), avlst_if.data );
                valid_tx_fifo.put( new_valid_tx_fifo );
                new_valid_tx_fifo = {};
              end
            else 
              begin
                avlst_if.sop   = 1'b0;
                avlst_if.eop   = 1'b0;
                avlst_if.valid = $urandom_range(1,0);
                if( avlst_if.valid == 1'b1 )
                  begin
                    new_valid_tx_fifo.push_back( avlst_if.data );
                    $display( "Send [%0d]: %0d",new_valid_tx_fifo.size(), avlst_if.data );
                  end
                `cb;
              end
          end
      end

    //Delay between packets:
    //Sort delay: total_data*total_data/2;
    //Write delay: total_data;
    //Read delay: total_data;
    for( int i =0; i< total_data*total_data/2 + 2*total_data+10; i++ )
      `cb;

  end

endtask

//Source (receive packets)
task receive_pk();

pkt_t new_rx_fifo;
forever
  begin
    `cb;
    if( avlst_if.valid == 1'b1 && avlst_if.eop != 1'b1 )
      begin
        new_rx_fifo.push_back( avlst_if.data );
        $display( "Receive [%0d]: %0d",new_rx_fifo.size(), avlst_if.data );
      end
    else if( avlst_if.valid == 1'b1 && avlst_if.eop == 1'b1 )
      begin
        new_rx_fifo.push_back( avlst_if.data );
        $display( "Receive [%0d]: %0d",new_rx_fifo.size(), avlst_if.data );
        $display( "\n" );

        rx_fifo.put( new_rx_fifo );
        new_rx_fifo = {}; //Reset packet
      end
    
    if( rx_fifo.num() >= PACKET )
      break;
  end
endtask

endclass

endpackage
