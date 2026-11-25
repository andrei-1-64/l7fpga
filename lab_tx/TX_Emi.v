module TX_Emi (
    input  wire clk,       // PIN_23: Clock 50 MHz
    input  wire S1,        // PIN_88: Buton emisie (active LOW)
    output wire tx_out,    // PIN_105 -> Rezistor 1 kOhm -> Baza BC547
    output wire tx_power,  // PIN_106 -> 3.3V ("PIN PE PLACA") -> Anod (+) LED emitator
    output wire led1,      // PIN_87: Indicator local pe placa TX cand apesi S1
    output wire led2,      // PIN_86 (stins)
    output wire led3,      // PIN_85 (stins)
    output wire buzzer     // PIN_110: Silentios
);

    assign tx_power = 1'b1;

    reg [1:0] s1_sync = 2'b11;
    always @(posedge clk)
        s1_sync <= {s1_sync[0], S1};

    // Cand S1 e apasat (0) -> tx_out HIGH (3.3V) -> LED TX aprins
    assign tx_out = ~s1_sync[1];

    assign led1   = s1_sync[1];
    assign led2   = 1'b1;
    assign led3   = 1'b1;
    assign buzzer = 1'b1;

endmodule
