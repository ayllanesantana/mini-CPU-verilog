// Módulo: module_lcd
// Função: Interface com o LCD HD44780 da DE2-115.
//   - Captura (trava) operação, registrador e resultado no instante do "show", então
//     o que aparece no display não muda se os switches ou a memória mudarem depois.
//   - mode: 0 = normal (nome, [reg], resultado)   1 = só o nome (CLEAR)
//           2 = modelo inicial (display ligado, sem instrução)   3 = apagar display
//   - ready = 1 quando o módulo está parado e pode receber um novo "show".

module module_lcd (
    input  wire        clk,
    input  wire        rst,
    input  wire        show,
    input  wire [1:0]  mode,

    input  wire [7:0]  opname_0, input wire [7:0] opname_1,
    input  wire [7:0]  opname_2, input wire [7:0] opname_3,

    input  wire [3:0]  dest_reg,
    input  wire signed [15:0] result,

    output wire        ready,
    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    localparam [1:0] M_NORMAL = 2'd0, M_NAME = 2'd1, M_TEMPLATE = 2'd2, M_OFF = 2'd3;

    wire [7:0] init_data; wire init_rs, init_rw, init_e;
    wire       init_done;
    reg        start_init;

    lcd_init_hd44780 lcd_init (
        .clk (clk), .rst (rst), .start (start_init), .done (init_done),
        .lcd_data (init_data), .lcd_rs (init_rs), .lcd_rw (init_rw), .lcd_e (init_e)
    );

    reg [7:0] wr_data; reg wr_rs; wire wr_rw; wire wr_e;

    assign lcd_data = (!init_done) ? init_data : wr_data;
    assign lcd_rs   = (!init_done) ? init_rs   : wr_rs;
    assign lcd_rw   = (!init_done) ? init_rw   : wr_rw;
    assign lcd_e    = (!init_done) ? init_e    : wr_e;

    // Delays para clock de 50 MHz
    localparam [31:0] DELAY_WRITE = 32'd100_000; // ~2 ms (folga; datasheet pede > 37 us)
    localparam [31:0] DELAY_PULSE = 32'd50;      // ~1 us
    localparam [31:0] DELAY_CLEAR = 32'd100_000; // ~2 ms

    // ---------------- valores travados no momento do show ----------------
    reg [7:0] r_op0, r_op1, r_op2, r_op3;
    reg [3:0] r_dest;
    reg signed [15:0] r_res;
    reg [1:0] r_mode;

    // ---------------- Double Dabble (17 bits, sem laços) ----------------
    wire              is_neg = r_res[15];
    wire signed [16:0] rext  = r_res;                       // estende o sinal
    wire        [16:0] mag   = is_neg ? (-rext) : rext;     // |r_res| (32768 cabe)

    // A checagem ">= 5 soma 3" vem antes de TODO deslocamento, inclusive o último.
    function [19:0] to_bcd;
        input [16:0] m;
        reg   [19:0] b;
        begin
            b = 20'd0;
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[16]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[15]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[14]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[13]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[12]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[11]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[10]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[9]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[8]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[7]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[6]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[5]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[4]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[3]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[2]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[1]};
            if (b[19:16] >= 5) b[19:16] = b[19:16] + 3;
            if (b[15:12] >= 5) b[15:12] = b[15:12] + 3;
            if (b[11:8] >= 5) b[11:8] = b[11:8] + 3;
            if (b[7:4] >= 5) b[7:4] = b[7:4] + 3;
            if (b[3:0] >= 5) b[3:0] = b[3:0] + 3;
            b = {b[18:0], m[0]};
            to_bcd = b;
        end
    endfunction

    wire [19:0] bcd = to_bcd(mag);

    wire [7:0] dig4 = 8'd48 + {4'b0, bcd[19:16]};
    wire [7:0] dig3 = 8'd48 + {4'b0, bcd[15:12]};
    wire [7:0] dig2 = 8'd48 + {4'b0, bcd[11:8]};
    wire [7:0] dig1 = 8'd48 + {4'b0, bcd[7:4]};
    wire [7:0] dig0 = 8'd48 + {4'b0, bcd[3:0]};
    wire [7:0] sign_char = is_neg ? 8'd45 : 8'd43;   // '-' / '+'

    wire [7:0] dreg3 = 8'd48 + {7'b0, r_dest[3]};
    wire [7:0] dreg2 = 8'd48 + {7'b0, r_dest[2]};
    wire [7:0] dreg1 = 8'd48 + {7'b0, r_dest[1]};
    wire [7:0] dreg0 = 8'd48 + {7'b0, r_dest[0]};

    // ---------------- linhas do display (16 caracteres, 1º caractere = MSB) ----------------
    reg [127:0] l1, l2;
    always @(*) begin
        case (r_mode)
            M_NORMAL: begin
                l1 = {r_op0, r_op1, r_op2, r_op3, 8'h20, 8'h20, 8'h20, "[", dreg3, dreg2, dreg1, dreg0, "]", 8'h20, 8'h20, 8'h20};
                l2 = {{8{8'h20}}, sign_char, dig4, dig3, dig2, dig1, dig0, 8'h20, 8'h20};
            end
            M_NAME: begin
                l1 = {r_op0, r_op1, r_op2, r_op3, {12{8'h20}}};
                l2 = {16{8'h20}};
            end
            default: begin   // modelo inicial
                l1 = {"-", "-", "-", "-", 8'h20, 8'h20, 8'h20, "[", "-", "-", "-", "-", "]", 8'h20, 8'h20, 8'h20};
                l2 = {{8{8'h20}}, "+", "0", "0", "0", "0", "0", 8'h20, 8'h20};
            end
        endcase
    end

    // ---------------- FSM de escrita ----------------
    localparam [3:0]
        S_WAIT_INIT = 4'd0,
        S_IDLE      = 4'd1,
        S_CLEAR     = 4'd2,
        S_SET_L1    = 4'd3,
        S_WRITE_L1  = 4'd4,
        S_SET_L2    = 4'd5,
        S_WRITE_L2  = 4'd6,
        S_PULSE_E   = 4'd7,
        S_WAIT      = 4'd8,
        S_DONE      = 4'd9;

    reg [3:0]  state,        next_state;
    reg [3:0]  return_state, next_return_state;
    reg [31:0] delay_cnt,    next_delay_cnt;
    reg [4:0]  char_idx,     next_char_idx;

    assign ready = init_done && (state == S_IDLE);

    // dado/RS da operação corrente e versão travada (estável durante PULSE_E e WAIT)
    reg [7:0] op_data; reg op_rs;
    reg [7:0] cur_data; reg cur_rs;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_WAIT_INIT;
            return_state <= S_IDLE;
            delay_cnt    <= 32'd0;
            char_idx     <= 5'd0;
            start_init   <= 1'b1;
            cur_data     <= 8'h00;
            cur_rs       <= 1'b0;
            r_op0 <= 8'h20; r_op1 <= 8'h20; r_op2 <= 8'h20; r_op3 <= 8'h20;
            r_dest <= 4'd0; r_res <= 16'sd0; r_mode <= M_TEMPLATE;
        end else begin
            state        <= next_state;
            return_state <= next_return_state;
            delay_cnt    <= next_delay_cnt;
            char_idx     <= next_char_idx;

            if (state == S_WAIT_INIT && !init_done)
                start_init <= 1'b0;

            // trava os dados da instrução no instante do show
            if (state == S_IDLE && show) begin
                r_op0 <= opname_0; r_op1 <= opname_1; r_op2 <= opname_2; r_op3 <= opname_3;
                r_dest <= dest_reg; r_res <= result; r_mode <= mode;
            end

            if (state != S_PULSE_E && state != S_WAIT) begin
                cur_data <= op_data;
                cur_rs   <= op_rs;
            end
        end
    end

    always @(*) begin
        next_state        = state;
        next_return_state = return_state;
        next_delay_cnt    = delay_cnt;
        next_char_idx     = char_idx;

        case (state)
            S_WAIT_INIT: if (init_done) next_state = S_IDLE;

            S_IDLE: if (show) next_state = S_CLEAR;

            S_CLEAR: begin
                next_return_state = (r_mode == M_OFF) ? S_DONE : S_SET_L1;
                next_delay_cnt    = DELAY_PULSE;
                next_state        = S_PULSE_E;
            end

            S_SET_L1: begin
                next_char_idx     = 5'd0;
                next_return_state = S_WRITE_L1;
                next_delay_cnt    = DELAY_PULSE;
                next_state        = S_PULSE_E;
            end

            S_WRITE_L1: begin
                if (char_idx < 5'd16) begin
                    next_char_idx     = char_idx + 5'd1;
                    next_return_state = S_WRITE_L1;
                    next_delay_cnt    = DELAY_PULSE;
                    next_state        = S_PULSE_E;
                end else
                    next_state = S_SET_L2;
            end

            S_SET_L2: begin
                next_char_idx     = 5'd0;
                next_return_state = S_WRITE_L2;
                next_delay_cnt    = DELAY_PULSE;
                next_state        = S_PULSE_E;
            end

            S_WRITE_L2: begin
                if (char_idx < 5'd16) begin
                    next_char_idx     = char_idx + 5'd1;
                    next_return_state = S_WRITE_L2;
                    next_delay_cnt    = DELAY_PULSE;
                    next_state        = S_PULSE_E;
                end else
                    next_state = S_DONE;
            end

            S_PULSE_E: begin
                if (delay_cnt > 0)
                    next_delay_cnt = delay_cnt - 1;
                else begin
                    // Clear Display precisa de ~2 ms; os demais ~50 us
                    next_delay_cnt = (!cur_rs && cur_data == 8'h01) ? DELAY_CLEAR : DELAY_WRITE;
                    next_state     = S_WAIT;
                end
            end

            S_WAIT: begin
                if (delay_cnt > 0) next_delay_cnt = delay_cnt - 1;
                else               next_state     = return_state;
            end

            S_DONE: next_state = S_IDLE;
            default: next_state = S_WAIT_INIT;
        endcase
    end

    assign wr_rw = 1'b0;                 // somente escrita
    assign wr_e  = (state == S_PULSE_E); // pulso de Enable

    // caractere atual de cada linha
    wire [7:0] ch1 = l1[(4'd15 - char_idx[3:0]) * 8 +: 8];
    wire [7:0] ch2 = l2[(4'd15 - char_idx[3:0]) * 8 +: 8];

    always @(*) begin
        op_data = 8'h00; op_rs = 1'b0;
        case (state)
            S_CLEAR:    begin op_data = 8'h01; op_rs = 1'b0; end
            S_SET_L1:   begin op_data = 8'h80; op_rs = 1'b0; end
            S_SET_L2:   begin op_data = 8'hC0; op_rs = 1'b0; end
            S_WRITE_L1: begin op_data = ch1;   op_rs = 1'b1; end
            S_WRITE_L2: begin op_data = ch2;   op_rs = 1'b1; end
            default: ;
        endcase
        if (state == S_PULSE_E || state == S_WAIT) begin
            wr_data = cur_data; wr_rs = cur_rs;
        end else begin
            wr_data = op_data;  wr_rs = op_rs;
        end
    end

endmodule