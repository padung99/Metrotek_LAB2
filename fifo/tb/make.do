vlib work

set source_file {
  "../rtl/fifo.sv"
  "fifo_tb.sv"
}
vlog altera_mf.v

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*
add wave -r *
view -undock wave
run -all