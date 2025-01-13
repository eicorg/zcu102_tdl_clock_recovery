# The following constraints are necessary because the tool does not like to place a PLL in the path from RXOUTCLK to RXUSRCLK/2

# Help the placer with the RXOUTCLK PLLs to meet skew requirement between RXUSRCLK and RXUSRCLK2
#set_property LOC PLL_X0Y3 [get_cells {tdl_example_top_0/tdl_wrapper_inst/gtwiz_userclk_rx_inst/PLLE4_ADV_inst}]
##set_property LOC BUFGCTRL_X0Y23 [get_cells {tdl_example_top_0/tdl_wrapper_inst/gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk_inst}]
##set_property LOC BUFGCTRL_X0Y22 [get_cells {tdl_example_top_0/tdl_wrapper_inst/gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk2_inst}]

#set_property LOC PLL_X0Y7 [get_cells {tdl_example_top_1/tdl_wrapper_inst/gtwiz_userclk_rx_inst/PLLE4_ADV_inst}]
#set_property LOC BUFGCTRL_X0Y25 [get_cells {tdl_example_top_1/tdl_wrapper_inst/gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk_inst}]
#set_property LOC BUFGCTRL_X0Y24 [get_cells {tdl_example_top_1/tdl_wrapper_inst/gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk2_inst}]

# Don't worry about placing the PLLs in the same region as the DRP clock
set_property CLOCK_DEDICATED_ROUTE SAME_CMT_COLUMN [get_nets {USER_SI570_BUFG}]


# Get GTH and BUFGMUX cells
set gt              [get_cells -hier -filter {NAME=~*tdl_gth_inst/*GTHE4_CHANNEL_PRIM_INST}]
set rxusrclkbuf     [get_cells -hier -filter {NAME=~*gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk_inst}]
set rxusrclk2buf    [get_cells -hier -filter {NAME=~*gtwiz_userclk_rx_inst/BUFGMUX_CTRL_usrclk2_inst}]

# Set GT properties
set_property RX_PROGDIV_CFG     80.0                    $gt
set_property RXPH_MONITOR_SEL   5'b00011                $gt
set_property ADAPT_CFG1         16'b1101100000000010    $gt
set_property RXCDR_CFG0         16'b0000010000100110    $gt
set_property RXCDR_CFG5         16'b0011010001111011    $gt

#set_property RXCDR_CFG2         16'b0000000011000101    $gt

# Only analyze timing for the steady state case
set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==RXRATE[0]} -of_objects $gt]
set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==RXRATE[1]} -of_objects $gt]
set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==RXRATE[2]} -of_objects $gt]

set_case_analysis 1 [get_pins -filter {REF_PIN_NAME==RXOUTCLKSEL[0]} -of_objects $gt]
set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==RXOUTCLKSEL[1]} -of_objects $gt]
set_case_analysis 1 [get_pins -filter {REF_PIN_NAME==RXOUTCLKSEL[2]} -of_objects $gt]

set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==S0} -of_objects $rxusrclkbuf]
set_case_analysis 0 [get_pins -filter {REF_PIN_NAME==S1} -of_objects $rxusrclkbuf]

# Don't analyze timing of async select pins
set_false_path -to [get_pins -filter {REF_PIN_NAME==S0} -of_objects $rxusrclkbuf]
set_false_path -to [get_pins -filter {REF_PIN_NAME==S1} -of_objects $rxusrclkbuf]
set_false_path -to [get_pins -filter {REF_PIN_NAME==S0} -of_objects $rxusrclk2buf]
set_false_path -to [get_pins -filter {REF_PIN_NAME==S1} -of_objects $rxusrclk2buf]

# Clocks
set_property -dict {package_pin G21     IOSTANDARD LVDS_25}                     [get_ports CLK_125_P]
set_property -dict {package_pin F21     IOSTANDARD LVDS_25}                     [get_ports CLK_125_N]
set_property -dict {package_pin AK15    IOSTANDARD LVDS_25}                     [get_ports CLK_74_25_P]
set_property -dict {package_pin AK14    IOSTANDARD LVDS_25}                     [get_ports CLK_74_25_N]
set_property -dict {package_pin AL8     IOSTANDARD LVDS}                        [get_ports USER_SI570_P]
set_property -dict {package_pin AL7     IOSTANDARD LVDS}                        [get_ports USER_SI570_N]
#set_property -dict {package_pin L27}                                            [get_ports USER_MGT_SI570_CLOCK1_P]
#set_property -dict {package_pin L28}                                            [get_ports USER_MGT_SI570_CLOCK1_N]
set_property -dict {package_pin C8}                                             [get_ports USER_MGT_SI570_CLOCK2_P]
set_property -dict {package_pin C7}                                             [get_ports USER_MGT_SI570_CLOCK2_N]
#set_property -dict {package_pin B10}                                            [get_ports SFP_SI5328_OUT_P]
#set_property -dict {package_pin B9}                                             [get_ports SFP_SI5328_OUT_N]
set_property -dict {package_pin G8}                                             [get_ports FMC_HPC0_GBTCLK0_M2C_P]
set_property -dict {package_pin G7}                                             [get_ports FMC_HPC0_GBTCLK0_M2C_N]
set_property -dict {package_pin G27}                                            [get_ports FMC_HPC1_GBTCLK0_M2C_P]
set_property -dict {package_pin G28}                                            [get_ports FMC_HPC1_GBTCLK0_M2C_N]
#set_property -dict {package_pin N27}                                            [get_ports HDMI_RX_CLK_P]
#set_property -dict {package_pin N28}                                            [get_ports HDMI_RX_CLK_N]
set_property -dict {package_pin J27}                                            [get_ports USER_SMA_MGT_CLOCK_P]
set_property -dict {package_pin J28}                                            [get_ports USER_SMA_MGT_CLOCK_N]
#set_property -dict {package_pin P10     IOSTANDARD LVDS}                        [get_ports FMC_HPC1_CLK1_M2C_P]
#set_property -dict {package_pin P9      IOSTANDARD LVDS}                        [get_ports FMC_HPC1_CLK1_M2C_N]

# Data
set_property -dict {package_pin G4}                                             [get_ports FMC_HPC0_DP0_C2M_P]
set_property -dict {package_pin G3}                                             [get_ports FMC_HPC0_DP0_C2M_N]
set_property -dict {package_pin H2}                                             [get_ports FMC_HPC0_DP0_M2C_P]
set_property -dict {package_pin H1}                                             [get_ports FMC_HPC0_DP0_M2C_N]
set_property -dict {package_pin F29}                                            [get_ports FMC_HPC1_DP0_C2M_P]
set_property -dict {package_pin F30}                                            [get_ports FMC_HPC1_DP0_C2M_N]
set_property -dict {package_pin E31}                                            [get_ports FMC_HPC1_DP0_M2C_P]
set_property -dict {package_pin E32}                                            [get_ports FMC_HPC1_DP0_M2C_N]
#set_property -dict {package_pin M29}                                            [get_ports SMA_MGT_TX_P]
#set_property -dict {package_pin M30}                                            [get_ports SMA_MGT_TX_N]
#set_property -dict {package_pin M33}                                            [get_ports SMA_MGT_RX_P]
#set_property -dict {package_pin M34}                                            [get_ports SMA_MGT_RX_N]

# Header pins
#set_property -dict {package_pin H13     IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports L8P_HDGC_50_P]
#set_property -dict {package_pin H16     IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports L11P_AD9P_50_P]
#set_property -dict {package_pin J16     IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports L12P_AD8P_50_P]

# GPIO buttons
set_property -dict {package_pin AG13    IOSTANDARD LVCMOS33}                    [get_ports GPIO_SW_C]
set_property -dict {package_pin AE14    IOSTANDARD LVCMOS33}                    [get_ports GPIO_SW_E]
set_property -dict {package_pin AF15    IOSTANDARD LVCMOS33}                    [get_ports GPIO_SW_W]
set_property -dict {package_pin AG15    IOSTANDARD LVCMOS33}                    [get_ports GPIO_SW_N]
set_property -dict {package_pin AE15    IOSTANDARD LVCMOS33}                    [get_ports GPIO_SW_S]

# GPIO LEDs
set_property -dict {package_pin AG14    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_0]
set_property -dict {package_pin AF13    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_1]
set_property -dict {package_pin AE13    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_2]
set_property -dict {package_pin AJ14    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_3]
set_property -dict {package_pin AJ15    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_4]
set_property -dict {package_pin AH13    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_5]
set_property -dict {package_pin AH14    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_6]
set_property -dict {package_pin AL12    IOSTANDARD LVCMOS33}                    [get_ports GPIO_LED_7]

# Create clocks
create_clock -name clk_125      -period 8.0     [get_ports CLK_125_P]
create_clock -name clk_74_25    -period 13.47   [get_ports CLK_74_25_P]
create_clock -name clk_570      -period 10.0    [get_ports USER_SI570_P]
create_clock -name clk_ref0     -period 10.0    [get_ports USER_MGT_SI570_CLOCK2_P]
create_clock -name clk_ref1     -period 10.0    [get_ports USER_SMA_MGT_CLOCK_P]
create_clock -name clk_rec0     -period 10.0    [get_ports FMC_HPC0_GBTCLK0_M2C_P]
create_clock -name clk_rec1     -period 10.0    [get_ports FMC_HPC1_GBTCLK0_M2C_P]



# False path constraints
# ----------------------------------------------------------------------------------------------------------------------
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *bit_synchronizer*inst/i_in_meta_reg}] -quiet
##set_false_path -to [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_*_reg}] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*D} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_meta*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*PRE} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_meta*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*PRE} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync1*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*PRE} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync2*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*PRE} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync3*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*PRE} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_out*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*CLR} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_meta*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*CLR} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync1*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*CLR} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync2*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*CLR} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_sync3*}]] -quiet
set_false_path -to [get_pins -filter {REF_PIN_NAME=~*CLR} -of_objects [get_cells -hierarchical -filter {NAME =~ *reset_synchronizer*inst/rst_in_out*}]] -quiet


set_false_path -to [get_cells -hierarchical -filter {NAME =~ *gtwiz_userclk_tx_inst/*gtwiz_userclk_tx_active_*_reg}] -quiet
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *gtwiz_userclk_rx_inst/*gtwiz_userclk_rx_active_*_reg}] -quiet
