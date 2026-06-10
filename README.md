# Mini CPU — Sistemas Digitais | CIn UFPE

Implementação de uma Mini CPU em Verilog para a placa FPGA DE2-115 (Cyclone IV).
A CPU processa 8 instruções, armazena resultados em um banco de 16 registradores de 16 bits e exibe o resultado no LCD da placa.

---

## Fluxo de Execução

```
1. Solta KEY[0]   →  Sistema liga, LCD inicializa, registradores zerados
2. Configura SW   →  Define a instrução nos switches
3. Solta KEY[1]   →  CPU executa a instrução
4. LCD atualiza   →  Exibe a operação e o resultado
5. Repete 2-4     →  Para executar mais instruções
6. Solta KEY[0]   →  Sistema desliga, registradores zerados
```

Internamente, a CPU segue o ciclo clássico de um processador:

```
Fetch → Decode → Execute → Writeback → Update LCD
```

A FSM principal do `module_mini_cpu` controla cada etapa:

| Estado | Descrição |
|--------|-----------|
| `S_RESET` | Inicializa o sistema |
| `S_WAIT_BUTTON` | Aguarda o botão Enviar ser solto |
| `S_FETCH_DECODE` | Lê os switches e define os endereços de memória |
| `S_EXECUTE` | Executa a operação na ALU |
| `S_WRITE_BACK` | Salva o resultado na memória |
| `S_UPDATE_LCD` | Envia os dados para o LCD |
| `S_WAIT_LCD` | Aguarda o LCD terminar (~200ms) |

---

## Módulos

### module_mini_cpu.v — Top-Level
Módulo principal que orquestra todos os outros. Decodifica a instrução recebida pelos switches, controla o fluxo de dados entre a memória e a ALU, e atualiza o LCD com o resultado. Contém a FSM principal da CPU.

### module_alu.v — Unidade Lógica e Aritmética
Recebe dois operandos signed de 16 bits e o opcode, e retorna o resultado da operação. Detecta overflow para todas as operações aritméticas.

Operações suportadas: `ADD`, `ADDI`, `SUB`, `SUBI`, `MUL`, `LOAD`, `CLEAR`, `DISPLAY`.

### module_memory.v — Banco de Registradores
RAM de 16 × 16 bits (16 registradores signed de 16 bits cada). Suporta leitura simultânea de dois operandos (`q_a` e `q_b`) e escrita síncrona. O reset é feito de forma sequencial via FSM interna — um registrador por ciclo — sem uso de laços de repetição.

| Estado | Descrição |
|--------|-----------|
| `S_RESET` | Zera um registrador por ciclo até completar os 16 |
| `S_READY` | Operação normal de leitura e escrita |

### module_lcd.v — Controlador do LCD
Controla a escrita no display HD44780. Recebe o nome da operação, o registrador destino e o resultado, e escreve nas duas linhas do display. Inclui:
- Conversão **binário → decimal** pelo algoritmo Double Dabble (sem laços)
- FSM para sequenciar comandos e caracteres com os delays corretos
- Instância do `lcd_init_hd44780` para inicialização física do display

| Estado | Descrição |
|--------|-----------|
| `S_WAIT_INIT` | Aguarda inicialização do LCD |
| `S_IDLE` | Aguarda sinal de show |
| `S_CLEAR` | Envia comando Clear Display |
| `S_SET_L1` | Posiciona cursor na linha 1 |
| `S_WRITE_L1` | Escreve 16 caracteres na linha 1 |
| `S_SET_L2` | Posiciona cursor na linha 2 |
| `S_WRITE_L2` | Escreve 16 caracteres na linha 2 |
| `S_DONE` | Escrita concluída |

### lcd_init_hd44780.v — Inicialização do LCD
Realiza a sequência obrigatória de inicialização física do display HD44780, incluindo o triplo wake-up exigido pelo datasheet. Após concluir, sinaliza `done` para o `module_lcd` assumir o controle.

---

## Instruções

### Tabela de Opcodes

| Instrução | Opcode | Tipo |
|-----------|--------|------|
| LOAD      | 000    | Carga |
| ADD       | 001    | Reg × Reg |
| ADDI      | 010    | Reg × Imediato |
| SUB       | 011    | Reg × Reg |
| SUBI      | 100    | Reg × Imediato |
| MUL       | 101    | Reg × Imediato |
| CLEAR     | 110    | Especial |
| DISPLAY   | 111    | Especial |

---

### Tipo 1 — Reg × Reg (ADD, SUB)

Operam exclusivamente com registradores.

```
SW: [17:15] Opcode | [14:11] Dest | [10:7] Src1 | [6:3] Src2
```

Exemplo — `ADD R6, R7, R8`:
```
SW = 001_0110_0111_1000_00
```

---

### Tipo 2 — Reg × Imediato (ADDI, SUBI, MUL)

Operam entre um registrador e um valor imediato de 6 bits com sinal.

```
SW: [17:15] Opcode | [14:11] Dest | [10:7] Src1 | [6] Sinal | [5:0] Imediato
```

Exemplo — `ADDI R2, R1, 5`:
```
SW = 010_0010_0001_0_000101
```

---

### Tipo 3 — Carga (LOAD)

Carrega um valor imediato diretamente em um registrador.

```
SW: [13:11] Opcode | [10:7] Dest | [6] Sinal | [5:0] Imediato
```

Exemplo — `LOAD R1, 10`:
```
SW = 000_0001_0_001010
```

---

### Tipo Especial (CLEAR, DISPLAY)

```
SW: [17:15] Opcode | [3:0] Src1
```

Exemplo — `DISPLAY R2`:
```
SW = 111_0010
```

---

## LCD

O display exibe duas linhas de 16 caracteres cada:

```
ADD     [0001]
        +00012
```

| Posição | Conteúdo |
|---------|----------|
| Linha 1 — esquerda | Nome da operação: `ADD `, `ADDI`, `LOAD`, `SUBI`, `MUL `, `CLR `, `DSP ` |
| Linha 1 — direita | Registrador destino em binário: `[0001]` |
| Linha 2 — direita | Sinal + valor decimal do resultado: `+00012` ou `-00005` |

Para instruções do tipo `CLEAR`, apenas o nome da operação é exibido.
Para instruções do tipo `DISPLAY`, exibe o valor atual do registrador selecionado.

---

## Especificações

| Item | Especificação |
|------|---------------|
| Placa | DE2-115 (Terasic) |
| FPGA | Cyclone IV — EP4CE115F29C7 |
| Clock | 50 MHz |
| Ferramenta | Quartus Prime Lite 21.1 |
| Linguagem | Verilog HDL |
| Registradores | 16 × 16 bits (signed) |
| Display | LCD HD44780 2×16 |
