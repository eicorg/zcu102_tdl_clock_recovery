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
//  Ties together the RX and TX blocks necessary for a complete TDL channel
//  Implements a simple retry timeout counter if the link is down to reset the
//  reciever to recover if the CDR gets into a bad state
// ------------------------------------------------------------------------------------------------

module tdl_wrapper (
    // Transceiver data pairs
     input  wire        gthrxn_in
    ,input  wire        gthrxp_in
    ,output wire        gthtxn_out
    ,output wire        gthtxp_out
    // Transmitter clock/reset
    ,output wire        txoutclk_out
    ,output wire        txusrclk_out
    ,output wire        txusrclk2_out
    ,input  wire        userclk_tx_reset_in
    ,output wire        userclk_tx_active_out
    // Receiver clock/reset
    ,output wire        rxoutclk_out
    ,output wire        rxusrclk_out
    ,output wire        rxusrclk2_out
    ,input  wire        userclk_rx_reset_in
    ,output wire        userclk_rx_active_out
    // Free running system clock/reset
    ,input  wire        reset_clk_freerun_in
    ,input  wire        reset_all_in
    ,input  wire        reset_tx_pll_and_datapath_in
    ,input  wire        reset_tx_datapath_in
    ,input  wire        reset_rx_pll_and_datapath_in
    ,input  wire        reset_rx_datapath_in
    ,output wire        reset_rx_cdr_stable_out
    ,output wire        reset_tx_done_out
    ,output wire        reset_rx_done_out
    // QPLL clock/reset
    ,input  wire        qpll0outclk_in
    ,input  wire        qpll0outrefclk_in
    ,input  wire        qpll0lock_in
    ,output wire        qpll0reset_out
    // Transmit data
    ,input  wire [63:0] userdata_tx_in
    ,input  wire [15:0] txctrl0_in
    ,input  wire [15:0] txctrl1_in
    ,input  wire [7:0]  txctrl2_in
    // Receive data
    ,output wire [63:0] userdata_rx_out
    ,output wire [15:0] rxctrl0_out
    ,output wire [15:0] rxctrl1_out
    ,output wire [7:0]  rxctrl2_out
    ,output wire [7:0]  rxctrl3_out
    // GT signals
    ,output wire        gtpowergood_out
    ,output wire        txpmaresetdone_out
    ,output wire        rxpmaresetdone_out
    // Transmitter frame clock
    ,input  wire        txframeclk_in
    // Receiver frame clock
    ,output wire        rxrecclkout_out
    // Receiver is aligned
    ,output wire        rxaligned_out
);

    wire        dmonitorclk_int;
    wire [15:0] dmonitorout_int;

    wire [9:0]  drpaddr_int;
    wire        drpclk_int;
    wire [15:0] drpdi_int;
    wire        drpen_int;
    wire        drpwe_int;
    wire [15:0] drpdo_int;
    wire        drprdy_int;

    wire [2:0]  rxrate_int;
    wire [2:0]  rxoutclksel_int;
    wire        rxcdrovrden_int;
    wire        rx8b10ben_int;
    wire        rxcommadeten_int;
    wire        rxmcommaalignen_int;
    wire        rxpcommaalignen_int;

    wire        rxphaligndone_int;
    wire        rxdlysresetdone_int;
    wire        rxsyncout_int;
    wire        rxsyncdone_int;
    wire        rxphdlyreset_int;
    wire        rxphalign_int;
    wire        rxphalignen_int;
    wire        rxphdlypd_int;
    wire        rxphovrden_int;
    wire        rxdlysreset_int;
    wire        rxdlybypass_int;
    wire        rxdlyen_int;
    wire        rxdlyovrden_int;
    wire        rxsyncmode_int;
    wire        rxsyncallin_int;
    wire        rxsyncin_int;

    wire        tx8b10ben_int;
    wire        txpippmen_int;
    wire        txpippmsel_int;
    wire [4:0]  txpippmstepsize_int;

    wire        rxcdrlock_int;
    wire        txresetdone_int;
    wire        rxresetdone_int;
    wire        txresetdone_sync;
    wire        rxresetdone_sync;
    wire        pllreset_tx_int;
    wire        pllreset_rx_int;
    wire        reset_rxprogdivreset_int;
    wire        align_rxprogdivreset_int;
    wire        rxprgdivresetdone_int;
    wire        txprogdivreset_int;
    wire        gttxreset_int;
    wire        txuserrdy_int;
    wire        gtrxreset_int;
    wire        rxuserrdy_int;
    wire        rxprogdivreset_int;

    wire [15:0] pll_drpdi_int;
    wire [6:0]  pll_drpaddr_int;
    wire        pll_drprdy_int;
    wire        pll_drpwe_int;
    wire        pll_drpen_int;
    wire        pll_drpclk_int;

    wire        inv_rxusrclk_int;
    wire        inv_rxusrclk2_int;

    wire        bitslip_int;
    wire        bitslip_rdy_int;
    
    wire        reset_rx_datapath_int;
    wire        rxaligned_sync;
    reg [23:0]  reset_rx_retry_cnt;

    // Always transmit 8b10b data
    assign tx8b10ben_int = 1'b1;

    // RX and TX use same PLL
    assign qpll0reset_out = pllreset_tx_int | pllreset_rx_int;

    // Allow phase aligner to reset rx programmable divider
    assign rxprogdivreset_int  = reset_rxprogdivreset_int | align_rxprogdivreset_int;
    
    // Reset receiver if link is not up after timeout
    assign reset_rx_datapath_int = reset_rx_datapath_in | &reset_rx_retry_cnt;
    
    // Retry timeout counter
    always @(posedge reset_clk_freerun_in) begin
        if (~rxresetdone_sync | rxaligned_sync) begin
            reset_rx_retry_cnt <= 24'b0;
        end
        else if (~reset_rx_cdr_stable_out | |reset_rx_retry_cnt) begin
            reset_rx_retry_cnt <= reset_rx_retry_cnt + 1;
        end
    end

    // TX clocking network
    gtwiz_userclk_tx gtwiz_userclk_tx_inst (
        .gtwiz_userclk_tx_srcclk_in   (txoutclk_out),
        .gtwiz_userclk_tx_reset_in    (userclk_tx_reset_in),
        .gtwiz_userclk_tx_usrclk_out  (txusrclk_out),
        .gtwiz_userclk_tx_usrclk2_out (txusrclk2_out),
        .gtwiz_userclk_tx_active_out  (userclk_tx_active_out)
    );

    // RX clocking network
    gtwiz_userclk_rx gtwiz_userclk_rx_inst (
        .gtwiz_userclk_rx_srcclk_in     (rxoutclk_out),
        .gtwiz_userclk_rx_reset_in      (userclk_rx_reset_in | userclk_rx_reset_int),
        .gtwiz_userclk_rx_usrclk_out    (rxusrclk_out),
        .gtwiz_userclk_rx_usrclk2_out   (rxusrclk2_out),
        .gtwiz_userclk_rx_active_out    (userclk_rx_active_out),
        .drpclk                         (pll_drpclk_int),
        .drpen                          (pll_drpen_int),
        .drpwe                          (pll_drpwe_int),
        .drprdy                         (pll_drprdy_int),
        .drpaddr                        (pll_drpaddr_int),
        .drpdi                          (pll_drpdi_int),
        .inv_rxusrclk                   (inv_rxusrclk_int),
        .inv_rxusrclk2                  (inv_rxusrclk2_int)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer_rxaligned_inst (
        .clk_in (reset_clk_freerun_in),
        .i_in   (rxaligned_out),
        .o_out  (rxaligned_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer_txresetdone_inst (
        .clk_in (reset_clk_freerun_in),
        .i_in   (txresetdone_int),
        .o_out  (txresetdone_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer_rxresetdone_inst (
        .clk_in (reset_clk_freerun_in),
        .i_in   (rxresetdone_int),
        .o_out  (rxresetdone_sync)
    );

    // Reset controller
    (* DONT_TOUCH = "TRUE" *)
    gtwiz_reset gtwiz_reset_inst (
        .gtwiz_reset_clk_freerun_in         (reset_clk_freerun_in),
        .gtwiz_reset_all_in                 (reset_all_in),
        .gtwiz_reset_tx_pll_and_datapath_in (reset_tx_pll_and_datapath_in),
        .gtwiz_reset_tx_datapath_in         (reset_tx_datapath_in),
        .gtwiz_reset_rx_pll_and_datapath_in (reset_rx_pll_and_datapath_in),
        .gtwiz_reset_rx_datapath_in         (reset_rx_datapath_int),
        .gtwiz_reset_rx_cdr_stable_out      (reset_rx_cdr_stable_out),
        .gtwiz_reset_tx_done_out            (reset_tx_done_out),
        .gtwiz_reset_rx_done_out            (reset_rx_done_out),
        .gtwiz_reset_userclk_tx_active_in   (userclk_tx_active_out),
        .gtwiz_reset_userclk_rx_active_in   (userclk_rx_active_out),
        .gtpowergood_in                     (gtpowergood_out),
        .txusrclk2_in                       (txusrclk2_out),
        .plllock_tx_in                      (qpll0lock_in),
        .txresetdone_in                     (txresetdone_sync),
        .rxusrclk2_in                       (rxusrclk2_out),
        .plllock_rx_in                      (qpll0lock_in),
        .rxcdrlock_in                       (rxcdrlock_int),
        .rxresetdone_in                     (rxresetdone_sync),
        .pllreset_tx_out                    (pllreset_tx_int),
        .txprogdivreset_out                 (txprogdivreset_int),
        .gttxreset_out                      (gttxreset_int),
        .txuserrdy_out                      (txuserrdy_int),
        .pllreset_rx_out                    (pllreset_rx_int),
        .rxprogdivreset_out                 (reset_rxprogdivreset_int),
        .gtrxreset_out                      (gtrxreset_int),
        .rxuserrdy_out                      (rxuserrdy_int),
        .tx_enabled_tie_in                  (1'b1),
        .rx_enabled_tie_in                  (1'b1),
        .shared_pll_tie_in                  (1'b1)
    );

    // GT IP instance
    tdl_gth tdl_gth_inst (
        .gthrxn_in                     (gthrxn_in),
        .gthrxp_in                     (gthrxp_in),
        .gthtxn_out                    (gthtxn_out),
        .gthtxp_out                    (gthtxp_out),
        .gtwiz_userclk_tx_active_in    (userclk_tx_active_out),
        .gtwiz_userclk_rx_active_in    (userclk_rx_active_out),
        .gtwiz_reset_tx_done_in        (reset_tx_done_out),
        .gtwiz_reset_rx_done_in        (reset_rx_done_out),
        .gtwiz_userdata_tx_in          (userdata_tx_in),
        .gtwiz_userdata_rx_out         (userdata_rx_out),
        .dmonitorclk_in                (dmonitorclk_int),
        .drpaddr_in                    (drpaddr_int),
        .drpclk_in                     (drpclk_int),
        .drpdi_in                      (drpdi_int),
        .drpen_in                      (drpen_int),
        .drpwe_in                      (drpwe_int),
        .gtrxreset_in                  (gtrxreset_int),
        .gttxreset_in                  (gttxreset_int),
        .qpll0clk_in                   (qpll0outclk_in),
        .qpll0refclk_in                (qpll0outrefclk_in),
        .qpll1clk_in                   (1'b0),
        .qpll1refclk_in                (1'b0),
        .rx8b10ben_in                  (rx8b10ben_int),
        .rxcdrovrden_in                (rxcdrovrden_int),
        .rxcommadeten_in               (rxcommadeten_int),
        .rxdlybypass_in                (rxdlybypass_int),
        .rxdlyen_in                    (rxdlyen_int),
        .rxdlyovrden_in                (rxdlyovrden_int),
        .rxdlysreset_in                (rxdlysreset_int),
        .rxmcommaalignen_in            (rxmcommaalignen_int),
        .rxoutclksel_in                (rxoutclksel_int),
        .rxpcommaalignen_in            (rxpcommaalignen_int),
        .rxphalign_in                  (rxphalign_int),
        .rxphalignen_in                (rxphalignen_int),
        .rxphdlypd_in                  (rxphdlypd_int),
        .rxphdlyreset_in               (rxphdlyreset_int),
        .rxphovrden_in                 (rxphovrden_int),
        .rxprogdivreset_in             (rxprogdivreset_int),
        .rxrate_in                     (rxrate_int),
        .rxslide_in                    (rxslide_int),
        .rxsyncallin_in                (rxsyncallin_int),
        .rxsyncin_in                   (rxsyncin_int),
        .rxsyncmode_in                 (rxsyncmode_int),
        .rxuserrdy_in                  (rxuserrdy_int),
        .rxusrclk_in                   (rxusrclk_out),
        .rxusrclk2_in                  (rxusrclk2_out),
        .tx8b10ben_in                  (tx8b10ben_int),
        .txctrl0_in                    (txctrl0_in),
        .txctrl1_in                    (txctrl1_in),
        .txctrl2_in                    (txctrl2_in),
        .txpippmen_in                  (txpippmen_int),
        .txpippmsel_in                 (txpippmsel_int),
        .txpippmstepsize_in            (txpippmstepsize_int),
        .txprogdivreset_in             (txprogdivreset_int),
        .txuserrdy_in                  (txuserrdy_int),
        .txusrclk_in                   (txusrclk_out),
        .txusrclk2_in                  (txusrclk2_out),
        .dmonitorout_out               (dmonitorout_int),
        .drpdo_out                     (drpdo_int),
        .drprdy_out                    (drprdy_int),
        .gtpowergood_out               (gtpowergood_out),
        .rxbyteisaligned_out           (),
        .rxbyterealign_out             (),
        .rxcdrlock_out                 (rxcdrlock_int),
        .rxcommadet_out                (),
        .rxctrl0_out                   (rxctrl0_out),
        .rxctrl1_out                   (rxctrl1_out),
        .rxctrl2_out                   (rxctrl2_out),
        .rxctrl3_out                   (rxctrl3_out),
        .rxdlysresetdone_out           (rxdlysresetdone_int),
        .rxoutclk_out                  (rxoutclk_out),
        .rxphaligndone_out             (rxphaligndone_int),
        .rxpmaresetdone_out            (rxpmaresetdone_out),
        .rxprgdivresetdone_out         (rxprgdivresetdone_int),
        .rxrecclkout_out               (rxrecclkout_out),
        .rxresetdone_out               (rxresetdone_int),
        .rxsyncdone_out                (rxsyncdone_int),
        .rxsyncout_out                 (rxsyncout_int),
        .txoutclk_out                  (txoutclk_out),
        .txpmaresetdone_out            (txpmaresetdone_out),
        .txresetdone_out               (txresetdone_int)
    );

    // RX word alignment
    rxdata_aligner rxdata_aligner_inst (
        .rxusrclk2          (rxusrclk2_out      ),
        .rst                (~reset_rx_done_out ),
        .rxcdrlock          (rxcdrlock_int      ),
        .rxctrl1            (rxctrl1_out        ),
        .rxctrl2            (rxctrl2_out        ),
        .rxctrl3            (rxctrl3_out        ),
        .bitslip_rdy        (bitslip_rdy_int    ),
        .bitslip            (bitslip_int        ),
        .aligned            (rxaligned_out      ),
        .rxcommadeten       (rxcommadeten_int   ),
        .rxmcommaalignen    (rxmcommaalignen_int),
        .rxpcommaalignen    (rxpcommaalignen_int),
        .rx8b10ben          (rx8b10ben_int      )
    );

    // RX clock phase alignment
    rxrecclk_phase_aligner rxrecclk_phase_aligner_inst (
        .clk_freerun        (reset_clk_freerun_in       ),
        .rxusrclk2          (rxusrclk2_out              ),
        .rst_rxusrclk2      (~reset_rx_done_out         ),
        .userclk_rx_active  (userclk_rx_active_out      ),
        .userclk_rx_reset   (userclk_rx_reset_int       ),
        .inv_rxusrclk       (inv_rxusrclk_int           ),
        .inv_rxusrclk2      (inv_rxusrclk2_int          ),
        .bitslip            (bitslip_int                ),
        .bitslip_rdy        (bitslip_rdy_int            ),
        .pll_drpclk         (pll_drpclk_int             ),
        .pll_drpen          (pll_drpen_int              ),
        .pll_drpwe          (pll_drpwe_int              ),
        .pll_drprdy         (pll_drprdy_int             ),
        .pll_drpaddr        (pll_drpaddr_int            ),
        .pll_drpdi          (pll_drpdi_int              ),
        .mgt_drpclk         (drpclk_int                 ),
        .mgt_drpen          (drpen_int                  ),
        .mgt_drpwe          (drpwe_int                  ),
        .mgt_drprdy         (drprdy_int                 ),
        .mgt_drpaddr        (drpaddr_int                ),
        .mgt_drpdi          (drpdi_int                  ),
        .mgt_drpdo          (drpdo_int                  ),
        .dmonitorclk        (dmonitorclk_int            ),
        .dmonitorout        (dmonitorout_int            ),
        .rxdlysresetdone    (rxdlysresetdone_int        ),
        .rxphaligndone      (rxphaligndone_int          ),
        .rxprgdivresetdone  (rxprgdivresetdone_int      ),
        .rxsyncdone         (rxsyncdone_int             ),
        .rxsyncout          (rxsyncout_int              ),
        .rxcdrovrden        (rxcdrovrden_int            ),
        .rxdlybypass        (rxdlybypass_int            ),
        .rxdlyen            (rxdlyen_int                ),
        .rxdlyovrden        (rxdlyovrden_int            ),
        .rxdlysreset        (rxdlysreset_int            ),
        .rxoutclksel        (rxoutclksel_int            ),
        .rxphalign          (rxphalign_int              ),
        .rxphalignen        (rxphalignen_int            ),
        .rxphdlypd          (rxphdlypd_int              ),
        .rxphdlyreset       (rxphdlyreset_int           ),
        .rxphovrden         (rxphovrden_int             ),
        .rxprogdivreset     (align_rxprogdivreset_int   ),
        .rxrate             (rxrate_int                 ),
        .rxslide            (rxslide_int                ),
        .rxsyncallin        (rxsyncallin_int            ),
        .rxsyncin           (rxsyncin_int               ),
        .rxsyncmode         (rxsyncmode_int             )
    );

    // TX clock phase alignment
    tx_phase_aligner tx_phase_aligner_inst (
        .rst            (~reset_tx_done_out ),
        .refclk         (txframeclk_in      ),
        .fbclk          (txusrclk2_out      ),
        .txpippmstepsize(txpippmstepsize_int),
        .txpippmen      (txpippmen_int      ),
        .txpippmsel     (txpippmsel_int     )
    );

endmodule
