set_time_format -unit ns -decimal_places 3

create_clock -name {clk_150} -period "150 MHz" -waveform { 0.000 3.333 } [get_ports {clk_i}]

derive_clock_uncertainty