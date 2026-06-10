// Módulo: module_alu
// Função: Unidade Lógica e Aritmética (ALU) da Mini CPU.

module module_alu (
    input  wire signed [15:0] op_a,
    input  wire signed [15:0] op_b,
    input  wire [2:0] opcode,

    output reg signed [15:0] resultado,
    output reg overflow
);

    // Códigos das instruções
    localparam LOAD    = 3'b000;
    localparam ADD     = 3'b001;
    localparam ADDI    = 3'b010;
    localparam SUB     = 3'b011;
    localparam SUBI    = 3'b100;
    localparam MUL     = 3'b101;
    localparam CLEAR   = 3'b110;
    localparam DISPLAY = 3'b111;

    // Registrador auxiliar de 32 bits para multiplicação segura
    reg signed [31:0] temp;

    always @(*) begin
        // Valores padrão para evitar inferred latches
        resultado = 16'sd0;
        overflow  = 1'b0;
        temp      = 32'sd0;

        case (opcode)

            // LOAD: apenas repassa o valor recebido (Imediato vem via op_b)
            LOAD: begin
                resultado = op_b;
            end

            // Soma (ADD e ADDI)
            ADD, ADDI: begin
                resultado = op_a + op_b;
                // Overflow: Sinais iguais geram resultado com sinal diferente
                overflow = (op_a[15] == op_b[15]) && (resultado[15] != op_a[15]);
            end

            // Subtração (SUB e SUBI)
            SUB, SUBI: begin
                resultado = op_a - op_b;
                // Overflow: Sinais diferentes geram resultado com sinal diferente de op_a
                overflow = (op_a[15] != op_b[15]) && (resultado[15] != op_a[15]);
            end

            // Multiplicação com expansão de sinal correta
            MUL: begin
                // Força o Verilog a expandir op_a e op_b para 32 bits assinados antes de multiplicar
                temp = {{16{op_a[15]}}, op_a} * {{16{op_b[15]}}, op_b};
                
                resultado = temp[15:0];

                // Verifica se os 16 bits superiores não são apenas a extensão do bit de sinal do resultado
                overflow = (temp[31:16] != {16{temp[15]}});
            end

            // CLEAR: zera o resultado
            CLEAR: begin
                resultado = 16'sd0;
                overflow  = 1'b0;
            end

            // DISPLAY: repassa o valor do registrador selecionado (passado em op_a)
            DISPLAY: begin
                resultado = op_a;
            end

            default: begin
                resultado = 16'sd0;
                overflow  = 1'b0;
            end
        endcase
    end

endmodule