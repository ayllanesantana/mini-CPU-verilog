// Módulo: module_lcd 
// Descrição: Interface para o LCD HD44780 da placa DE2-115.
//            Exibe o nome da operação (4 caracteres), o registrador de destino
//            e o resultado assinado de 16 bits (com tratamento para -32768).
            
module module_lcd (
    input  wire        clk,
    input  wire        rst,
    input  wire        show,

    input  wire [7:0]  opname_0, input wire [7:0] opname_1,
    input  wire [7:0]  opname_2, input wire [7:0] opname_3,

    input  wire [3:0]  dest_reg,
    input  wire signed [15:0] result,

    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    wire [7:0] init_data; wire init_rs, init_rw, init_e;
    wire       init_done; 
    reg        start_init;

    // Instanciação do inicializador estável com triplo wake-up
    lcd_init_hd44780 lcd_init (
        .clk (clk), .rst (rst), .start (start_init), .done (init_done),
        .lcd_data (init_data), .lcd_rs (init_rs), .lcd_rw (init_rw), .lcd_e (init_e)
    );

    reg [7:0] wr_data; reg wr_rs; wire wr_rw; wire wr_e;

    // Multiplexação do barramento baseada no término da inicialização
    assign lcd_data = (!init_done) ? init_data : wr_data;
    assign lcd_rs   = (!init_done) ? init_rs   : wr_rs;
    assign lcd_rw   = (!init_done) ? init_rw   : wr_rw;
    assign lcd_e    = (!init_done) ? init_e    : wr_e;

    // Delays calibrados para clock de 50 MHz (período de 20ns)
    localparam [31:0] DELAY_WRITE = 32'd2_500;   // ~50 us
    localparam [31:0] DELAY_PULSE = 32'd50;      // ~1 us
    localparam [31:0] DELAY_CLEAR = 32'd100_000; // ~2 ms

    // DOUBLE DABBLE CORRIGIDO DE 17 BITS 

    reg [16:0] mag; reg [19:0] bcd; reg is_neg;

    always @(*) begin
        is_neg = result[15];
        // Ao expandir a operação para 17 bits, o Verilog consegue representar 
        // o valor positivo de +32768 (17'h08000) sem estourar em complemento de 2!
        mag    = is_neg ? (-result) : {1'b0, result}; 
        bcd    = 20'b0;

        // Bit 16 (Passo extra adicionado para processar a magnitude expandida)
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[16]};

        // Bit 15
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[15]};

        // Bit 14
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[14]};

        // Bit 13
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[13]};

        // Bit 12
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[12]};

        // Bit 11
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[11]};

        // Bit 10
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[10]};

        // Bit 9
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[9]};

        // Bit 8
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[8]};

        // Bit 7
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[7]};

        // Bit 6
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[6]};

        // Bit 5
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[5]};

        // Bit 4
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[4]};

        // Bit 3
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[3]};

        // Bit 2
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[2]};

        // Bit 1
        if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
        if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
        if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
        if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
        if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
        bcd = {bcd[18:0], mag[1]};

        // Bit 0 (Deslocamento puro final - Obrigatório do algoritmo)
        bcd = {bcd[18:0], mag[0]};
    end

    // Conversão estável dos dígitos BCD para a tabela ASCII (+48)
    wire [7:0] dig4 = 8'd48 + {4'b0, bcd[19:16]};
    wire [7:0] dig3 = 8'd48 + {4'b0, bcd[15:12]};
    wire [7:0] dig2 = 8'd48 + {4'b0, bcd[11:8]};
    wire [7:0] dig1 = 8'd48 + {4'b0, bcd[7:4]};
    wire [7:0] dig0 = 8'd48 + {4'b0, bcd[3:0]};
    wire [7:0] sign_char = is_neg ? 8'd45 : 8'd43; // 45='-', 43='+'

    // Conversão do número do registrador para ASCII (Binário para caractere '0' ou '1')
    wire [7:0] dreg3 = 8'd48 + {7'b0, dest_reg[3]};
    wire [7:0] dreg2 = 8'd48 + {7'b0, dest_reg[2]};
    wire [7:0] dreg1 = 8'd48 + {7'b0, dest_reg[1]};
    wire [7:0] dreg0 = 8'd48 + {7'b0, dest_reg[0]};

    // Mapeamento estático e combinacional das linhas 1 e 2 do LCD
    reg [7:0] line1 [0:15]; reg [7:0] line2 [0:15];
    always @(*) begin
        line1[0] = opname_0; line1[1] = opname_1; line1[2] = opname_2; line1[3] = opname_3;
        line1[4] = " ";      line1[5] = " ";      line1[6] = " ";      line1[7] = "[";
        line1[8] = dreg3;    line1[9] = dreg2;    line1[10]= dreg1;    line1[11]= dreg0;
        line1[12]= "]";      line1[13]= " ";      line1[14]= " ";      line1[15]= " ";

        line2[0] = " ";      line2[1] = " ";      line2[2] = " ";      line2[3] = " ";
        line2[4] = " ";      line2[5] = " ";      line2[6] = " ";      line2[7] = " ";
        line2[8] = sign_char;line2[9] = dig4;     line2[10]= dig3;     line2[11]= dig2;
        line2[12]= dig1;     line2[13]= dig0;     line2[14]= " ";      line2[15]= " ";
    end

    // Estados da Máquina de Estados de Escrita (FSM)
    localparam [3:0]
        S_WAIT_INIT  = 4'd0,
        S_IDLE       = 4'd1,
        S_CLEAR      = 4'd2,
        S_SET_L1     = 4'd3,
        S_WRITE_L1   = 4'd4,
        S_SET_L2     = 4'd5,
        S_WRITE_L2   = 4'd6,
        S_PULSE_E    = 4'd7,
        S_WAIT       = 4'd8,
        S_DONE       = 4'd9;

    reg [3:0]  state,        next_state;
    reg [3:0]  return_state, next_return_state;
    reg [31:0] delay_cnt,    next_delay_cnt;
    reg [4:0]  char_idx,     next_char_idx;

    // BLOCO SEQUENCIAL: Atualização de Estados e Sinais de Controle

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_WAIT_INIT;
            return_state <= S_IDLE;
            delay_cnt    <= 32'd0;
            char_idx     <= 5'd0;
            start_init   <= 1'b1; // Dispara a inicialização imediatamente no reset
        end else begin
            state        <= next_state;
            return_state <= next_return_state;
            delay_cnt    <= next_delay_cnt;
            char_idx     <= next_char_idx;
            
            // Derruba o sinal de start assim que o inicializador começar a trabalhar
            if (state == S_WAIT_INIT && !init_done)
                start_init <= 1'b0;
        end
    end

    // BLOCO COMBINACIONAL: Transições de Estados
    
    always @(*) begin
        next_state        = state;
        next_return_state = return_state;
        next_delay_cnt    = delay_cnt;
        next_char_idx     = char_idx;

        case (state)
            S_WAIT_INIT: if (init_done) next_state = S_IDLE;

            S_IDLE: if (show) next_state = S_CLEAR;

            S_CLEAR: begin
                next_return_state = S_SET_L1;
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
                    // Se viemos do S_CLEAR, precisamos esperar o delay longo de limpeza (DELAY_CLEAR)
                    next_delay_cnt = (return_state == S_SET_L1) ? DELAY_CLEAR : DELAY_WRITE;
                    next_state     = S_WAIT;
                end
            end

            S_WAIT: begin
                if (delay_cnt > 0)
                    next_delay_cnt = delay_cnt - 1;
                else begin
                    // Incrementa o índice de caracteres apenas quando terminar a escrita estável
                    if (return_state == S_WRITE_L1 || return_state == S_WRITE_L2)
                        next_char_idx = char_idx + 1;
                    next_state = return_state;
                end
            end

            S_DONE: next_state = S_IDLE;
            default: next_state = S_WAIT_INIT;
        endcase
    end

    // Sinais estáticos de escrita do barramento
    assign wr_rw = 1'b0;                 // Operação constante de Escrita ('0')
    assign wr_e  = (state == S_PULSE_E); // Gera o pulso de Enable apenas no estado correto

    // BLOCO COMBINACIONAL: Geração dos Dados e Sinais de Registro (RS)
    
    always @(*) begin
        wr_data = 8'h00;
        wr_rs   = 1'b0;

        case (state)
            S_CLEAR:    begin wr_data = 8'h01; wr_rs = 1'b0; end 
            S_SET_L1:   begin wr_data = 8'h80; wr_rs = 1'b0; end 
            S_SET_L2:   begin wr_data = 8'hC0; wr_rs = 1'b0; end 
            S_WRITE_L1: begin wr_data = line1[char_idx]; wr_rs = 1'b1; end 
            S_WRITE_L2: begin wr_data = line2[char_idx]; wr_rs = 1'b1; end 

            // Durante o pulso elétrico e a espera pós-pulso, o dado 
            // e o sinal RS devem ser idênticos ao estado original que disparou a operação.
      
            S_PULSE_E, S_WAIT: begin
                case (return_state)
                    S_SET_L1:   begin wr_data = 8'h01; wr_rs = 1'b0; end // Mantém estável o S_CLEAR
                    S_WRITE_L1: begin wr_data = 8'h80; wr_rs = 1'b0; end // Mantém estável o S_SET_L1
                    S_SET_L2:   begin wr_data = line1[char_idx]; wr_rs = 1'b1; end // Mantém estável o S_WRITE_L1
                    S_WRITE_L2: begin wr_data = 8'hC0; wr_rs = 1'b0; end // Mantém estável o S_SET_L2
                    S_DONE:     begin wr_data = line2[char_idx]; wr_rs = 1'b1; end // Mantém estável o S_WRITE_L2
                    default:    begin wr_data = 8'h00; wr_rs = 1'b0; end
                endcase
            end

            default: begin wr_data = 8'h00; wr_rs = 1'b0; end
        endcase
    end

endmodule