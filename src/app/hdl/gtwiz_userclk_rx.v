`timescale 1ps/1ps

module gtwiz_userclk_rx (
    input  wire         gtwiz_userclk_rx_srcclk_in,
    input  wire         gtwiz_userclk_rx_reset_in,
    output wire         gtwiz_userclk_rx_usrclk_out,
    output wire         gtwiz_userclk_rx_usrclk2_out,
    output wire         gtwiz_userclk_rx_active_out,
    input  wire         drpclk,
    input  wire         drpen,
    input  wire         drpwe,
    output wire         drprdy,
    input  wire [6:0]   drpaddr,
    input  wire [15:0]  drpdi,
    input  wire         inv_rxusrclk,
    input  wire         inv_rxusrclk2
);

      // Indicate active helper block functionality when the BUFG_GT divider is not held in reset
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_rx_active_meta = 1'b0;
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_rx_active_sync = 1'b0;
      always @(posedge gtwiz_userclk_rx_usrclk2_out, posedge gtwiz_userclk_rx_reset_in) begin
        if (gtwiz_userclk_rx_reset_in) begin
          gtwiz_userclk_rx_active_meta <= 1'b0;
          gtwiz_userclk_rx_active_sync <= 1'b0;
        end
        else begin
          gtwiz_userclk_rx_active_meta <= LOCKED;
          gtwiz_userclk_rx_active_sync <= gtwiz_userclk_rx_active_meta;
        end
      end
      assign gtwiz_userclk_rx_active_out = gtwiz_userclk_rx_active_sync;
  
    // Buffer RXOUTCLK from GT to PLL
    BUFG_GT #(
        .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
    )
    BUFG_GT_RXOUTCLK_inst (
        .O(gtwiz_userclk_rx_outclk),             // 1-bit output: Buffer
        .CE(1'b1),           // 1-bit input: Buffer enable
        .CEMASK(1'b0),   // 1-bit input: CE Mask
        .CLR(1'b0),         // 1-bit input: Asynchronous clear
        .CLRMASK(1'b0), // 1-bit input: CLR Mask
        .DIV(3'b000),         // 3-bit input: Dynamic divide Value
        .I(gtwiz_userclk_rx_srcclk_in)              // 1-bit input: Buffer
    );
    
    // Buffer RXUSRCLK2 from PLL to GT with selectable inversion
    BUFGMUX_CTRL BUFGMUX_CTRL_usrclk2_inst (
        .O(gtwiz_userclk_rx_usrclk2_out),   // 1-bit output: Clock output
        .I0(gtwiz_userclk_rx_usrclk2), // 1-bit input: Clock input (S=0)
        .I1(gtwiz_userclk_rx_usrclk2_b), // 1-bit input: Clock input (S=1)
        .S(inv_rxusrclk2)    // 1-bit input: Clock select
    );
    
    // Buffer RXUSRCLK from PLL to GT with selectable inversion
    BUFGMUX_CTRL BUFGMUX_CTRL_usrclk_inst (
        .O(gtwiz_userclk_rx_usrclk_out),   // 1-bit output: Clock output
        .I0(gtwiz_userclk_rx_usrclk), // 1-bit input: Clock input (S=0)
        .I1(gtwiz_userclk_rx_usrclk_b), // 1-bit input: Clock input (S=1)
        .S(inv_rxusrclk)    // 1-bit input: Clock select
    );

    // PLL to generate RXUSRCLK (200MHz) and RXUSRCLK2 (100MHz) from RXOUTCLK (100MHz)
    PLLE4_ADV #(
        .CLKFBOUT_MULT(8),          // Multiply value for all CLKOUT
        .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB
        .CLKIN_PERIOD(10.0),         // Input clock period in ns to ps resolution (i.e., 33.333 is 30 MHz).
        .CLKOUT0_DIVIDE(4),         // Divide amount for CLKOUT0
        .CLKOUT0_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT0
        .CLKOUT0_PHASE(0.0),        // Phase offset for CLKOUT0
        .CLKOUT1_DIVIDE(8),         // Divide amount for CLKOUT1
        .CLKOUT1_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT1
        .CLKOUT1_PHASE(0.0),        // Phase offset for CLKOUT1
        .CLKOUTPHY_MODE("VCO_2X"),  // Frequency of the CLKOUTPHY
        .COMPENSATION("AUTO"),      // Clock input compensation
        .DIVCLK_DIVIDE(1),          // Master division value
        .IS_CLKFBIN_INVERTED(1'b0), // Optional inversion for CLKFBIN
        .IS_CLKIN_INVERTED(1'b0),   // Optional inversion for CLKIN
        .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
        .IS_RST_INVERTED(1'b0),     // Optional inversion for RST
        .REF_JITTER(0.0),           // Reference input jitter in UI
        .STARTUP_WAIT("FALSE")      // Delays DONE until PLL is locked
    )
    PLLE4_ADV_inst (
        .CLKFBOUT(CLKFB),       // 1-bit output: Feedback clock
        .CLKOUT0(gtwiz_userclk_rx_usrclk),         // 1-bit output: General Clock output
        .CLKOUT0B(gtwiz_userclk_rx_usrclk_b),       // 1-bit output: Inverted CLKOUT0
        .CLKOUT1(gtwiz_userclk_rx_usrclk2),         // 1-bit output: General Clock output
        .CLKOUT1B(gtwiz_userclk_rx_usrclk2_b),       // 1-bit output: Inverted CLKOUT1
        .CLKOUTPHY(),     // 1-bit output: Bitslice clock
        .DO(),                   // 16-bit output: DRP data output
        .DRDY(drprdy),               // 1-bit output: DRP ready
        .LOCKED(LOCKED),           // 1-bit output: LOCK
        .CLKFBIN(CLKFB),         // 1-bit input: Feedback clock
        .CLKIN(gtwiz_userclk_rx_outclk),             // 1-bit input: Input clock
        .CLKOUTPHYEN(1'b0), // 1-bit input: CLKOUTPHY enable
        .DADDR(drpaddr),             // 7-bit input: DRP address
        .DCLK(drpclk),               // 1-bit input: DRP clock
        .DEN(drpen),                 // 1-bit input: DRP enable
        .DI(drpdi),                   // 16-bit input: DRP data input
        .DWE(drpwe),                 // 1-bit input: DRP write enable
        .PWRDWN(1'b0),           // 1-bit input: Power-down
        .RST(gtwiz_userclk_rx_reset_in)                  // 1-bit input: Reset
    );
    
endmodule
