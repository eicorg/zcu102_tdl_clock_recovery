##################################################################
# CREATE IP picxo_fracxo_0
##################################################################

set picxo_fracxo_0 [create_ip -name picxo_fracxo -vendor xilinx.com -library ip -version 1.0 -module_name picxo_fracxo_0]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $picxo_fracxo_0

##################################################################

