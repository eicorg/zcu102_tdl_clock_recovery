##################################################################
# CREATE IP vio_rx
##################################################################

set vio_rx [create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_rx]

# User Parameters
set_property -dict [list \
  CONFIG.C_NUM_PROBE_IN {1} \
  CONFIG.C_NUM_PROBE_OUT {0} \
  CONFIG.C_PROBE_IN0_WIDTH {64} \
] [get_ips vio_rx]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $vio_rx

##################################################################

