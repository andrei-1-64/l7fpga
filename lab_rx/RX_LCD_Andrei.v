module RX_LCD_Andrei (
    input  wire clk,         // PIN_23: Clock 50 MHz
    input  wire sensor,      // PIN_103: Nodul dintre LDR si rezistorul 4.7 kOhm
    output wire ldr_power,   // PIN_98: Alimentare LDR 3.3V
    output wire led1,        // PIN_87: Aprins la semnal
    output wire led2,        // PIN_86: Stins
    output wire led3,        // PIN_85: Aprins fara semnal
    output wire buzzer,      // PIN_110: Silentios
    output reg  lcd_rst = 0, // PIN_144
    output reg  lcd_ce  = 1, // PIN_142
    output reg  lcd_dc  = 0, // PIN_138
    output reg  lcd_din = 0, // PIN_136
    output reg  lcd_clk = 0  // PIN_133
);

    assign ldr_power = 1'b1;

    // Sincronizator 2 etaje + filtru ~10 ms pe senzorul LDR
    reg [1:0] light = 2'b00;
    reg [18:0] rx_cnt = 0;
    reg rx_clean = 0;

    always @(posedge clk) begin
        light <= {light[0], sensor};
        if (light[1] == rx_clean)
            rx_cnt <= 0;
        else if (rx_cnt == 19'd499999) begin
            rx_cnt <= 0;
            rx_clean <= light[1];
        end else
            rx_cnt <= rx_cnt + 1'b1;
    end

    assign led1   = ~rx_clean;
    assign led2   = 1'b1;
    assign led3   = rx_clean;
    assign buzzer = 1'b1;

    // img1 = ANDREI_84x48.hex (fara semnal), img2 = ANDREI2_84x48.hex (cu semnal)
    reg [7:0] img1 [0:503], img2 [0:503];

    initial begin
        $readmemh("ANDREI_84x48.hex", img1);
        $readmemh("ANDREI2_84x48.hex", img2);
    end

    function [7:0] cmd;
        input [2:0] n;
        begin
            case (n)
                0: cmd=8'h21; 1: cmd=8'hB8;
                2: cmd=8'h04; 3: cmd=8'h14;
                4: cmd=8'h20; 5: cmd=8'h0C;
                6: cmd=8'h80; 7: cmd=8'h40;
            endcase
        end
    endfunction

    reg selected = 0, done = 0;
    reg [21:0] startup = 0;
    reg [6:0] div = 0;
    reg [9:0] index = 0;
    reg [7:0] shift = 0;
    reg [2:0] bit_no = 7;
    reg [1:0] state = 0;

    wire [9:0] pixel_index = index - 10'd8;

    wire [7:0] data_byte = (index < 8) ?
        cmd(index[2:0]) :
        selected ? img2[pixel_index] : img1[pixel_index];

    always @(posedge clk) begin
        if (startup < 22'd2500000) begin
            startup <= startup + 1'b1;
            if (startup == 22'd1000000)
                lcd_rst <= 1'b1;
        end
        else if (done) begin
            if (rx_clean != selected) begin
                selected <= rx_clean;
                index <= 6;
                done <= 0;
            end
        end
        else if (div == 7'd99) begin
            div <= 0;
            case (state)
                0: begin
                    lcd_ce <= 0;
                    lcd_dc <= (index >= 8);
                    lcd_din <= data_byte[7];
                    shift <= data_byte;
                    bit_no <= 7;
                    state <= 1;
                end
                1: begin
                    lcd_clk <= 1;
                    state <= 2;
                end
                2: begin
                    lcd_clk <= 0;
                    if (bit_no == 0)
                        state <= 3;
                    else begin
                        bit_no <= bit_no - 1'b1;
                        lcd_din <= shift[6];
                        shift <= {shift[6:0], 1'b0};
                        state <= 1;
                    end
                end
                3: begin
                    lcd_ce <= 1;
                    if (index == 511)
                        done <= 1;
                    else
                        index <= index + 1'b1;
                    state <= 0;
                end
            endcase
        end
        else
            div <= div + 1'b1;
    end

endmodule
