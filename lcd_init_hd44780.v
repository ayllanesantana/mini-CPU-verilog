// Módulo: lcd_init_hd44780 
// Versão estável: FSM síncrona com sequência completa de Wake-up.

module lcd_init_hd44780 (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg         done,
    output reg  [7:0]  lcd_data,
    output reg         lcd_rs,
    output reg         lcd_rw,
    output reg         lcd_e
);
    // Comandos HD44780
    localparam [7:0] CMD_WAKEUP        = 8'h38; // Modo 8-bits, 2 linhas
    localparam [7:0] CMD_DISPLAY_ON    = 8'h0C; // Display ON, cursor OFF
    localparam [7:0] CMD_DISPLAY_CLEAR = 8'h01; // Limpa display
    localparam [7:0] CMD_ENTRY_MODE    = 8'h06; // Incrementa cursor

    // 7 passos obrigatórios para garantir a inicialização física
    localparam integer NUM_CMDS = 7;

    // Temporizações ajustadas para clock de 50 MHz
    localparam [31:0] DELAY_POWER_ON   = 32'd1_000_000; // ~20 ms (estabilização da fonte)
    localparam [31:0] DELAY_WAKEUP_1   = 32'd250_000;   // ~5 ms (exigido > 4.1 ms)
    localparam [31:0] DELAY_WAKEUP_2   = 32'd7_500;     // ~150 us (exigido > 100 us)
    localparam [31:0] DELAY_STD_CMD     = 32'd2_500;     // ~50 us (exigido > 37 us)
    localparam [31:0] DELAY_CLEAR_CMD   = 32'd100_000;   // ~2 ms (exigido > 1.52 ms)
    localparam [31:0] DELAY_PULSE_E     = 32'd50;        // ~1 us pulso de Enable

    localparam [2:0]
        S_IDLE       = 3'd0,
        S_POWER_WAIT = 3'd1,
        S_SETUP      = 3'd2,
        S_PULSE      = 3'd3,
        S_WAIT       = 3'd4,
        S_DONE       = 3'd5;

    reg [2:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [2:0]  cmd_idx, next_cmd_idx;
    
    reg [7:0]  current_cmd;
    reg [31:0] current_delay;

    // 1) BLOCO SEQUENCIAL
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            delay_cnt <= 32'd0;
            cmd_idx   <= 3'd0;
        end else begin
            state     <= next_state;
            delay_cnt <= next_delay_cnt;
            cmd_idx   <= next_cmd_idx;
        end
    end

    // 2) BLOCO COMBINACIONAL: Lógica da ROM 
    always @(*) begin
        case (cmd_idx)
            3'd0: begin current_cmd = CMD_WAKEUP;        current_delay = DELAY_WAKEUP_1; end // Triplo wake-up obrigatório
            3'd1: begin current_cmd = CMD_WAKEUP;        current_delay = DELAY_WAKEUP_2; end
            3'd2: begin current_cmd = CMD_WAKEUP;        current_delay = DELAY_STD_CMD;   end
            3'd3: begin current_cmd = CMD_WAKEUP;        current_delay = DELAY_STD_CMD;   end // Configuração definitiva
            3'd4: begin current_cmd = CMD_DISPLAY_ON;    current_delay = DELAY_STD_CMD;   end
            3'd5: begin current_cmd = CMD_DISPLAY_CLEAR; current_delay = DELAY_CLEAR_CMD; end
            3'd6: begin current_cmd = CMD_ENTRY_MODE;    current_delay = DELAY_STD_CMD;   end
            default: begin current_cmd = 8'h00;          current_delay = 32'd0;           end
        endcase
    end

    // 3) BLOCO COMBINACIONAL: Transição de Estados
    always @(*) begin
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_cmd_idx   = cmd_idx;

        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state     = S_POWER_WAIT;
                    next_delay_cnt = DELAY_POWER_ON;
                    next_cmd_idx   = 3'd0;
                end
            end
            S_POWER_WAIT: begin
                if (delay_cnt > 0)
                    next_delay_cnt = delay_cnt - 1;
                else
                    next_state = S_SETUP;
            end
            S_SETUP: begin
                if (cmd_idx < NUM_CMDS) begin
                    next_state     = S_PULSE;
                    next_delay_cnt = DELAY_PULSE_E;
                end else
                    next_state = S_DONE;
            end
            S_PULSE: begin
                if (delay_cnt > 0)
                    next_delay_cnt = delay_cnt - 1;
                else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = current_delay;
                end
            end
            S_WAIT: begin
                if (delay_cnt > 0)
                    next_delay_cnt = delay_cnt - 1;
                else begin
                    next_cmd_idx = cmd_idx + 1;
                    next_state   = S_SETUP;
                end
            end
            S_DONE: begin
                // Garante que o estado final permaneça retido
                next_state = S_DONE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // 4) BLOCO COMBINACIONAL: Atribuição estável de Saídas
    always @(*) begin
        lcd_data = 8'h00;
        lcd_rs   = 1'b0;
        lcd_rw   = 1'b0;
        lcd_e    = 1'b0;
        done     = 1'b0;

        case (state)
            S_SETUP: begin
                lcd_data = current_cmd;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end
            S_PULSE: begin
                lcd_data = current_cmd;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b1; // Pulso ativo
            end
            S_WAIT: begin
                lcd_data = current_cmd; // Segura os dados estáveis pós-pulso (Hold Time)
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end
            S_DONE: begin
                done     = 1'b1;
                lcd_data = 8'h00;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end
            default: begin
                lcd_data = 8'h00;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end
        endcase
    end

endmodule