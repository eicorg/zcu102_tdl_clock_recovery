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
//
//  *** THIS IS PROBABLY NOT RECOMMENDED BY XILINX ***
//
// ------------------------------------------------------------------------------------------------

module rxrecclk_phase_aligner
(
    // Clocking
    input  logic        clk_freerun,
    input  logic        rxusrclk2,
    input  logic        rst_rxusrclk2,
    input  logic        userclk_rx_active,
    output logic        userclk_rx_reset,
    output logic        inv_rxusrclk,
    output logic        inv_rxusrclk2,
    // User bit shift
    input  logic        bitslip,
    output logic        bitslip_rdy,
    // PLL DRP
    output logic        pll_drpclk,
    output logic        pll_drpen,
    output logic        pll_drpwe,
    input  logic        pll_drprdy,
    output logic [6:0]  pll_drpaddr,
    output logic [15:0] pll_drpdi,
    // MGT DRP
    output logic        mgt_drpclk,
    output logic        mgt_drpen,
    output logic        mgt_drpwe,
    input  logic        mgt_drprdy,
    output logic [9:0]  mgt_drpaddr,
    output logic [15:0] mgt_drpdi,
    input  logic [15:0] mgt_drpdo,
    // MGT DMONITOR
    output logic        dmonitorclk,
    input  logic [15:0] dmonitorout,
    // MGT RX signals
    input  logic        rxdlysresetdone,
    input  logic        rxphaligndone,
    input  logic        rxprgdivresetdone,
    input  logic        rxsyncdone,
    input  logic        rxsyncout,
    output logic        rxcdrovrden,
    output logic        rxdlybypass,
    output logic        rxdlyen,
    output logic        rxdlyovrden,
    output logic        rxdlysreset,
    output logic [2:0]  rxoutclksel,
    output logic        rxphalign,
    output logic        rxphalignen,
    output logic        rxphdlypd,
    output logic        rxphdlyreset,
    output logic        rxphovrden,
    output logic        rxprogdivreset,
    output logic [2:0]  rxrate,
    output logic        rxslide,
    output logic        rxsyncallin,
    output logic        rxsyncin,
    output logic        rxsyncmode
);

    // Clock frequency ratios
    localparam RATIO_PLL_FREQ_BIT_RATE      = 1;
    localparam RATIO_BIT_RATE_RXUSRCLK      = 40;
    
    // PLL DRP addresses
    localparam PLL_DRP_ADDR_CKOUT0_FREQ     = 7'h08;
    localparam PLL_DRP_ADDR_CKOUT0_DLY      = 7'h09;
    
    // MGT DRP addresses
    localparam MGT_DRP_ADDR_RXCDR_CFG1      = 10'h00F;
    localparam MGT_DRP_ADDR_DMONITOR_CFG1   = 10'h03A;
    localparam MGT_DRP_ADDR_RXSLIDE_MODE    = 10'h064;
    
    // Mask out desired fields
    localparam MASK_DMONITOR_CFG1           = 16'h00FF;
    localparam MASK_RXSLIDE_MODE            = 16'hF9FF;
    
    // Clocks are considered to be aligned when the delay tap values are within this window
    // 4ns / 256 = 15.625ps / tap
    // Somewhat arbitrary, big enough to allow for variations, small enough to not align to wrong edge
    // This difference is due to routing delays inside the GT and shouldn't change much over PVT
    localparam ALIGN_DLY_THRESHOLD_LO       = 2;
    localparam ALIGN_DLY_THRESHOLD_HI       = 5;
    
    // CDR PI step size for bitslip operation
    localparam CDR_STEP_SIZE                = 32;
    
    // Number of CDR PI steps for one bitslip
    localparam CDR_NUM_STEPS                = (128 / CDR_STEP_SIZE) * RATIO_PLL_FREQ_BIT_RATE;

    // FSM states
    typedef enum {
        reset_s,
        mgt_config_dmonitor_read_s,
        mgt_config_dmonitor_phalign_s,
        mgt_config_rxslide_read_s,
        mgt_config_rxslide_pma_s,
        pll_config_ckout0_freq,
        pll_config_ckout0_dly,
        pll_reset_s,
        rxphalign_wait_s,
        rxphalign_dly_dwell_s,
        rxphalign_dly_avg_s,
        rxphalign_dly_check_s,
        rxoutclkpcs_shift_s,
        rxprogdivclk_reset_s,
        mgt_config_rxslide_pcs_s,
        rxdata_shift_s,
        mgt_config_dmonitor_cdr_s,
        idle_s,
        bitslip_cdr_s
    } state_t;

    state_t state;

    // DRP Register values
    logic [15:0]    dmonitor_cfg1_reg;
    logic [15:0]    rxslide_mode_reg;
    
    // Counters
    logic [15:0]    rxprgdivreset_wait_cnt;
    logic [15:0]    rxdlysreset_wait_cnt;
    logic [15:0]    dly_dwell_cnt;
    
    // RXOUTCLKPCS delay measurements
    logic [7:0]     rxoutclkpcs_dly_fine;
    logic           rxoutclkpcs_dly_180;
    logic           rxoutclkpcs_dly_90;
    logic           rxoutclkpcs_dly_valid;
    
    // Phase alignment delay accumulator
    logic [7:0]     dly_avg_cnt;
    logic [15:0]    dly_avg_acc;
    
    // Counters
    logic [6:0]     rxslide_shift_cnt;
    logic [5:0]     rxslide_wait_cnt;
    logic [7:0]     rxcdr_step_cnt;
    logic [6:0]     rxcdr_pi_val;
    
    // CDC signals
    logic           bitslip_sync;
    logic           bitslip_sync_q;
    logic           rxprgdivresetdone_sync;
    logic           rxprgdivresetdone_sync_q;
    logic           rxsyncdone_sync;
    logic           rxsyncdone_sync_q;
    logic           rxphaligndone_sync;
    logic           userclk_rx_active_sync;
    logic           userclk_rx_active_sync_q;
    logic           rxslide_toggle_rxusrclk2;
    logic           rxslide_toggle_rxusrclk2_sync;
    logic           rxslide_toggle_rxusrclk2_sync_q;
    logic           rxslide_toggle_clk_freerun;
    logic           rxslide_toggle_clk_freerun_sync;
    
    // Number of bit shifts required for alignment
    logic [6:0]     align_shift_cnt;
    logic           align_shift_cnt_valid;
    
    // How many times RXUSRCLK has been inverted
    logic [1:0]     inv_rxusrclk_cnt;
    
    // Delay measurement within valid range
    logic           dly_valid;
    
    // Delays are matched within threshold
    logic           dly_match;
    
    // Initial phase alignment enabled
    logic           phalign_init;
    
    // Bitslip sync signals
    logic           bitslip_q;
    logic           bitslip_toggle;
    logic           bitslip_toggle_sync;
    logic           bitslip_toggle_sync_q;
    logic           bitslip_rdy_clk_freerun;
    
    // Single lane auto buffer bypass mode
    assign rxphdlyreset = 1'b0;
    assign rxphalign    = 1'b0;
    assign rxphalignen  = 1'b0;
    assign rxphdlypd    = 1'b0;
    assign rxphovrden   = 1'b0;
    assign rxdlybypass  = 1'b0;
    assign rxdlyen      = 1'b0;
    assign rxdlyovrden  = 1'b0;
    assign rxsyncmode   = 1'b1;
    assign rxsyncallin  = rxphaligndone;
    assign rxsyncin     = 1'b0;

    // Use system clock as DRP clock and DMONITOR clock
    assign dmonitorclk  = clk_freerun;
    assign mgt_drpclk   = clk_freerun;
    assign pll_drpclk   = clk_freerun;
    
    // Invert RXUSRCLK
    assign inv_rxusrclk = inv_rxusrclk_cnt[0];

    // RXOUTCLKPCS delay measurement is within the valid range
    assign dly_valid = dly_avg_acc[15:8] inside {[1:254-ALIGN_DLY_THRESHOLD_HI]};

    // RXPROGDIVCLK delay matches RXOUTCLKPCS delay within threshold
    assign dly_match = dly_avg_acc[15:8] - rxoutclkpcs_dly_fine inside {[ALIGN_DLY_THRESHOLD_LO:ALIGN_DLY_THRESHOLD_HI]};
    
    // State transitions
    always @(posedge clk_freerun) begin
        if (rst_clk_freerun)
            state <= reset_s;
        else case (state)
            // Reset
            reset_s:
                state <= mgt_config_dmonitor_read_s;
            // Read DMONITOR configuration register
            mgt_config_dmonitor_read_s:
                if (mgt_drpen & mgt_drprdy)
                    state <= mgt_config_dmonitor_phalign_s;
            // Write DMONITOR configuration register to monitor Delay Aligner tap value
            mgt_config_dmonitor_phalign_s:    
                if (mgt_drpen & mgt_drprdy)
                    state <= mgt_config_rxslide_read_s;
            // Read RXSLIDE configuration register
            mgt_config_rxslide_read_s:    
                if (mgt_drpen & mgt_drprdy)
                    state <= mgt_config_rxslide_pma_s;
            // Write RXSLIDE configuration register to select RXSLIDE PMA mode
            mgt_config_rxslide_pma_s:
                if (mgt_drpen & mgt_drprdy)
                    state <= pll_config_ckout0_freq;
            // Configure RXUSRCLK frequency
            pll_config_ckout0_freq:
                if (pll_drpen & pll_drprdy)
                    state <= pll_config_ckout0_dly;
            // Configure RXUSRCLK delay 
            pll_config_ckout0_dly:
                if (pll_drpen & pll_drprdy)
                    state <= pll_reset_s;
            // Reset PLL
            pll_reset_s:
                if (userclk_rx_active_sync & ~userclk_rx_active_sync_q)
                    state <= rxoutclkpcs_dly_valid ? rxphalign_wait_s : rxphalign_dly_dwell_s;
            // Wait for phase alignment to complete
            rxphalign_wait_s:
                if (rxsyncdone_sync & ~rxsyncdone_sync_q & rxphaligndone_sync)
                    state <= rxphalign_dly_dwell_s; 
            // Wait for delay reading to settle
            rxphalign_dly_dwell_s:
                if (&dly_dwell_cnt)
                    state <= rxphalign_dly_avg_s;
            // Average delay reading
            rxphalign_dly_avg_s:
                if (&dly_avg_cnt)
                    state <= rxphalign_dly_check_s;
            // Check delay reading
            rxphalign_dly_check_s:
                if (rxoutclkpcs_dly_valid)
                    if (rxslide_shift_cnt == RATIO_BIT_RATE_RXUSRCLK * 2)
                        state <= align_shift_cnt_valid ? mgt_config_rxslide_pcs_s : rxprogdivclk_reset_s;
                    else
                        state <= rxoutclkpcs_shift_s;
                else if (dly_valid)
                    state <= pll_config_ckout0_freq;
                else
                    state <= &inv_rxusrclk_cnt ? pll_config_ckout0_dly : rxphalign_dly_dwell_s;
            // Shift RXOUTCLKPCS two bits at a time
            rxoutclkpcs_shift_s:
                if ((rxslide_toggle_rxusrclk2_sync ^ rxslide_toggle_rxusrclk2_sync_q) & ~rxslide_shift_cnt[0])
                    state <= rxphalign_dly_dwell_s;
            // Reset RXPROGDIVCLK
            rxprogdivclk_reset_s:
                if (rxprgdivresetdone_sync & ~rxprgdivresetdone_sync_q)
                    state <= pll_reset_s;
            // Write RXSLIDE configuration register to select RXSLIDE PCS mode
            mgt_config_rxslide_pcs_s:
                if (mgt_drpen & mgt_drprdy)
                    state <= |align_shift_cnt ? rxdata_shift_s : mgt_config_dmonitor_cdr_s;
            // Shift PCS parallel data shifter
            rxdata_shift_s:
                if ((rxslide_toggle_rxusrclk2_sync ^ rxslide_toggle_rxusrclk2_sync_q) & (rxslide_shift_cnt == align_shift_cnt))
                    state <= mgt_config_dmonitor_cdr_s;
            // Write DMONITOR configuration register to monitor CDR PI tap value
            mgt_config_dmonitor_cdr_s:
                if (mgt_drpen & mgt_drprdy)
                    state <= idle_s;
            // Ready for bitslip
            idle_s:
                if (bitslip_toggle_sync ^ bitslip_toggle_sync_q)
                    state <= bitslip_cdr_s;
            // Slip one bit
            bitslip_cdr_s:
                if (mgt_drpen & mgt_drprdy & rxcdr_step_cnt == CDR_NUM_STEPS)
                    state <= idle_s;
        endcase
    end
    
    // Enable phase alignment once PLL is locked
    always @(posedge clk_freerun) begin
        rxdlysreset <= state == pll_reset_s & (~phalign_init | rxoutclkpcs_dly_valid) & userclk_rx_active_sync & ~userclk_rx_active_sync_q;
        if (state == reset_s)
            phalign_init <= 1'b0;
        else if (rxdlysreset)
            phalign_init <= 1'b1;
    end
    
    // RXOUTCLKPCS delay measurements
    always @(posedge clk_freerun) begin
        if (state == reset_s) begin
            rxoutclkpcs_dly_180 <= 1'b0;
            rxoutclkpcs_dly_fine <= 8'b0;
            inv_rxusrclk_cnt <= 2'b0;
            rxoutclkpcs_dly_valid <= 1'b0;
            rxoutclkpcs_dly_90 <= 1'b0;
        end
        else if (state == rxphalign_dly_check_s & ~rxoutclkpcs_dly_valid) begin
            if (dly_valid) begin
                rxoutclkpcs_dly_180 <= inv_rxusrclk;
                rxoutclkpcs_dly_fine <= dly_avg_acc[15:8];
                inv_rxusrclk_cnt <= 2'b0;
                rxoutclkpcs_dly_valid <= 1'b1;
            end
            else begin
                inv_rxusrclk_cnt <= inv_rxusrclk_cnt + 1;
                rxoutclkpcs_dly_90 <= rxoutclkpcs_dly_90 ^ &inv_rxusrclk_cnt;
            end
        end
    end
    
    // Dwell time to let delay tap value settle
    always @(posedge clk_freerun) begin
        if (state == rxphalign_dly_dwell_s)
            dly_dwell_cnt <= dly_dwell_cnt + 1;
        else
            dly_dwell_cnt <= 16'b0;
    end
    
    // RXOUTCLK select and reset on change
    always @(posedge clk_freerun) begin
        if (state == reset_s) begin
            userclk_rx_reset <= 1'b0;
            rxoutclksel <= 3'b001;
            rxrate <= 3'b011;
        end
        else if (state == pll_reset_s) begin
            userclk_rx_reset <= userclk_rx_active_sync_q;
            if (rxoutclkpcs_dly_valid) begin
                rxoutclksel <= 3'b101;
                rxrate <= 3'b000;
            end
        end
    end
    
    // RXPROGDIVCLK delay shift measurement
    always @(posedge clk_freerun) begin
        inv_rxusrclk2 <= align_shift_cnt >= RATIO_BIT_RATE_RXUSRCLK;
        if (state == reset_s) begin
            align_shift_cnt_valid <= 1'b0;
            align_shift_cnt <= 7'b0;
        end
        else if (state == rxphalign_dly_check_s & rxoutclkpcs_dly_valid & dly_match) begin
            align_shift_cnt_valid <= 1'b1;
            align_shift_cnt <= ((RATIO_BIT_RATE_RXUSRCLK * 4) - (rxslide_shift_cnt + RATIO_BIT_RATE_RXUSRCLK * rxoutclkpcs_dly_180 + RATIO_BIT_RATE_RXUSRCLK / 2 * rxoutclkpcs_dly_90)) % (RATIO_BIT_RATE_RXUSRCLK * 2);
        end
    end
    
    // Send toggle pulse to RXUSRCLK2 domain to signal one rxslide shift
    always @(posedge clk_freerun) begin
        if (state == reset_s | state == rxprogdivclk_reset_s | state == mgt_config_rxslide_pcs_s) begin
            rxslide_shift_cnt <= 7'b0;
            rxslide_toggle_clk_freerun <= 1'b0;
        end
        else if ((state == rxoutclkpcs_shift_s | state == rxdata_shift_s) & ~(rxslide_toggle_rxusrclk2_sync_q ^ rxslide_toggle_clk_freerun)) begin
            rxslide_toggle_clk_freerun <= ~rxslide_toggle_clk_freerun;
            rxslide_shift_cnt <= rxslide_shift_cnt + 1;
        end
    end
    
    // Issue one rxslide pulse sequence when signal is toggled
    always @(posedge rxusrclk2) begin
        if (rst_rxusrclk2) begin
            rxslide <= 1'b0;
            rxslide_wait_cnt <= 6'b0;
            rxslide_toggle_rxusrclk2 <= 1'b0;
        end
        else if (rxslide_toggle_clk_freerun_sync ^ rxslide_toggle_rxusrclk2) begin
            rxslide <= (rxslide_wait_cnt < 2);
            rxslide_wait_cnt <= rxslide_wait_cnt + 1;
            // High for 2 cycles, Low for 32 cycles
            if (rxslide_wait_cnt == 33)
                rxslide_toggle_rxusrclk2 <= rxslide_toggle_clk_freerun_sync;
        end
        else begin
            rxslide <= 1'b0;
            rxslide_wait_cnt <= 6'b0;
        end
    end

    // Delay average accumulator
    always @(posedge clk_freerun) begin
        if (state == rxphalign_dly_avg_s) begin
            dly_avg_cnt <= dly_avg_cnt + 1;
            dly_avg_acc <= dly_avg_acc + dmonitorout[7:0];
        end
        else begin
            dly_avg_cnt <= 8'b0;
            dly_avg_acc <= 1 << 7; // Initialize accumulator with 0.5 to round final result instead of truncate
        end
    end

    // Reset RXPROGDIV and wait
    always @(posedge clk_freerun) begin
        if (state == rxprogdivclk_reset_s) begin
            rxprgdivreset_wait_cnt <= rxprgdivreset_wait_cnt + 1;
            rxprogdivreset <= ~|rxprgdivreset_wait_cnt;
        end
        else begin
            rxprgdivreset_wait_cnt <= 16'b0;
            rxprogdivreset <= 1'b0;
        end
    end
    
    // MGT DRP interface
    always @(posedge clk_freerun) begin
        case (state)
            mgt_config_dmonitor_read_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b0;
                mgt_drpaddr <= MGT_DRP_ADDR_DMONITOR_CFG1;
                mgt_drpdi <= 16'bX;
                if (mgt_drpen & mgt_drprdy)
                    dmonitor_cfg1_reg <= mgt_drpdo;
            end
            mgt_config_dmonitor_phalign_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b1;
                mgt_drpaddr <= MGT_DRP_ADDR_DMONITOR_CFG1;
                mgt_drpdi <= (dmonitor_cfg1_reg & MASK_DMONITOR_CFG1) | (8'h03 << 8);
            end
            mgt_config_rxslide_read_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b0;
                mgt_drpaddr <= MGT_DRP_ADDR_RXSLIDE_MODE;
                mgt_drpdi <= 16'bX;
                if (mgt_drpen & mgt_drprdy)
                    rxslide_mode_reg <= mgt_drpdo;
            end
            mgt_config_rxslide_pma_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b1;
                mgt_drpaddr <= MGT_DRP_ADDR_RXSLIDE_MODE;
                mgt_drpdi <= (rxslide_mode_reg & MASK_RXSLIDE_MODE) | (2'd3 << 9);
            end
            mgt_config_rxslide_pcs_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b1;
                mgt_drpaddr <= MGT_DRP_ADDR_RXSLIDE_MODE;
                mgt_drpdi <= (rxslide_mode_reg & MASK_RXSLIDE_MODE) | (2'd2 << 9);
            end
            mgt_config_dmonitor_cdr_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b1;
                mgt_drpaddr <= MGT_DRP_ADDR_DMONITOR_CFG1;
                mgt_drpdi <= (dmonitor_cfg1_reg & MASK_DMONITOR_CFG1) | (8'h01 << 8);
            end
            bitslip_cdr_s: begin
                mgt_drpen <= ~(mgt_drpen & mgt_drprdy);
                mgt_drpwe <= 1'b1;
                mgt_drpaddr <= MGT_DRP_ADDR_RXCDR_CFG1;
                mgt_drpdi <= rxcdr_pi_val << 9;
            end
            default: begin
                mgt_drpen <= 1'b0;
                mgt_drpwe <= 1'bX;
                mgt_drpaddr <= 10'bX;
                mgt_drpdi <= 16'bX;
            end
        endcase
    end
    
    // PLL DRP interface
    always @(posedge clk_freerun) begin
        case (state)
            pll_config_ckout0_freq: begin
                pll_drpen <= ~(pll_drpen & pll_drprdy);
                pll_drpwe <= 1'b1;
                pll_drpaddr <= PLL_DRP_ADDR_CKOUT0_FREQ;
                pll_drpdi <= rxoutclkpcs_dly_valid ? 16'h1082 : 16'h1104;
            end
            pll_config_ckout0_dly: begin
                pll_drpen <= ~(pll_drpen & pll_drprdy);
                pll_drpwe <= 1'b1;
                pll_drpaddr <= PLL_DRP_ADDR_CKOUT0_DLY;
                pll_drpdi <= rxoutclkpcs_dly_valid | ~rxoutclkpcs_dly_90 ? 16'h0000 : 16'h0002;
            end
            default: begin
                pll_drpen <= 1'b0;
                pll_drpwe <= 1'bX;
                pll_drpaddr <= 10'bX;
                pll_drpdi <= 16'bX;
            end
        endcase
    end
    
    // Walk RX CDR PI value
    always @(posedge clk_freerun) begin
        rxcdrovrden = state == bitslip_cdr_s & mgt_drpen & mgt_drprdy;
        if ((state == idle_s & (bitslip_toggle_sync ^ bitslip_toggle_sync_q)) | rxcdrovrden) begin
            rxcdr_pi_val <= rxcdr_pi_val + CDR_STEP_SIZE;
            rxcdr_step_cnt <= rxcdr_step_cnt + 1;
        end
        else if (state == idle_s) begin
            rxcdr_pi_val <= dmonitorout[6:0];
            rxcdr_step_cnt <= 8'b0;
        end
    end
    
    // Free running clock registers
    always @(posedge clk_freerun) begin
        bitslip_toggle_sync_q <= bitslip_toggle_sync;
        rxprgdivresetdone_sync_q <= rxprgdivresetdone_sync;
        rxsyncdone_sync_q <= rxsyncdone_sync;
        userclk_rx_active_sync_q <= userclk_rx_active_sync;
        rxslide_toggle_rxusrclk2_sync_q <= rxslide_toggle_rxusrclk2_sync;
        bitslip_rdy_clk_freerun <= (state == idle_s);
    end
    
    // RXUSRCLK2 registers
    always @(posedge rxusrclk2) begin
        bitslip_q <= bitslip;
        bitslip_toggle <= bitslip_toggle ^ (bitslip & ~bitslip_q);
    end

    // Bit synchronizers
    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer0_inst (
        .clk_in (clk_freerun),
        .i_in   (rxprgdivresetdone),
        .o_out  (rxprgdivresetdone_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer1_inst (
        .clk_in (clk_freerun),
        .i_in   (rxsyncdone),
        .o_out  (rxsyncdone_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer2_inst (
        .clk_in (clk_freerun),
        .i_in   (rxphaligndone),
        .o_out  (rxphaligndone_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer3_inst (
        .clk_in (clk_freerun),
        .i_in   (bitslip_toggle),
        .o_out  (bitslip_toggle_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer4_inst (
        .clk_in (clk_freerun),
        .i_in   (userclk_rx_active),
        .o_out  (userclk_rx_active_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer5_inst (
        .clk_in (clk_freerun),
        .i_in   (rxslide_toggle_rxusrclk2),
        .o_out  (rxslide_toggle_rxusrclk2_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer6_inst (
        .clk_in (rxusrclk2),
        .i_in   (rxslide_toggle_clk_freerun),
        .o_out  (rxslide_toggle_clk_freerun_sync)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer7_inst (
        .clk_in (rxusrclk2),
        .i_in   (bitslip_rdy_clk_freerun),
        .o_out  (bitslip_rdy)
    );

    (* DONT_TOUCH = "TRUE" *)
    bit_synchronizer bit_synchronizer8_inst (
        .clk_in (clk_freerun),
        .i_in   (rst_rxusrclk2),
        .o_out  (rst_clk_freerun)
    );

endmodule
