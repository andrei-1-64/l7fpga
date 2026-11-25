module Optical_RX (
    input  wire clk,         // PIN_23: 50 MHz clock
    input  wire S1,          // PIN_88: button (active LOW) - changes picture only when signal is present
    input  wire sensor,      // PIN_103: LDR + 4.7k junction
    output wire ldr_power,   // PIN_98: 3.3V supply for LDR (or use 3V3 pin)
    output wire led1,        // PIN_87 (LED4 fizic): lumina detectata
    output wire led2,        // PIN_86 (LED3 fizic): stins
    output wire led3,        // PIN_85 (LED2 fizic): intuneric detectat
    output wire buzzer,      // PIN_110: silent
    output reg  lcd_rst = 0, // PIN_144
    output reg  lcd_ce  = 1, // PIN_142
    output reg  lcd_dc  = 0, // PIN_138
    output reg  lcd_din = 0, // PIN_136
    output reg  lcd_clk = 0  // PIN_133
);

    // 1) Receptie semnal optic pe LDR (adaptata din GitHub LAB/LDR/Senzor_Lumina.v)
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

    assign led1   = ~rx_clean; // aprins cand exista semnal luminos
    assign led2   = 1'b1;      // stins
    assign led3   = rx_clean;  // aprins cand nu exista semnal
    assign buzzer = 1'b1;      // silentios

    // 2) Sincronizare + debounce ~10 ms pentru butonul S1 (active LOW)
    reg [1:0] s1_sync = 2'b11;
    reg [18:0] s1_cnt = 0;
    reg s1_clean = 1'b1;
    reg prev_s1 = 1'b1;

    always @(posedge clk) begin
        s1_sync <= {s1_sync[0], S1};
        if (s1_sync[1] == s1_clean)
            s1_cnt <= 0;
        else if (s1_cnt == 19'd499999) begin
            s1_cnt <= 0;
            s1_clean <= s1_sync[1];
        end else
            s1_cnt <= s1_cnt + 1'b1;

        prev_s1 <= s1_clean;
    end

    wire s1_press = prev_s1 && !s1_clean;

    // 3) Selectarea pozei:
    //    - Fara semnal (rx_clean == 0): ramane mereu pe 0 (sad, default), indiferent de buton
    //    - Cu semnal (rx_clean == 1): la apasarea S1 schimba intre sad (0) si happy (1)
    reg target_img = 1'b0;

    always @(posedge clk) begin
        if (!rx_clean)
            target_img <= 1'b0;
        else if (s1_press)
            target_img <= ~target_img;
    end

    // 4) Controller LCD Nokia 5110 (adaptat din map change)
    // img1 = sad_84x48.hex (default / fara semnal)
    // img2 = happy_84x48.hex (cu semnal + buton apasat)
    reg [7:0] img1 [0:503], img2 [0:503];

    initial begin
        $readmemh("sad_84x48.hex", img1);
        $readmemh("happy_84x48.hex", img2);
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

        // Redesenare cand se schimba target_img
        else if (done) begin
            if (target_img != selected) begin
                selected <= target_img;
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
