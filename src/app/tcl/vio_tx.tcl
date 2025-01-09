##################################################################
# CREATE IP vio_tx
##################################################################

set vio_tx [create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_tx]

# User Parameters
set_property -dict [list \
  CONFIG.C_NUM_PROBE_IN {0} \
  CONFIG.C_PROBE_OUT0_WIDTH {64} \
] [get_ips vio_tx]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $vio_tx

##################################################################

