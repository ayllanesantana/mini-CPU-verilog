// Módulo: module_mini_cpu (Top-Level)
// Função: Mini CPU para a DE2-115. FSM: Fetch -> Execute -> Write-back -> LCD.
//   KEY0 (btn_clear): liga/desliga, ao SOLTAR. Desligado = display apagado, CPU parada.
//   KEY1 (btn_send) : envia a instrução dos switches, ao SOLTAR.
//
// Formato dos switches (18 bits):
//   Reg x Reg  (ADD, SUB)            : [17:15] op | [14:11] dest | [10:7] src1 | [6:3] src2
//   Reg x Imm  (ADDI, SUBI, MUL)     : [17:15] op | [14:11] dest | [10:7] src1 | [6] sinal | [5:0] módulo
//   Carga      (LOAD)                : [17:15] op | [14:11] dest | [6] sinal | [5:0] módulo
//   Especiais  (CLEAR, DISPLAY)      : [17:15] op | [14:11] registrador (DISPLAY)
// O imediato é SINAL + MÓDULO (bit de sinal = 1 -> negativo).

module module_mini_cpu (
    input  wire        clk,
    input  wire        btn_clear,   // KEY0: liga/desliga
    input  wire        btn_send,    // KEY1: enviar
    input  wire [17:0] sw,
    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e,
    output wire        lcd_on,
    output wire        lcd_blon
);

    // Alimentação / backlight do LCD da DE2-115
    assign lcd_on   = 1'b1;
    assign lcd_blon = 1'b1;

    localparam [2:0] OP_LOAD    = 3'b000;
    localparam [2:0] OP_ADD     = 3'b001;
    localparam [2:0] OP_ADDI    = 3'b010;
    localparam [2:0] OP_SUB     = 3'b011;
    localparam [2:0] OP_SUBI    = 3'b100;
    localparam [2:0] OP_MUL     = 3'b101;
    localparam [2:0] OP_CLEAR   = 3'b110;
    localparam [2:0] OP_DISPLAY = 3'b111;

    // Reset de energização (garante que o LCD inicializa sem precisar apertar nada)
    reg [7:0] por_cnt = 8'd0;
    reg       por_rst = 1'b1;
    always @(posedge clk) begin
        if (por_cnt != 8'hFF) por_cnt <= por_cnt + 8'd1;
        por_rst <= (por_cnt != 8'hFF);
    end

    // Botões: debounce (~21 ms) e pulso de 1 ciclo ao SOLTAR. Botões da placa são ativos em 0.
    wire pulse_power;
    wire pulse_send;
    button_pulse u_btn_power (.clk(clk), .btn_in(btn_clear), .pulse_out(pulse_power));
    button_pulse u_btn_send  (.clk(clk), .btn_in(btn_send),  .pulse_out(pulse_send));

    // Estados
    localparam [3:0]
        S_OFF      = 4'd0,
        S_SHOW_ON  = 4'd1,
        S_IDLE     = 4'd2,
        S_FETCH    = 4'd3,
        S_EXECUTE  = 4'd4,
        S_WRITE    = 4'd5,
        S_SHOW     = 4'd6,
        S_WAIT_LCD = 4'd7,
        S_SHOW_OFF = 4'd8;

    reg [3:0]         state   = S_OFF;
    reg               on_flag = 1'b0;     // 1 = sistema ligado
    reg [17:0]        ir      = 18'd0;    // instrução travada no FETCH
    reg signed [15:0] res_r   = 16'sd0;   // resultado travado no EXECUTE

    wire lcd_ready;

    // Decodificação a partir da instrução travada
    wire [2:0] opcode = ir[17:15];
    wire [3:0] r_dest = ir[14:11];
    wire [3:0] r_src1 = ir[10:7];
    wire [3:0] r_src2 = ir[6:3];

    // Imediato (LOAD, ADDI, SUBI, MUL): sinal em [6], módulo em [5:0]
    wire signed [15:0] imm_mag  = {10'b0, ir[5:0]};
    wire signed [15:0] imediato = ir[6] ? -imm_mag : imm_mag;   // sinal + módulo

    wire is_imm = (opcode == OP_LOAD) || (opcode == OP_ADDI) ||
                  (opcode == OP_SUBI) || (opcode == OP_MUL);

    // Endereços de leitura (a memória registra o endereço: no FETCH usa os switches)
    wire [3:0] mem_addr_a = (state == S_FETCH)
                            ? ((sw[17:15] == OP_DISPLAY) ? sw[14:11] : sw[10:7])
                            : ((opcode == OP_DISPLAY) ? r_dest : r_src1);
    wire [3:0] mem_addr_b = (state == S_FETCH) ? sw[6:3] : r_src2;

    wire signed [15:0] mem_q_a, mem_q_b;
    wire signed [15:0] alu_resultado;
    wire               alu_overflow;

    wire mem_we         = (state == S_WRITE) && (opcode != OP_CLEAR) && (opcode != OP_DISPLAY);
    wire mem_clear_inst = (state == S_WRITE) && (opcode == OP_CLEAR);

    module_memory u_memory (
        .clk        (clk),
        .rst        (por_rst | ~on_flag),
        .clear_inst (mem_clear_inst),
        .we         (mem_we),
        .addr_dest  (r_dest),
        .addr_a     (mem_addr_a),
        .addr_b     (mem_addr_b),
        .data_in    (res_r),
        .q_a        (mem_q_a),
        .q_b        (mem_q_b)
    );

    module_alu u_alu (
        .op_a      (mem_q_a),
        .op_b      (is_imm ? imediato : mem_q_b),
        .opcode    (opcode),
        .resultado (alu_resultado),
        .overflow  (alu_overflow)
    );

    // LCD
    reg [7:0] opn0, opn1, opn2, opn3;
    always @(*) begin
        case (opcode)
            OP_LOAD:    begin opn0="L"; opn1="O"; opn2="A"; opn3="D"; end
            OP_ADD:     begin opn0="A"; opn1="D"; opn2="D"; opn3=" "; end
            OP_ADDI:    begin opn0="A"; opn1="D"; opn2="D"; opn3="I"; end
            OP_SUB:     begin opn0="S"; opn1="U"; opn2="B"; opn3=" "; end
            OP_SUBI:    begin opn0="S"; opn1="U"; opn2="B"; opn3="I"; end
            OP_MUL:     begin opn0="M"; opn1="U"; opn2="L"; opn3=" "; end
            OP_CLEAR:   begin opn0="C"; opn1="L"; opn2="R"; opn3=" "; end
            default:    begin opn0="D"; opn1="P"; opn2="L"; opn3=" "; end
        endcase
    end

    wire lcd_show = (state == S_SHOW) || (state == S_SHOW_ON) || (state == S_SHOW_OFF);
    wire [1:0] lcd_mode = (state == S_SHOW_ON)  ? 2'd2 :
                          (state == S_SHOW_OFF) ? 2'd3 :
                          (opcode == OP_CLEAR)  ? 2'd1 : 2'd0;

    module_lcd u_lcd (
        .clk      (clk),
        .rst      (por_rst),
        .show     (lcd_show),
        .mode     (lcd_mode),
        .opname_0 (opn0),
        .opname_1 (opn1),
        .opname_2 (opn2),
        .opname_3 (opn3),
        .dest_reg (r_dest),
        .result   (res_r),
        .ready    (lcd_ready),
        .lcd_data (lcd_data),
        .lcd_rs   (lcd_rs),
        .lcd_rw   (lcd_rw),
        .lcd_e    (lcd_e)
    );

    // FSM
    always @(posedge clk) begin
        if (por_rst) begin
            state   <= S_OFF;
            on_flag <= 1'b0;
        end else begin
            case (state)
                S_OFF:      if (pulse_power && lcd_ready) begin
                                on_flag <= 1'b1;
                                state   <= S_SHOW_ON;
                            end
                S_SHOW_ON:  state <= S_WAIT_LCD;
                S_IDLE:     if (pulse_power)     state <= S_SHOW_OFF;
                            else if (pulse_send) state <= S_FETCH;
                S_FETCH:    begin ir <= sw; state <= S_EXECUTE; end
                S_EXECUTE:  begin res_r <= alu_resultado; state <= S_WRITE; end
                S_WRITE:    state <= S_SHOW;
                S_SHOW:     state <= S_WAIT_LCD;
                S_SHOW_OFF: begin on_flag <= 1'b0; state <= S_WAIT_LCD; end
                S_WAIT_LCD: if (lcd_ready) state <= on_flag ? S_IDLE : S_OFF;
                default:    state <= S_OFF;
            endcase
        end
    end

endmodule


// Módulo auxiliar: sincroniza, filtra ruído mecânico (debounce) e gera um pulso de 1 ciclo
// quando o botão é SOLTO (0 -> 1 estável).
module button_pulse #(
    parameter [19:0] DEBOUNCE_MAX = 20'hFFFFF   // ~21 ms a 50 MHz
)(
    input  wire clk,
    input  wire btn_in,
    output reg  pulse_out = 1'b0
);
    reg sync_0 = 1'b1, sync_1 = 1'b1;
    reg [19:0] counter = 20'd0;
    reg stable = 1'b1, stable_prev = 1'b1;

    always @(posedge clk) begin
        sync_0 <= btn_in;
        sync_1 <= sync_0;

        if (sync_1 == stable) begin
            counter <= 20'd0;
        end else begin
            counter <= counter + 20'd1;
            if (counter == DEBOUNCE_MAX) stable <= sync_1;
        end

        stable_prev <= stable;
        pulse_out   <= (stable_prev == 1'b0) && (stable == 1'b1);
    end
endmodule