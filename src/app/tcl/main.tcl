################################################################################
# Main tcl for the module
################################################################################

# ==============================================================================
proc init {} {
}

# ==============================================================================
proc setSources {} {
  # Add sources
  variable Sources
  lappend Sources [list ../hdl/bit_sync.v                               "Verilog"]
  lappend Sources [list ../hdl/gtwiz_reset.v                            "Verilog"]
  lappend Sources [list ../hdl/gtwiz_userclk_rx.v                       "Verilog"]
  lappend Sources [list ../hdl/gtwiz_userclk_tx.v                       "Verilog"]
  lappend Sources [list ../hdl/gtwizard_ultrascale_v1_7_gthe4_common.v  "Verilog"]
  lappend Sources [list ../hdl/reset_inv_sync.v                         "Verilog"]
  lappend Sources [list ../hdl/reset_sync.v                             "Verilog"]
  lappend Sources [list ../hdl/tdl_example_top.v                        "Verilog"]
  lappend Sources [list ../hdl/tdl_gthe4_common_wrapper.v               "Verilog"]
  lappend Sources [list ../hdl/tdl_wrapper.v                            "Verilog"]
  lappend Sources [list ../hdl/rxdata_aligner.sv                        "SystemVerilog"]
  lappend Sources [list ../hdl/rxrecclk_phase_aligner.sv                "SystemVerilog"]
  lappend Sources [list ../hdl/tx_phase_aligner.sv                      "SystemVerilog"]
  lappend Sources [list ../hdl/zcu102_tdl_test_top.sv                   "SystemVerilog"]
  lappend Sources [list ../cstr/zcu102_tdl_test_top.xdc                 "XDC"]

  # Add IP tcl build script
  variable Ip
  lappend Ip ../tcl/picxo_fracxo_0.tcl
  lappend Ip ../tcl/tdl_gth.tcl
  lappend Ip ../tcl/vio_rx.tcl
  lappend Ip ../tcl/vio_tx.tcl
}

# ==============================================================================
proc setAddressSpace {} {
}

# ==============================================================================
proc setPrjProperties {} {
  # Set project properties
  set_property PART             "xczu9eg-ffvb1156-2-e"          [current_project]
  set_property board_part       "xilinx.com:zcu102:part0:3.4"   [current_project]
}

# ==============================================================================
proc doOnCreate {} {
  # Add Sources
  variable Sources
  addSources Sources

  # Execute IP TCL scripts
  variable Ip
  foreach Ip_i $Ip { source $Ip_i }
}

# ==============================================================================
proc doOnBuild {} {
}

# ==============================================================================
proc setSim {} {
}
