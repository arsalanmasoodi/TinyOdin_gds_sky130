#------------------------------------------------------------------------------
# "librelane.sdc" - SDC constraints file for LibreLane OpenSTA
# Project: tinyODIN on Sky130A
#------------------------------------------------------------------------------

# Timing targets
if {[info exists ::env(CLOCK_PERIOD)]} {
    set CLK_PERIOD $::env(CLOCK_PERIOD)
} else {
    set CLK_PERIOD 20.0
}
set SCK_PERIOD [expr {$CLK_PERIOD * 4}]

set IO_DLY [expr {$CLK_PERIOD * 0.2}]

set CLK_LATENCY     0.5
set CLK_UNCERTAINTY 0.25
set CLK_TRAN        0.2

#####################################
#           Main Clocks             #
#####################################

# Controller core clock
create_clock -name "CLK" -period $CLK_PERIOD -waveform [list 0 [expr {$CLK_PERIOD / 2.0}]] [get_ports CLK]

# SPI slave clock
create_clock -name "SCK" -period $SCK_PERIOD -waveform [list 0 [expr {$SCK_PERIOD / 2.0}]] [get_ports SCK]

# Asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks CLK] -group [get_clocks SCK]

# Clock distribution latency, uncertainty, and transition
set_clock_latency     $CLK_LATENCY     [all_clocks]
set_clock_uncertainty $CLK_UNCERTAINTY [all_clocks]
set_clock_transition  $CLK_TRAN        [all_clocks]

#####################################
#           False Paths             #
#####################################

set_false_path -through [get_ports RST]
set_false_path -through [get_ports AERIN_ADDR]
set_false_path -through [get_ports AERIN_REQ]
set_false_path -through [get_ports AERIN_ACK]
set_false_path -through [get_ports AEROUT_ADDR]
set_false_path -through [get_ports AEROUT_REQ]
set_false_path -through [get_ports AEROUT_ACK]
set_false_path -through [get_ports SCHED_FULL]

#####################################
#       Input/Output Delays         #
#####################################

# SPI MOSI input
set_input_delay  $IO_DLY -max -clock "SCK" -clock_fall [get_ports MOSI]
set_input_delay [expr {-$IO_DLY}] -min -clock "SCK" -clock_fall [get_ports MOSI]

# SPI MISO output
set_output_delay  $IO_DLY -max -clock "SCK" [get_ports MISO]
set_output_delay [expr {-$IO_DLY}] -min -clock "SCK" [get_ports MISO]
