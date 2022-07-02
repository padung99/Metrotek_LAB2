module fifo #(
  parameter DWIDTH             = 16,
  parameter AWIDTH             = 8,
  parameter SHOWAHEAD          = 1,
  parameter ALMOST_FULL_VALUE  = 240,
  parameter ALMOST_EMPTY_VALUE = 15,
  parameter REGISTER_OUTPUT    = 0
) (
  input  logic              clk_i,
  input  logic              srst_i,
  input  logic [DWIDTH-1:0] data_i,

  input  logic              wrreq_i,
  input  logic              rdreq_i,
  output logic [DWIDTH-1:0] q_o,
  output logic              empty_o,
  output logic              full_o,
  output logic [AWIDTH-1:0] usedw_o,

  output logic              almost_full_o,  
  output logic              almost_empty_o
);

scfifo #(
  .add_ram_output_register ( "OFF"               ),
  .almost_empty_value      ( ALMOST_EMPTY_VALUE  ),
  .almost_full_value       ( ALMOST_FULL_VALUE   ),
  .intended_device_family  ( "Cyclone V"         ),
  .lpm_hint                ("RAM_BLOCK_TYPE=M10K"),
  .lpm_numwords            ( 2**AWIDTH           ),
  .lpm_showahead           ( "ON"                ),
  .lpm_type                ( "scfifo"            ),
  .lpm_width               ( DWIDTH              ),
  .lpm_widthu              ( AWIDTH              ),
  .overflow_checking       ( "ON"                ),
  .underflow_checking      ( "ON"                ),
  .use_eab                 ( "ON"                )
) golden_model (
  .clock        ( clk_i          ),
  .data         ( data_i         ),
  .rdreq        ( rdreq_i        ),
  .sclr         ( srst_i         ),
  .wrreq        ( wrreq_i        ),
  .almost_empty ( almost_empty_o ),
  .almost_full  ( almost_full_o  ),
  .empty        ( empty_o        ),
  .full         ( full_o         ),
  .q            ( q_o            ),
  .usedw        ( usedw_o        ),
  .aclr         (                ),
  .eccstatus    (                )
);

endmodule
