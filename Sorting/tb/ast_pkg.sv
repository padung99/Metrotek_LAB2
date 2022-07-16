package ast_pkg;

typedef bit[15:0] packet_t[$];

class pk_avalon_st( );

  mailbox #( packet_t ) gen_pk;
  
  virtual avalon_st avlst_if;

  task send_pk();
    avlst_if.data
  endtask

  task receive_pk();
  endtask

  function new( virtual avalon_st avlst_if );
    this.avlst_if = avlst_if;
  endfunction
endclass

endpackage