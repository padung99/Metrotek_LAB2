vlib work

set source_file {
  "../rtl/Sorting.sv"
  "Sorting_tb.sv"
}

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*
add wave "sim:/Sorting_tb/dut/sort_mem"
add wave -r *
view -undock wave
run -all