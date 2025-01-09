// ------------------------------------------------------------------------------------------------
//            .~``~._
//       _.|  |_.._  `~._
//      |  |  `    `~.   |   BBBBB   N     N  L
//      |  |  .~``~.  |  |   B    B  N N   N  L
//      |  |  |    |  |  |   BBBBB   N  N  N  L
//      |  |  `~..~`  |  |   B    B  N   N N  L
//      \_  `~._  _.~`  _/   BBBBB   N     N  LLLLLL
//        `~._  ``  _.~`
//            `~..~`
// ------------------------------------------------------------------------------------------------
//  Testing out two TDL channels on a ZCU102 eval board
//  FMC0 and FMC1 DP0 are looped back to each other and the recovered clocks are
//  output to GBTCLK0 on each. They each use an independent reference clock.
//  The system controller board UI tool is used to program the Si5328 and both Si570
//  oscillators to 100 MHz for this test application
// ------------------------------------------------------------------------------------------------

module zcu102_tdl_test_top (
    // Fixed 125 MHz clock
    input  wire CLK_125_P,
    input  wire CLK_125_N,
    // Fixed 74.25 MHz clock
    input  wire CLK_74_25_P,
    input  wire CLK_74_25_N,
    // Si570 fabric clock
    input  wire USER_SI570_P,
    input  wire USER_SI570_N,
    // Si570 mgtref clock
    input  wire USER_MGT_SI570_CLOCK1_P,
    input  wire USER_MGT_SI570_CLOCK1_N,
    // Si5328 mgtref clock
    input  wire SFP_SI5328_OUT_P,
    input  wire SFP_SI5328_OUT_N,
    // FMC0 GBTCLK0
    output wire FMC_HPC0_GBTCLK0_M2C_P,
    output wire FMC_HPC0_GBTCLK0_M2C_N,
    // FMC1 GBTCLK0
    output wire FMC_HPC1_GBTCLK0_M2C_P,
    output wire FMC_HPC1_GBTCLK0_M2C_N,
    // FMC0 DP0
    output wire FMC_HPC0_DP0_C2M_P,
    output wire FMC_HPC0_DP0_C2M_N,
    input  wire FMC_HPC0_DP0_M2C_P,
    input  wire FMC_HPC0_DP0_M2C_N,
    // FMC1 DP0
    output wire FMC_HPC1_DP0_C2M_P,
    output wire FMC_HPC1_DP0_C2M_N,
    input  wire FMC_HPC1_DP0_M2C_P,
    input  wire FMC_HPC1_DP0_M2C_N,
    // Header pins
    output wire L8P_HDGC_50_P,
    output wire L11P_AD9P_50_P,
    output wire L12P_AD8P_50_P,
    // GPIO buttons
    input  wire GPIO_SW_N,
    input  wire GPIO_SW_E,
    input  wire GPIO_SW_S,
    input  wire GPIO_SW_W,
    input  wire GPIO_SW_C,
    // GPIO LEDs
    output wire GPIO_LED_0,
    output wire GPIO_LED_1,
    output wire GPIO_LED_2,
    output wire GPIO_LED_3,
    output wire GPIO_LED_4,
    output wire GPIO_LED_5,
    output wire GPIO_LED_6,
    output wire GPIO_LED_7
);
    
    wire CLK_125;
    wire CLK_74_25;
    wire USER_SI570;
    wire SFP_SI5328_OUT_BUF;
    wire USER_MGT_SI570_CLOCK1_BUF;
    
    wire link_status_0;
    wire link_status_1;
    
    logic [31:0] cnt [3];
    
    always @(posedge CLK_125)    cnt[0] = cnt[0] + 1;
    always @(posedge CLK_74_25)  cnt[1] = cnt[1] + 1;
    always @(posedge USER_SI570) cnt[2] = cnt[2] + 1;
    
    assign GPIO_LED_0 = cnt[0][27];
    assign GPIO_LED_1 = cnt[1][27];
    assign GPIO_LED_2 = cnt[2][27];
    assign GPIO_LED_3 = GPIO_SW_N;
    assign GPIO_LED_4 = GPIO_SW_S;
    assign GPIO_LED_5 = GPIO_SW_C;
    assign GPIO_LED_6 = link_status_0;
    assign GPIO_LED_7 = link_status_1;
    
    OBUFDS OBUFDS_inst (
        .O(HDMI_TX_LVDS_OUT_P),   // 1-bit output: Diff_p output (connect directly to top-level port)
        .OB(HDMI_TX_LVDS_OUT_N), // 1-bit output: Diff_n output (connect directly to top-level port)
        .I(USER_SI570)    // 1-bit input: Buffer input
    );
    
    IBUFDS #(
        .CCIO_EN_M("TRUE"),
        .CCIO_EN_S("TRUE") 
    ) IBUFDS0_inst (
        .O(CLK_74_25),   // 1-bit output: Buffer output
        .I(CLK_74_25_P),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
        .IB(CLK_74_25_N)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
    );
  
    IBUFDS #(
        .CCIO_EN_M("TRUE"),
        .CCIO_EN_S("TRUE") 
    ) IBUFDS1_inst (
        .O(CLK_125),   // 1-bit output: Buffer output
        .I(CLK_125_P),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
        .IB(CLK_125_N)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
    );
  
    IBUFDS #(
        .CCIO_EN_M("TRUE"),
        .CCIO_EN_S("TRUE") 
    ) IBUFDS2_inst (
        .O(USER_SI570),   // 1-bit output: Buffer output
        .I(USER_SI570_P),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
        .IB(USER_SI570_N)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
    );
   
    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    ) ODDRE1_inst0 (
        .Q(L8P_HDGC_50_P),   // 1-bit output: Data output to IOB
        .C(SFP_SI5328_OUT_BUF),   // 1-bit input: High-speed clock input
        .D1(1'b0), // 1-bit input: Parallel data input 1
        .D2(1'b1), // 1-bit input: Parallel data input 2
        .SR(1'b0)  // 1-bit input: Active-High Async Reset
    );
   
    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    ) ODDRE1_inst1 (
        .Q(L11P_AD9P_50_P),   // 1-bit output: Data output to IOB
        .C(USER_MGT_SI570_CLOCK1_BUF),   // 1-bit input: High-speed clock input
        .D1(1'b0), // 1-bit input: Parallel data input 1
        .D2(1'b1), // 1-bit input: Parallel data input 2
        .SR(1'b0)  // 1-bit input: Active-High Async Reset
    );
   
    ODDRE1 #(
        .IS_C_INVERTED(1'b0),           // Optional inversion for C
        .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
        .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
        .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        .SRVAL(1'b0)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
    ) ODDRE1_inst2 (
        .Q(L12P_AD8P_50_P),   // 1-bit output: Data output to IOB
        .C(USER_SI570),   // 1-bit input: High-speed clock input
        .D1(1'b0), // 1-bit input: Parallel data input 1
        .D2(1'b1), // 1-bit input: Parallel data input 2
        .SR(1'b0)  // 1-bit input: Active-High Async Reset
    );
    
    tdl_example_top tdl_example_top_fmc0 (
        .mgtrefclk_p    (SFP_SI5328_OUT_P),
        .mgtrefclk_n    (SFP_SI5328_OUT_N),
        .mgtrefclk_buf  (SFP_SI5328_OUT_BUF),
        .rxrecclkout_p  (FMC_HPC0_GBTCLK0_M2C_P),
        .rxrecclkout_n  (FMC_HPC0_GBTCLK0_M2C_N),
        .gthrxn         (FMC_HPC0_DP0_M2C_N),
        .gthrxp         (FMC_HPC0_DP0_M2C_P),
        .gthtxn         (FMC_HPC0_DP0_C2M_N),
        .gthtxp         (FMC_HPC0_DP0_C2M_P),
        .clk_freerun    (USER_SI570),
        .reset          (GPIO_SW_E),
        .link_status    (link_status_0)
        ,.reset_rx_datapath_in(GPIO_SW_S)
    );
    
    tdl_example_top tdl_example_top_fmc1 (
        .mgtrefclk_p    (USER_MGT_SI570_CLOCK1_P),
        .mgtrefclk_n    (USER_MGT_SI570_CLOCK1_N),
        .mgtrefclk_buf  (USER_MGT_SI570_CLOCK1_BUF),
        .rxrecclkout_p  (FMC_HPC1_GBTCLK0_M2C_P),
        .rxrecclkout_n  (FMC_HPC1_GBTCLK0_M2C_N),
        .gthrxn         (FMC_HPC1_DP0_M2C_N),
        .gthrxp         (FMC_HPC1_DP0_M2C_P),
        .gthtxn         (FMC_HPC1_DP0_C2M_N),
        .gthtxp         (FMC_HPC1_DP0_C2M_P),
        .clk_freerun    (USER_SI570),
        .reset          (GPIO_SW_W),
        .link_status    (link_status_1)
        ,.reset_rx_datapath_in(GPIO_SW_N)
    );
    
endmodule
