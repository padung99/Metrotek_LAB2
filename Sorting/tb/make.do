set path_to_library C:/intelFPGA_lite/18.1/quartus/eda/sim_lib
vlib work

set source_file {
  "../rtl/Sorting.sv"
  "../rtl/mem2.v"
  "avalon_st.sv"
  "avlst_pk.sv"
  "Sorting_tb.sv"
}

vlog $path_to_library/altera_mf.v

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*
#add wave "sim:/Sorting_tb/dut/sort_mem"
add wave -r *
view -undock wave
run -all