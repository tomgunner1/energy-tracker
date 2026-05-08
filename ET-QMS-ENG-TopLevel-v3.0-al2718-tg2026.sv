// ET-DES-TopLevel-v1.0-al2718-tg2026.sv

module energy_tracker (
    input  logic        CLOCK_50,
    input  logic [9:0]  SW,
    input  logic [3:0]  KEY,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5
);

    localparam CLK_FREQ = 50_000_000;

    logic        rst_n;
    logic        tick_1hz;
    logic [31:0] clk_counter;
    logic [31:0] display_val;
    logic [31:0] remainder;
    logic [31:0] new_remainder;
    logic [31:0] increments;
    logic [3:0]  digit [5:0];

    assign rst_n = KEY[0];

    // 1Hz clock tick generator
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 32'd0;
            tick_1hz    <= 1'b0;
        end else begin
            if (clk_counter == CLK_FREQ - 1) begin
                clk_counter <= 32'd0;
                tick_1hz    <= 1'b1;
            end else begin
                clk_counter <= clk_counter + 1;
                tick_1hz    <= 1'b0;
            end
        end
    end

    // Watt-seconds to 0.1Wh increment conversion
    logic [31:0] total;
    assign total = remainder + {22'd0, SW};

    always_comb begin
        increments    = 32'd0;
        new_remainder = total;
        if (new_remainder >= 32'd360) begin new_remainder = new_remainder - 32'd360; increments = increments + 32'd1; end
        if (new_remainder >= 32'd360) begin new_remainder = new_remainder - 32'd360; increments = increments + 32'd1; end
        if (new_remainder >= 32'd360) begin new_remainder = new_remainder - 32'd360; increments = increments + 32'd1; end
        if (new_remainder >= 32'd360) begin new_remainder = new_remainder - 32'd360; increments = increments + 32'd1; end
    end

    // Energy accumulator: updates display value and remainder each 1Hz tick
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            display_val <= 32'd0;
            remainder   <= 32'd0;
        end else if (tick_1hz) begin
            if (SW == 10'd0) begin
                remainder   <= remainder;
                display_val <= display_val;
            end else begin
                remainder   <= new_remainder;
                display_val <= display_val + increments;
            end
        end
    end

    // LED bar graph: 1 LED per 1Wh (10 display units), all on at 10Wh
    always_comb begin
        if      (display_val >= 32'd90) LEDR = 10'b1111111111;
        else if (display_val >= 32'd80) LEDR = 10'b0111111111;
        else if (display_val >= 32'd70) LEDR = 10'b0011111111;
        else if (display_val >= 32'd60) LEDR = 10'b0001111111;
        else if (display_val >= 32'd50) LEDR = 10'b0000111111;
        else if (display_val >= 32'd40) LEDR = 10'b0000011111;
        else if (display_val >= 32'd30) LEDR = 10'b0000001111;
        else if (display_val >= 32'd20) LEDR = 10'b0000000111;
        else if (display_val >= 32'd10) LEDR = 10'b0000000011;
        else if (display_val >= 32'd1)  LEDR = 10'b0000000001;
        else                            LEDR = 10'b0000000000;
    end

    // BCD conversion via double dabble (6 digits, 32-bit input)
    logic [55:0] bcd_shift;

    always_comb begin
        bcd_shift = {24'd0, display_val};
        for (int i = 0; i < 32; i++) begin
            if (bcd_shift[55:52] >= 4'd5) bcd_shift[55:52] = bcd_shift[55:52] + 4'd3;
            if (bcd_shift[51:48] >= 4'd5) bcd_shift[51:48] = bcd_shift[51:48] + 4'd3;
            if (bcd_shift[47:44] >= 4'd5) bcd_shift[47:44] = bcd_shift[47:44] + 4'd3;
            if (bcd_shift[43:40] >= 4'd5) bcd_shift[43:40] = bcd_shift[43:40] + 4'd3;
            if (bcd_shift[39:36] >= 4'd5) bcd_shift[39:36] = bcd_shift[39:36] + 4'd3;
            if (bcd_shift[35:32] >= 4'd5) bcd_shift[35:32] = bcd_shift[35:32] + 4'd3;
            bcd_shift = bcd_shift << 1;
        end
        digit[5] = bcd_shift[55:52];
        digit[4] = bcd_shift[51:48];
        digit[3] = bcd_shift[47:44];
        digit[2] = bcd_shift[43:40];
        digit[1] = bcd_shift[39:36];
        digit[0] = bcd_shift[35:32];
    end

    // 7-segment decoder (active low output)
    function automatic logic [6:0] seg7(input logic [3:0] d);
        case (d)
            4'd0: seg7 = 7'b1000000;
            4'd1: seg7 = 7'b1111001;
            4'd2: seg7 = 7'b0100100;
            4'd3: seg7 = 7'b0110000;
            4'd4: seg7 = 7'b0011001;
            4'd5: seg7 = 7'b0010010;
            4'd6: seg7 = 7'b0000010;
            4'd7: seg7 = 7'b1111000;
            4'd8: seg7 = 7'b0000000;
            4'd9: seg7 = 7'b0010000;
            default: seg7 = 7'b1111111;
        endcase
    endfunction

    assign HEX0 = seg7(digit[0]);
    assign HEX1 = seg7(digit[1]);
    assign HEX2 = seg7(digit[2]);
    assign HEX3 = seg7(digit[3]);
    assign HEX4 = seg7(digit[4]);
    assign HEX5 = seg7(digit[5]);

endmodule
