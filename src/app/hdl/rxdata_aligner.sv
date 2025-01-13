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
//  This block aligns an incoming datastream using comma characters
//  If no comma characters are detected after the timer elapses then the bitslip
//  signal is asserted to shift the datastream by one bit until alignment is achieved.
// ------------------------------------------------------------------------------------------------

module rxdata_aligner (
    input  logic        rxusrclk2,
    input  logic        rst,
    input  logic [15:0] rxctrl1,
    input  logic [7:0]  rxctrl2,
    input  logic [7:0]  rxctrl3,
    input  logic        bitslip_rdy,
    output logic        bitslip,
    output logic        aligned,
    output logic        rxcommadeten,
    output logic        rxmcommaalignen,
    output logic        rxpcommaalignen,
    output logic        rx8b10ben
);

    logic [15:0] timeout_cnt;
    logic [3:0] comma_cnt;
    
    assign rxcommadeten     = 1'b1;
    assign rxmcommaalignen  = 1'b0;
    assign rxpcommaalignen  = 1'b0;
    assign rx8b10ben        = 1'b1;
    
    // Data is aligned when several valid commas are detected with no errors in between
    assign aligned = &comma_cnt;
    
    // Timeout counter and valid comma counter
    always @(posedge rxusrclk2) begin
        if (rst) begin
            comma_cnt <= 4'b0;
            timeout_cnt <= 16'b0;
        end
        else if (|rxctrl1 | |rxctrl3 | &timeout_cnt) begin
            comma_cnt <= 4'b0;
            timeout_cnt <= timeout_cnt + 1;
        end
        else if (rxctrl2 == 8'b1 & bitslip_rdy) begin
            comma_cnt <= comma_cnt + ~&comma_cnt;
            timeout_cnt <= 16'b0;
        end
        else begin
            timeout_cnt <= timeout_cnt + 1;
        end
    end
    
    // Slip one bit position when timeout is reached
    always @(posedge rxusrclk2) begin
        if (rst) begin
            bitslip <= 1'b0;
        end
        else begin
            bitslip <= &timeout_cnt;
        end
    end

endmodule
