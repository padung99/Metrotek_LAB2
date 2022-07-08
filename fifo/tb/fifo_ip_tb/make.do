set path_to_library C:/intelFPGA_lite/18.1/quartus/eda/sim_lib
vlib work

set source_file {
  "../../rtl/fifo_ip/fifo_ip.sv"
  "../../rtl/fifo_ip/mem.v"
  "fifo_ip_tb.sv"
}

vlog $path_to_library/altera_mf.v

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*
add wave -group dut1_fifo_ip /fifo_ip_tb/dut1/*
add wave -group dut2_fifo_ip /fifo_ip_tb/dut2/*
view -undock wave
run -all