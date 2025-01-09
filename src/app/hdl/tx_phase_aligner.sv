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
//  Wraps the PICXO IP for aligning TX data with a user clock
//  Loop parameters tuned using xilinx excel spreadsheet accompanying this file
// ------------------------------------------------------------------------------------------------

module tx_phase_aligner (
    input  logic        rst,
    input  logic        refclk,
    input  logic        fbclk,
    output logic [4:0]  txpippmstepsize,
    output logic        txpippmen,
    output logic        txpippmsel
    
);

    localparam CE_DSP_RATE  = 16'h0417;
    localparam V            = 16'h00C6;
    localparam R            = 16'h00C6;
    localparam ACC_STEP     = 4'h1;
    localparam G1           = 5'h0A;
    localparam G2           = 5'h12;
    
    assign txpippmen    = 1'b1;
    assign txpippmsel   = 1'b1;
    
    picxo_fracxo_0 picxo_fracxo_0_inst (
        .RESET_I(rst),          // input wire RESET_I
        .REF_CLK_I(refclk),      // input wire REF_CLK_I
        .TXOUTCLK_I(fbclk),    // input wire TXOUTCLK_I
        .RSIGCE_I(1'b1),        // input wire RSIGCE_I
        .VSIGCE_I(1'b1),        // input wire VSIGCE_I
        .VSIGCE_O(),        // output wire VSIGCE_O
        .ACC_STEP(ACC_STEP),        // input wire [3 : 0] ACC_STEP
        .G1(G1),                    // input wire [4 : 0] G1
        .G2(G2),                    // input wire [4 : 0] G2
        .R(R),                      // input wire [15 : 0] R
        .V(V),                      // input wire [15 : 0] V
        .CE_DSP_RATE(CE_DSP_RATE),  // input wire [15 : 0] CE_DSP_RATE
        .C_I(7'b0),                  // input wire [6 : 0] C_I
        .P_I(10'b0),                  // input wire [9 : 0] P_I
        .N_I(10'b0),                  // input wire [9 : 0] N_I
        .OFFSET_PPM(22'h0),    // input wire [21 : 0] OFFSET_PPM
        .OFFSET_EN(1'b0),      // input wire OFFSET_EN
        .DON_I(1'b1),              // input wire [0 : 0] DON_I
        .ACC_DATA(txpippmstepsize),        // output wire [4 : 0] ACC_DATA
        .ERROR_O(),          // output wire [20 : 0] ERROR_O
        .VOLT_O(),            // output wire [21 : 0] VOLT_O
        .CE_PI_O(),          // output wire CE_PI_O
        .CE_PI2_O(),        // output wire CE_PI2_O
        .CE_DSP_O(),        // output wire CE_DSP_O
        .OVF_PD(),            // output wire OVF_PD
        .OVF_AB(),            // output wire OVF_AB
        .OVF_VOLT(),        // output wire OVF_VOLT
        .OVF_INT()          // output wire OVF_INT
    );

endmodule
