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
//  Example TDL channel with VIOs for TX and RX data
//  Transmits a comma character every 1024 words
// ------------------------------------------------------------------------------------------------

module tdl_example_top (
    // mgtrefclk
    input  wire mgtrefclk_p,
    input  wire mgtrefclk_n,
    // mgtrefclk copy
    output wire mgtrefclk_buf,
    // recovered clock
    output wire rxrecclkout_p,
    output wire rxrecclkout_n,
    // data pairs
    input  wire gthrxn,
    input  wire gthrxp,
    output wire gthtxn,
    output wire gthtxp,
    // clock/reset
    input  wire clk_freerun,
    input  wire reset,
    // status
    output wire link_status,
    input wire reset_rx_datapath_in
);

    wire mgtrefclk;
    wire mgtrefclk_fabric;
    
    wire rxrecclkout;

    wire qpll0outclk;
    wire qpll0outrefclk;
    wire qpll0lock;
    wire qpll0reset;
    
    wire userclk_tx_reset;
    wire userclk_rx_reset;
    wire userclk_tx_active;
    wire userclk_rx_active;
    wire txpmaresetdone;
    wire rxpmaresetdone;
    
    wire txusrclk2;
    wire rxusrclk2;
    
    wire reset_sync;
    
    reg [15:0] txctrl0;
    reg [15:0] txctrl1;
    reg [7:0] txctrl2;
    wire [15:0] rxctrl0;
    wire [15:0] rxctrl1;
    wire [7:0] rxctrl2;
    wire [7:0] rxctrl3;
    
    reg [63:0] txdata;
    wire [63:0] rxdata;
    
    reg [9:0] tx_comma_cnt;
    
    wire [63:0] vio_txdata;
    reg [63:0] vio_rxdata;
    
    assign userclk_tx_reset = ~txpmaresetdone;
    assign userclk_rx_reset = ~rxpmaresetdone;
    
    assign link_status = rxaligned;
    
    // Transmit some BS data
    always @(posedge txusrclk2) begin
        txctrl0 <= 16'b0;
        txctrl1 <= 16'b0;
        tx_comma_cnt <= tx_comma_cnt + 1;
        if (~userclk_tx_active) begin
              txdata <= 64'b0;
              txctrl2 <= 8'b0;
        end
        else if (&tx_comma_cnt) begin
              txdata <= 64'hBC;
              txctrl2 <= 8'b1;
        end
        else begin
              txdata <= vio_txdata;
              txctrl2 <= 8'b0;
        end
    end
    
    // Receive data and discard commas
    always @(posedge rxusrclk2) begin
        if (~userclk_rx_active) begin
              vio_rxdata <= 64'b0;
        end
        else if (~rxaligned) begin
              vio_rxdata <= 64'hDEADBEEF12345678;
        end  
        else if (rxctrl2 == 8'b0) begin
              vio_rxdata <= rxdata;
        end
    end
    
    vio_tx vio_tx_i (
        .clk(txusrclk2),                // input wire clk
        .probe_out0(vio_txdata)  // output wire [63 : 0] probe_out0
    );
    
    vio_rx vio_rx_i (
        .clk(rxusrclk2),                // input wire clk
        .probe_in0(vio_rxdata)  // output wire [63 : 0] probe_out0
    );
    
    // MGTREFCLK input buffer
    IBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b00),
        .REFCLK_ICNTL_RX    (2'b00)
    ) IBUFDS_GTE4_MGTREFCLK_INST (
        .I     (mgtrefclk_p),
        .IB    (mgtrefclk_n),
        .CEB   (1'b0),
        .O     (mgtrefclk),
        .ODIV2 (mgtrefclk_fabric)
    );
  
    // MGTREFCLK fabric copy
    BUFG_GT #(
        .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
    )
    BUFG_GT_inst (
        .O(mgtrefclk_buf),             // 1-bit output: Buffer
        .CE(1'b1),           // 1-bit input: Buffer enable
        .CEMASK(1'b0),   // 1-bit input: CE Mask
        .CLR(1'b0),         // 1-bit input: Asynchronous clear
        .CLRMASK(1'b0), // 1-bit input: CLR Mask
        .DIV(3'b0),         // 3-bit input: Dynamic divide Value
        .I(mgtrefclk_fabric)              // 1-bit input: Buffer
    );

    // RXRECCLKOUT output buffer
    OBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH (1'b1),
        .REFCLK_ICNTL_TX   (5'b00111)
    ) OBUFDS_GTE4_INST (
        .O     (rxrecclkout_p),
        .OB    (rxrecclkout_n),
        .CEB   (1'b0),
        .I     (rxrecclkout)
    );

    // Synchronize reset
    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer_inst (
        .clk_in (clk_freerun),
        .i_in   (reset),
        .o_out  (reset_sync)
    );

    // GT Common instance
    tdl_gthe4_common_wrapper gthe4_common_wrapper_inst (
        .GTHE4_COMMON_BGBYPASSB         (1'b1),
        .GTHE4_COMMON_BGMONITORENB      (1'b1),
        .GTHE4_COMMON_BGPDB             (1'b1),
        .GTHE4_COMMON_BGRCALOVRD        (5'b11111),
        .GTHE4_COMMON_BGRCALOVRDENB     (1'b1),
        .GTHE4_COMMON_DRPADDR           (16'b0000000000000000),
        .GTHE4_COMMON_DRPCLK            (1'b0),
        .GTHE4_COMMON_DRPDI             (16'b0000000000000000),
        .GTHE4_COMMON_DRPEN             (1'b0),
        .GTHE4_COMMON_DRPWE             (1'b0),
        .GTHE4_COMMON_GTGREFCLK0        (1'b0),
        .GTHE4_COMMON_GTGREFCLK1        (1'b0),
        .GTHE4_COMMON_GTNORTHREFCLK00   (1'b0),
        .GTHE4_COMMON_GTNORTHREFCLK01   (1'b0),
        .GTHE4_COMMON_GTNORTHREFCLK10   (1'b0),
        .GTHE4_COMMON_GTNORTHREFCLK11   (1'b0),
        .GTHE4_COMMON_GTREFCLK00        (mgtrefclk),
        .GTHE4_COMMON_GTREFCLK01        (1'b0),
        .GTHE4_COMMON_GTREFCLK10        (1'b0),
        .GTHE4_COMMON_GTREFCLK11        (1'b0),
        .GTHE4_COMMON_GTSOUTHREFCLK00   (1'b0),
        .GTHE4_COMMON_GTSOUTHREFCLK01   (1'b0),
        .GTHE4_COMMON_GTSOUTHREFCLK10   (1'b0),
        .GTHE4_COMMON_GTSOUTHREFCLK11   (1'b0),
        .GTHE4_COMMON_PCIERATEQPLL0     (3'b000),
        .GTHE4_COMMON_PCIERATEQPLL1     (3'b000),
        .GTHE4_COMMON_PMARSVD0          (8'b00000000),
        .GTHE4_COMMON_PMARSVD1          (8'b00000000),
        .GTHE4_COMMON_QPLL0CLKRSVD0     (1'b0),
        .GTHE4_COMMON_QPLL0CLKRSVD1     (1'b0),
        .GTHE4_COMMON_QPLL0FBDIV        (8'b00000000),
        .GTHE4_COMMON_QPLL0LOCKDETCLK   (1'b0),
        .GTHE4_COMMON_QPLL0LOCKEN       (1'b1),
        .GTHE4_COMMON_QPLL0PD           (1'b0),
        .GTHE4_COMMON_QPLL0REFCLKSEL    (3'b001),
        .GTHE4_COMMON_QPLL0RESET        (qpll0reset),
        .GTHE4_COMMON_QPLL1CLKRSVD0     (1'b0),
        .GTHE4_COMMON_QPLL1CLKRSVD1     (1'b0),
        .GTHE4_COMMON_QPLL1FBDIV        (8'b00000000),
        .GTHE4_COMMON_QPLL1LOCKDETCLK   (1'b0),
        .GTHE4_COMMON_QPLL1LOCKEN       (1'b0),
        .GTHE4_COMMON_QPLL1PD           (1'b1),
        .GTHE4_COMMON_QPLL1REFCLKSEL    (3'b001),
        .GTHE4_COMMON_QPLL1RESET        (1'b1),
        .GTHE4_COMMON_QPLLRSVD1         (8'b00000000),
        .GTHE4_COMMON_QPLLRSVD2         (5'b00000),
        .GTHE4_COMMON_QPLLRSVD3         (5'b00000),
        .GTHE4_COMMON_QPLLRSVD4         (8'b00000000),
        .GTHE4_COMMON_RCALENB           (1'b1),
        .GTHE4_COMMON_SDM0DATA          (25'b0000000000000000000000000),
        .GTHE4_COMMON_SDM0RESET         (1'b0),
        .GTHE4_COMMON_SDM0TOGGLE        (1'b0),
        .GTHE4_COMMON_SDM0WIDTH         (2'b00),
        .GTHE4_COMMON_SDM1DATA          (25'b0000000000000000000000000),
        .GTHE4_COMMON_SDM1RESET         (1'b0),
        .GTHE4_COMMON_SDM1TOGGLE        (1'b0),
        .GTHE4_COMMON_SDM1WIDTH         (2'b00),
        .GTHE4_COMMON_TCONGPI           (10'b0000000000),
        .GTHE4_COMMON_TCONPOWERUP       (1'b0),
        .GTHE4_COMMON_TCONRESET         (2'b00),
        .GTHE4_COMMON_TCONRSVDIN1       (2'b00),
        .GTHE4_COMMON_DRPDO             (),
        .GTHE4_COMMON_DRPRDY            (),
        .GTHE4_COMMON_PMARSVDOUT0       (),
        .GTHE4_COMMON_PMARSVDOUT1       (),
        .GTHE4_COMMON_QPLL0FBCLKLOST    (),
        .GTHE4_COMMON_QPLL0LOCK         (qpll0lock),
        .GTHE4_COMMON_QPLL0OUTCLK       (qpll0outclk),
        .GTHE4_COMMON_QPLL0OUTREFCLK    (qpll0outrefclk),
        .GTHE4_COMMON_QPLL0REFCLKLOST   (),
        .GTHE4_COMMON_QPLL1FBCLKLOST    (),
        .GTHE4_COMMON_QPLL1LOCK         (),
        .GTHE4_COMMON_QPLL1OUTCLK       (),
        .GTHE4_COMMON_QPLL1OUTREFCLK    (),
        .GTHE4_COMMON_QPLL1REFCLKLOST   (),
        .GTHE4_COMMON_QPLLDMONITOR0     (),
        .GTHE4_COMMON_QPLLDMONITOR1     (),
        .GTHE4_COMMON_REFCLKOUTMONITOR0 (),
        .GTHE4_COMMON_REFCLKOUTMONITOR1 (),
        .GTHE4_COMMON_RXRECCLK0SEL      (),
        .GTHE4_COMMON_RXRECCLK1SEL      (),
        .GTHE4_COMMON_SDM0FINALOUT      (),
        .GTHE4_COMMON_SDM0TESTDATA      (),
        .GTHE4_COMMON_SDM1FINALOUT      (),
        .GTHE4_COMMON_SDM1TESTDATA      (),
        .GTHE4_COMMON_TCONGPO           (),
        .GTHE4_COMMON_TCONRSVDOUT0      ()
    );
    
    // TDL instance
    tdl_wrapper tdl_wrapper_inst (
         .gthrxn_in                            (gthrxn)
        ,.gthrxp_in                            (gthrxp)
        ,.gthtxn_out                           (gthtxn)
        ,.gthtxp_out                           (gthtxp)
        ,.txoutclk_out                         ()
        ,.txusrclk_out                         ()
        ,.txusrclk2_out                        (txusrclk2)
        ,.userclk_tx_reset_in                  (userclk_tx_reset)
        ,.userclk_tx_active_out                (userclk_tx_active)
        ,.rxoutclk_out                         ()
        ,.rxusrclk_out                         ()
        ,.rxusrclk2_out                        (rxusrclk2)
        ,.userclk_rx_reset_in                  (userclk_rx_reset)
        ,.userclk_rx_active_out                (userclk_rx_active)
        ,.reset_clk_freerun_in                 (clk_freerun)
        ,.reset_all_in                         (reset_sync)
        ,.reset_tx_pll_and_datapath_in         (1'b0)
        ,.reset_tx_datapath_in                 (1'b0)
        ,.reset_rx_pll_and_datapath_in         (1'b0)
        ,.reset_rx_datapath_in                 (reset_rx_datapath_in)
        ,.reset_rx_cdr_stable_out              ()
        ,.reset_tx_done_out                    ()
        ,.reset_rx_done_out                    ()
        ,.qpll0outclk_in                       (qpll0outclk)
        ,.qpll0outrefclk_in                    (qpll0outrefclk)
        ,.qpll0lock_in                         (qpll0lock)
        ,.qpll0reset_out                       (qpll0reset)
        ,.userdata_tx_in                       (txdata)
        ,.txctrl0_in                           (txctrl0)
        ,.txctrl1_in                           (txctrl1)
        ,.txctrl2_in                           (txctrl2)
        ,.userdata_rx_out                      (rxdata)
        ,.rxctrl0_out                          (rxctrl0)
        ,.rxctrl1_out                          (rxctrl1)
        ,.rxctrl2_out                          (rxctrl2)
        ,.rxctrl3_out                          (rxctrl3)
        ,.gtpowergood_out                      ()
        ,.txpmaresetdone_out                   (txpmaresetdone)
        ,.rxpmaresetdone_out                   (rxpmaresetdone)
        ,.txframeclk_in                        (mgtrefclk_buf)
        ,.rxrecclkout_out                      (rxrecclkout)
        ,.rxaligned_out                        (rxaligned)
    );

endmodule
