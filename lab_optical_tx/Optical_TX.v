module Optical_TX (
    input  wire clk,
    output wire tx_out,    // PIN_105 -> 1k resistor -> Base of BC547 (always ON)
    output wire tx_power,  // PIN_106 -> 3.3V ("PIN PE PLACA" for LED anode)
    output wire led1,      // PIN_87 (active LOW) - ON while transmitting
    output wire led2,      // PIN_86 (OFF)
    output wire led3,      // PIN_85 (OFF)
    output wire buzzer     // PIN_110 (silent)
);

    // 3.3V pin on board for TX LED anode
    assign tx_power = 1'b1;

    // Continuously drive BC547 ON (TX LED always ON, no button needed on TX)
    assign tx_out = 1'b1;

    // On-board LED1 stays ON as TX indicator
    assign led1 = 1'b0;
    assign led2 = 1'b1;
    assign led3 = 1'b1;

    assign buzzer = 1'b1;

endmodule
