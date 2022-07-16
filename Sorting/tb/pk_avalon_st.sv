
// typedef bit[15:0] packet_t[$];

// typedef struct {

// logic [19:0] [15:0] pkg_data;
// logic        pkg_eop;
// logic        pkg_sop;

// }packet_t;

class pk_avalon_st( );


mailbox #( logic[15:0] ) pk_data;

virtual avalon_st avlst_if;

default clocking cb
  @( posedge avlst_if.clk );
endclocking

//Send pk to snk
task send_pk( mailbox #( logic[15:0] ) _pk_data );

logic [15:0] new_pk_data;
int total_data;

total_data = _pk_data.num();

while( _pk_data.num() != 0 )
  begin
    if( avlst_if.ready )
    _pk_data.get( new_pk_data );
    avlst_if.data = new_pk_data;
    if( _pk_data.num() == total_data-2 || _pk_data.num() == total_data- 10 ||  _pk_data.num() == total_data-25 ||  _pk_data.num() == total_data-45 )
      begin
        avlst_if.sop = 1;
        avlst_if.valid = 1;
        ##1;
        avlst_if.sop = 0;
        avlst_if.valid = $urandom_range(1,0);
      end
  end

endtask

task receive_pk();
endtask

function new( virtual avalon_st avlst_if );
  this.avlst_if = avlst_if;
endfunction
endclass
