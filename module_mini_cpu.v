// Módulo: module_mini_cpu (Top-Level)
// Função: Orquestra a Mini CPU, realiza o Decode, controla o fluxo de dados
//         entre a Memória, ULA e atualiza o LCD da placa DE2-115.

module module_mini_cpu (
    input  wire        clk,
    input  wire        btn_clear,
    input  wire        btn_send,
    input  wire [17:0] sw,
    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    // Opcodes
   
    localparam [2:0] OP_LOAD    = 3'b000;
    localparam [2:0] OP_ADD     = 3'b001;
    localparam [2:0] OP_ADDI    = 3'b010;
    localparam [2:0] OP_SUB     = 3'b011;
    localparam [2:0] OP_SUBI    = 3'b100;
    localparam [2:0] OP_MUL     = 3'b101;
    localparam [2:0] OP_CLEAR   = 3'b110;
    localparam [2:0] OP_DISPLAY = 3'b111;

    // Decodificação dos switches
 
    wire [2:0] opcode = sw[17:15];
    wire [3:0] r_dest = sw[14:11];
    wire [3:0] r_src1 = sw[10:7];
    wire [3:0] r_src2 = sw[6:3];

    // Extensão de sinal correta: sw[6]=1 → negativo, sw[6]=0 → positivo
    wire signed [15:0] imediato = sw[6] ? {{10{1'b1}}, sw[5:0]} : {{10{1'b0}}, sw[5:0]};

    // Reset físico (botões ativos em baixo)
    
    wire internal_rst = ~btn_clear;

    // Detecção de borda de subida do btn_send (soltar = 0→1)
   
    reg btn_send_r1, btn_send_r2;
    always @(posedge clk or posedge internal_rst) begin
        if (internal_rst) begin
            btn_send_r1 <= 1'b1;
            btn_send_r2 <= 1'b1;
        end else begin
            btn_send_r1 <= btn_send;
            btn_send_r2 <= btn_send_r1;
        end
    end
    wire pulse_execute = (btn_send_r2 == 1'b0 && btn_send_r1 == 1'b1);

    // Sinais internos

    reg        mem_we;
    reg        mem_clear_inst;
    reg  [3:0] mem_addr_dest;
    reg  [3:0] mem_addr_a;
    reg  [3:0] mem_addr_b;
    reg  signed [15:0] mem_data_in;
    wire signed [15:0] mem_q_a;
    wire signed [15:0] mem_q_b;

    reg  signed [15:0] alu_op_a;
    reg  signed [15:0] alu_op_b;
    wire signed [15:0] alu_resultado;
    wire               alu_overflow;

    reg        lcd_show;
    reg  [7:0] lcd_opname_0, lcd_opname_1, lcd_opname_2, lcd_opname_3;
    reg  [3:0] lcd_dest_reg;
    reg  signed [15:0] lcd_result_val;

    // Contador de espera do LCD (~200ms a 50MHz)
    localparam [24:0] LCD_WAIT_MAX = 25'd10_000_000;
    reg [24:0] lcd_wait_cnt;

    // Instâncias
 
    module_memory u_memory (
        .clk        (clk),
        .rst        (internal_rst),
        .clear_inst (mem_clear_inst),
        .we         (mem_we),
        .addr_dest  (mem_addr_dest),
        .addr_a     (mem_addr_a),
        .addr_b     (mem_addr_b),
        .data_in    (mem_data_in),
        .q_a        (mem_q_a),
        .q_b        (mem_q_b)
    );

    module_alu u_alu (
        .op_a      (alu_op_a),
        .op_b      (alu_op_b),
        .opcode    (opcode),
        .resultado (alu_resultado),
        .overflow  (alu_overflow)
    );

    module_lcd u_lcd (
        .clk      (clk),
        .rst      (internal_rst),
        .show     (lcd_show),
        .opname_0 (lcd_opname_0),
        .opname_1 (lcd_opname_1),
        .opname_2 (lcd_opname_2),
        .opname_3 (lcd_opname_3),
        .dest_reg (lcd_dest_reg),
        .result   (lcd_result_val),
        .lcd_data (lcd_data),
        .lcd_rs   (lcd_rs),
        .lcd_rw   (lcd_rw),
        .lcd_e    (lcd_e)
    );

    // FSM

    localparam [2:0]
        S_RESET        = 3'd0,
        S_WAIT_BUTTON  = 3'd1,
        S_FETCH_DECODE = 3'd2,
        S_EXECUTE      = 3'd3,
        S_WRITE_BACK   = 3'd4,
        S_UPDATE_LCD   = 3'd5,
        S_WAIT_LCD     = 3'd6;

    reg [2:0] state, next_state;

    // 1) BLOCO SEQUENCIAL
    always @(posedge clk or posedge internal_rst) begin
        if (internal_rst) begin
            state        <= S_RESET;
            lcd_wait_cnt <= 25'd0;
        end else begin
            state <= next_state;
            // contador de espera do LCD
            if (state == S_WAIT_LCD)
                lcd_wait_cnt <= lcd_wait_cnt + 1;
            else
                lcd_wait_cnt <= 25'd0;
        end
    end

    // 2) BLOCO COMBINACIONAL: próximo estado
    always @(*) begin
        next_state = state;
        case (state)
            S_RESET:        next_state = S_WAIT_BUTTON;
            S_WAIT_BUTTON:  if (pulse_execute) next_state = S_FETCH_DECODE;
            S_FETCH_DECODE: next_state = S_EXECUTE;
            S_EXECUTE:      next_state = S_WRITE_BACK;
            S_WRITE_BACK:   next_state = S_UPDATE_LCD;
            S_UPDATE_LCD:   next_state = S_WAIT_LCD;
            S_WAIT_LCD:     if (lcd_wait_cnt >= LCD_WAIT_MAX) next_state = S_WAIT_BUTTON;
            default:        next_state = S_WAIT_BUTTON;
        endcase
    end

    // 3) BLOCO COMBINACIONAL: saídas
    always @(*) begin
        // defaults
        mem_we         = 1'b0;
        mem_clear_inst = 1'b0;
        mem_addr_dest  = r_dest;
        mem_addr_a     = r_src1;
        mem_addr_b     = r_src2;
        mem_data_in    = alu_resultado;

        alu_op_a       = mem_q_a;
        alu_op_b       = mem_q_b;

        lcd_show       = 1'b0;
        lcd_dest_reg   = r_dest;
        lcd_result_val = alu_resultado;

        // Nome da operação
        case (opcode)
            OP_LOAD:    begin lcd_opname_0="L"; lcd_opname_1="O"; lcd_opname_2="A"; lcd_opname_3="D"; end
            OP_ADD:     begin lcd_opname_0="A"; lcd_opname_1="D"; lcd_opname_2="D"; lcd_opname_3=" "; end
            OP_ADDI:    begin lcd_opname_0="A"; lcd_opname_1="D"; lcd_opname_2="D"; lcd_opname_3="I"; end
            OP_SUB:     begin lcd_opname_0="S"; lcd_opname_1="U"; lcd_opname_2="B"; lcd_opname_3=" "; end
            OP_SUBI:    begin lcd_opname_0="S"; lcd_opname_1="U"; lcd_opname_2="B"; lcd_opname_3="I"; end
            OP_MUL:     begin lcd_opname_0="M"; lcd_opname_1="U"; lcd_opname_2="L"; lcd_opname_3=" "; end
            OP_CLEAR:   begin lcd_opname_0="C"; lcd_opname_1="L"; lcd_opname_2="R"; lcd_opname_3=" "; end
            OP_DISPLAY: begin lcd_opname_0="D"; lcd_opname_1="S"; lcd_opname_2="P"; lcd_opname_3=" "; end
            default:    begin lcd_opname_0="E"; lcd_opname_1="R"; lcd_opname_2="R"; lcd_opname_3=" "; end
        endcase

        case (state)
            S_FETCH_DECODE: begin
                // Define endereços de leitura conforme o tipo de instrução
                if (opcode == OP_DISPLAY) begin
                    mem_addr_a = r_dest;
                    mem_addr_b = 4'd0;
                end else begin
                    mem_addr_a = r_src1;
                    mem_addr_b = r_src2;
                end
            end

            S_EXECUTE: begin
                // Define operandos da ALU
                alu_op_a = mem_q_a;
                if (opcode == OP_LOAD || opcode == OP_ADDI ||
                    opcode == OP_SUBI || opcode == OP_MUL)
                    alu_op_b = imediato;
                else
                    alu_op_b = mem_q_b;
            end

            S_WRITE_BACK: begin
                // Mantém operandos estáveis para ALU
                alu_op_a = mem_q_a;
                alu_op_b = (opcode == OP_LOAD || opcode == OP_ADDI ||
                            opcode == OP_SUBI || opcode == OP_MUL) ? imediato : mem_q_b;

                mem_addr_dest = r_dest;
                mem_data_in   = alu_resultado;

                if (opcode == OP_CLEAR) begin
                    mem_clear_inst = 1'b1;
                    mem_we         = 1'b0;
                end else if (opcode == OP_DISPLAY) begin
                    mem_we         = 1'b0;
                end else begin
                    mem_we         = 1'b1;
                end
            end

            S_UPDATE_LCD: begin
                lcd_show     = 1'b1;
                lcd_dest_reg = r_dest;

                if (opcode == OP_DISPLAY) begin
                    mem_addr_a     = r_dest;
                    lcd_result_val = mem_q_a;
                end else begin
                    alu_op_a       = mem_q_a;
                    alu_op_b       = (opcode == OP_LOAD || opcode == OP_ADDI ||
                                      opcode == OP_SUBI || opcode == OP_MUL) ? imediato : mem_q_b;
                    lcd_result_val = alu_resultado;
                end
            end

            default: begin
                mem_addr_a = r_src1;
            end
        endcase
    end

endmodule