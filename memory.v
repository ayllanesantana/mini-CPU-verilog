// ---------------------------------------------------------------------------
// Módulo: memory
// Função: Banco de 16 registradores de 16 bits da Mini CPU.
//         Reset sequencial interno via FSM (um registrador por ciclo).
//         100% Livre de laços (for) e otimizado para RAM nativa M9K.
// ---------------------------------------------------------------------------
module module_memory (
    input  wire        clk,
    input  wire        rst,         // Reset assíncrono global (físico)
    input  wire        clear_inst,  // Reset síncrono da instrução CLEAR
    input  wire        we,
    input  wire [3:0]  addr_dest,
    input  wire [3:0]  addr_a,
    input  wire [3:0]  addr_b,
    input  wire signed [15:0] data_in,
    output wire signed [15:0] q_a,  // Mudado para wire para usar assign síncrono
    output wire signed [15:0] q_b   // Mudado para wire para usar assign síncrono
);

    reg signed [15:0] ram [0:15];

    // Estados da FSM
    localparam S_RESET = 2'd0; // Estado inicial: zera um registrador por ciclo
    localparam S_READY = 2'd1; // Operação normal de leitura e escrita

    reg        state, next_state; // Apenas 2 estados bastam!
    reg [3:0]  addr_clear, next_addr_clear;

    // Registradores para armazenar os endereços de leitura (Padrão Altera/Intel)
    reg [3:0]  addr_a_reg;
    reg [3:0]  addr_b_reg;

    // Inicialização segura para ferramentas de simulação
    integer idx;
    initial begin
        ram[4'd0]  = 16'sd0; ram[4'd1]  = 16'sd0; ram[4'd2]  = 16'sd0; ram[4'd3]  = 16'sd0;
        ram[4'd4]  = 16'sd0; ram[4'd5]  = 16'sd0; ram[4'd6]  = 16'sd0; ram[4'd7]  = 16'sd0;
        ram[4'd8]  = 16'sd0; ram[4'd9]  = 16'sd0; ram[4'd10] = 16'sd0; ram[4'd11] = 16'sd0;
        ram[4'd12] = 16'sd0; ram[4'd13] = 16'sd0; ram[4'd14] = 16'sd0; ram[4'd15] = 16'sd0;
    end

    // 1) BLOCO SEQUENCIAL: Escrita, FSM e Registro de Endereços
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_RESET;
            addr_clear <= 4'd0;
            // Opcional: limpa os registradores de endereços no reset
            addr_a_reg <= 4'd0;
            addr_b_reg <= 4'd0;
        end else begin
            state      <= next_state;
            addr_clear <= next_addr_clear;

            // Registro síncrono dos endereços de leitura (OBRIGATÓRIO para inferir RAM real)
            addr_a_reg <= addr_a;
            addr_b_reg <= addr_b;

            // Escrita normal durante operação ativa
            if (state == S_READY && we) begin
                ram[addr_dest] <= data_in;
            end

            // Limpeza sequencial: zera um registrador por ciclo quando em S_RESET
            if (state == S_RESET) begin
                ram[addr_clear] <= 16'sd0;
            end
        end
    end

    // 2) BLOCO COMBINACIONAL: Próximo Estado
    always @(*) begin
        next_state      = state;
        next_addr_clear = addr_clear;

        case (state)
            S_RESET: begin
                if (addr_clear == 4'd15) begin
                    next_state = S_READY;
                end else begin
                    next_addr_clear = addr_clear + 4'd1;
                end
            end

            S_READY: begin
                // Se receber o comando CLEAR via software, volta a varrer limpando tudo
                if (clear_inst) begin
                    next_state      = S_RESET;
                    next_addr_clear = 4'd0;
                end
            end

            default: next_state = S_READY;
        endcase
    end

    // 3) LEITURA SÍNCRONA (Estilo exato que você enviou da RAM da Altera)
    assign q_a = ram[addr_a_reg];
    assign q_b = ram[addr_b_reg];

endmodule