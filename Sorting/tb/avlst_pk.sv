package  avlst_pk;

class pk_avalon_st #(
  parameter DWIDTH_PK    = 16,
  parameter WIDTH_MAX_PK = 20
);

mailbox #( logic[DWIDTH_PK-1:0] ) pk_data;

virtual avalon_st avlst_if;

`define cb @( posedge avlst_if.clk );

// clocking cb
//   @( posedge avlst_if.clk );
// endclocking

function new( virtual avalon_st _avlst_if, mailbox #( logic[DWIDTH_PK-1:0] ) _pk_data  );
  this.avlst_if = _avlst_if;
  this.pk_data  = _pk_data;
endfunction

//Send 1 pk to snk
task send_pk( );

logic [DWIDTH_PK-1:0] new_pk_data;
int total_data;

int sop_random;
int eop_random;

total_data = pk_data.num();
sop_random = $urandom_range( 5,2 );
eop_random = $urandom_range( 4,2 );

while( pk_data.num() != 0 )
  begin
    pk_data.get( new_pk_data );
    avlst_if.data = new_pk_data;
    if( avlst_if.ready )
      begin
        if( pk_data.num() == total_data-sop_random )
          begin
            avlst_if.sop   = 1'b1;
            avlst_if.valid = 1'b1;
            `cb;
            avlst_if.sop = 1'b0;
          end
        else if( pk_data.num() == eop_random )
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

endtask

task receive_pk();
endtask

endclass

endpackage
