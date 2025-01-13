##################################################################
# CREATE IP tdl_gth
##################################################################

set tdl_gth [create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name tdl_gth]

# User Parameters
set_property -dict [list \
  CONFIG.ENABLE_OPTIONAL_PORTS {dmonitorclk_in drpaddr_in drpclk_in drpdi_in drpen_in drpwe_in rxcdrovrden_in rxoutclksel_in rxrate_in txpippmen_in txpippmsel_in txpippmstepsize_in dmonitorout_out drpdo_out drprdy_out rxprgdivresetdone_out rxrecclkout_out} \
  CONFIG.LOCATE_COMMON {EXAMPLE_DESIGN} \
  CONFIG.LOCATE_RESET_CONTROLLER {EXAMPLE_DESIGN} \
  CONFIG.LOCATE_RX_BUFFER_BYPASS_CONTROLLER {EXAMPLE_DESIGN} \
  CONFIG.RX_BUFFER_MODE {0} \
  CONFIG.RX_COMMA_ALIGN_WORD {4} \
  CONFIG.RX_COMMA_M_ENABLE {true} \
  CONFIG.RX_COMMA_PRESET {K28.5} \
  CONFIG.RX_COMMA_P_ENABLE {true} \
  CONFIG.RX_DATA_DECODING {8B10B} \
  CONFIG.RX_EQ_MODE {LPM} \
  CONFIG.RX_LINE_RATE {8} \
  CONFIG.RX_OUTCLK_SOURCE {RXOUTCLKPMA} \
  CONFIG.RX_SLIDE_MODE {PCS} \
  CONFIG.RX_USER_DATA_WIDTH {64} \
  CONFIG.TX_DATA_ENCODING {8B10B} \
  CONFIG.TX_LINE_RATE {8} \
  CONFIG.TX_USER_DATA_WIDTH {64} \
] [get_ips tdl_gth]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $tdl_gth

##################################################################

