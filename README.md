# Mini CPU

Implementação de uma Mini CPU em Verilog para a placa FPGA DE2-115 (Cyclone IV).
A CPU processa 8 instruções, armazena resultados em um banco de 16 registradores de 16 bits
e exibe a operação e o resultado no LCD da placa.

---

## Como usar

```
1. Grava na placa  →  Sistema desligado: display vazio, CPU parada
2. Solta KEY[0]    →  Sistema liga: display mostra o modelo inicial, registradores zerados
3. Configura SW    →  Define a instrução nos 18 switches
4. Solta KEY[1]    →  CPU executa a instrução
5. LCD atualiza    →  Exibe a operação, o registrador de destino e o resultado
6. Repete 3-5      →  Para executar mais instruções
7. Solta KEY[0]    →  Sistema desliga: display apagado (registradores zerados ao ligar de novo)
```

- Os dois botões só agem ao serem **soltos**, e passam por um filtro de ruído (debounce de ~21 ms).
- Instruções enviadas com o sistema desligado são ignoradas.

### Display ao ligar (modelo inicial)

```
----   [----]
       +00000
```

---

## Arquitetura

```
module_mini_cpu  (top: FSM + botões)
 ├── module_memory      (memory.v)
 ├── module_alu         (module_alu.v)
 ├── module_lcd         (module_lcd.v)
 │    └── lcd_init_hd44780   (lcd_init_hd44780.v)
 └── button_pulse ×2    (dentro de module_mini_cpu.v)
```

### Ciclo de instrução

```
Fetch → Execute → Write-back → Update LCD
```

A instrução é travada no Fetch e o resultado no Execute. Assim, mexer nos switches ou na memória
depois do envio não altera o que aparece no display.

| Estado | Descrição |
|--------|-----------|
| `S_OFF` | Sistema desligado, aguarda KEY[0] ser solto |
| `S_SHOW_ON` | Pede ao LCD para mostrar o modelo inicial |
| `S_IDLE` | Ligado, aguarda KEY[1] (enviar) ou KEY[0] (desligar) |
| `S_FETCH` | Trava os 18 switches e envia os endereços à memória |
| `S_EXECUTE` | Executa a operação na ALU e trava o resultado |
| `S_WRITE` | Grava o resultado na memória (ou limpa tudo, no CLEAR) |
| `S_SHOW` | Pede ao LCD para mostrar operação, registrador e resultado |
| `S_WAIT_LCD` | Aguarda o LCD ficar pronto |
| `S_SHOW_OFF` | Pede ao LCD para apagar o display |

---

## Módulos

### module_mini_cpu.v — Top-Level
Contém a FSM principal, a decodificação da instrução travada, a ligação entre memória, ALU e LCD,
e o liga/desliga por KEY[0]. Também contém o módulo auxiliar `button_pulse`, que sincroniza o botão,
filtra o ruído mecânico (~21 ms) e gera um pulso de um ciclo quando o botão é solto.
A saída `lcd_on` fica em 1 (alimentação do LCD da placa).

### module_alu.v — Unidade Lógica e Aritmética
Recebe dois operandos de 16 bits com sinal e o opcode, e retorna o resultado.
Detecta overflow nas operações aritméticas.

Operações: `ADD`, `ADDI`, `SUB`, `SUBI`, `MUL`, `LOAD`, `CLEAR`, `DISPLAY`.

### memory.v — Banco de Registradores (`module_memory`)
RAM de 16 × 16 bits (16 registradores com sinal). Leitura simultânea de dois operandos
(`q_a` e `q_b`) e escrita síncrona. O reset é feito por uma FSM interna, um registrador por ciclo,
sem laços de repetição.

| Estado | Descrição |
|--------|-----------|
| `S_RESET` | Zera um registrador por ciclo até completar os 16 |
| `S_READY` | Operação normal de leitura e escrita |

### module_lcd.v — Controlador do LCD
Controla a escrita no display HD44780. No momento do pedido de escrita (`show`), **trava** o nome da
operação, o registrador de destino e o resultado, então o display não muda se as entradas mudarem
durante a escrita. Inclui:
- Conversão binário → decimal pelo algoritmo Double Dabble (17 bits, sem laços), com a checagem
  "≥ 5 soma 3" antes de todos os deslocamentos.
- FSM para sequenciar comandos e caracteres, com o dado e o RS travados durante o pulso de Enable.
- Sinal `ready` para a CPU saber quando o LCD terminou.
- Instância do `lcd_init_hd44780` para a inicialização física.

Modos de escrita: normal (nome, registrador e resultado), só o nome (CLEAR), modelo inicial
(ao ligar) e apagar (ao desligar).

| Estado | Descrição |
|--------|-----------|
| `S_WAIT_INIT` | Aguarda a inicialização do LCD |
| `S_IDLE` | Aguarda o pedido de escrita |
| `S_CLEAR` | Envia o comando Clear Display |
| `S_SET_L1` | Posiciona o cursor na linha 1 |
| `S_WRITE_L1` | Escreve 16 caracteres na linha 1 |
| `S_SET_L2` | Posiciona o cursor na linha 2 |
| `S_WRITE_L2` | Escreve 16 caracteres na linha 2 |
| `S_PULSE_E` / `S_WAIT` | Pulso de Enable e espera (~2 ms por caractere ou comando) |
| `S_DONE` | Escrita concluída |

### lcd_init_hd44780.v — Inicialização do LCD
Sequência obrigatória do HD44780: espera de energização (~50 ms), triplo wake-up (`0x38`),
configuração de 8 bits e 2 linhas, display ligado, limpeza e modo de entrada. Ao concluir,
sinaliza `done` para o `module_lcd` assumir o controle. A inicialização roda sozinha logo depois
da gravação, sem depender dos botões.

---

## Instruções

### Tabela de opcodes

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

Todos os formatos usam os 18 switches (`SW[17:0]`). O opcode fica sempre em `SW[17:15]` e o
registrador de destino em `SW[14:11]`. Bits não citados em um formato são ignorados.

### Tipo 1 — Reg × Reg (ADD, SUB)

```
SW: [17:15] Opcode | [14:11] Dest | [10:7] Src1 | [6:3] Src2 | [2:0] ignorado
```

- `ADD D, S1, S2`: D = S1 + S2
- `SUB D, S1, S2`: D = S1 − S2

Exemplo — `ADD R6, R7, R8`:
```
SW = 001_0110_0111_1000_000
```

### Tipo 2 — Reg × Imediato (ADDI, SUBI, MUL)

```
SW: [17:15] Opcode | [14:11] Dest | [10:7] Src1 | [6] Sinal | [5:0] Módulo
```

- `ADDI D, S1, Imm`: D = S1 + Imm
- `SUBI D, S1, Imm`: D = S1 − Imm
- `MUL  D, S1, Imm`: D = S1 × Imm

O imediato é **sinal + módulo**: o bit 6 em 1 indica número negativo, e o módulo vai de 0 a 63
(valores de −63 a +63). Exemplo: `-1` é `1_000001`.

Exemplo — `ADDI R2, R1, 5`:
```
SW = 010_0010_0001_0_000101
```

### Tipo 3 — Carga (LOAD)

```
SW: [17:15] Opcode | [14:11] Dest | [10:7] ignorado | [6] Sinal | [5:0] Módulo
```

- `LOAD D, Imm`: D = Imm (sinal + módulo, como no tipo 2)

Exemplos:
```
LOAD R1, 10   →  SW = 000_0001_0000_0_001010
LOAD R7, -10  →  SW = 000_0111_0000_1_001010
```

### Tipo Especial (CLEAR, DISPLAY)

```
SW: [17:15] Opcode | [14:11] Registrador (somente DISPLAY) | demais bits ignorados
```

- `CLEAR`: zera os 16 registradores. O display mostra só o nome da operação.
- `DISPLAY R`: mostra o valor atual do registrador R.

Exemplos:
```
CLEAR       →  SW = 110_0000_0000_0_000000
DISPLAY R2  →  SW = 111_0010_0000_0_000000
```

---

## LCD

O display tem duas linhas de 16 caracteres:

```
ADD    [0011]
        +00025
```

| Posição | Conteúdo |
|---------|----------|
| Linha 1, esquerda | Nome da operação: `LOAD`, `ADD `, `ADDI`, `SUB `, `SUBI`, `MUL `, `CLR `, `DPL ` |
| Linha 1, direita | Registrador de destino em binário, entre colchetes: `[0011]` |
| Linha 2, direita | Sinal e valor decimal com 5 dígitos: `+00025` ou `-00010` |

- No `CLEAR`, só o nome da operação é exibido.
- No `DISPLAY`, o registrador mostrado é o selecionado nos switches.
- Ao ligar, o display mostra o modelo inicial (`----   [----]` e `+00000`). Ao desligar, fica vazio.

### Exemplos de teste

Partindo do sistema recém-ligado:

| Instrução | Switches | Linha 1 | Linha 2 |
|-----------|----------|---------|---------|
| `LOAD R1, 10` | `000_0001_0000_0_001010` | `LOAD   [0001]` | `+00010` |
| `ADDI R2, R1, 5` | `010_0010_0001_0_000101` | `ADDI   [0010]` | `+00015` |
| `ADD R3, R1, R2` | `001_0011_0001_0010_000` | `ADD    [0011]` | `+00025` |
| `SUB R4, R3, R1` | `011_0100_0011_0001_000` | `SUB    [0100]` | `+00015` |
| `MUL R6, R1, 3` | `101_0110_0001_0_000011` | `MUL    [0110]` | `+00030` |
| `LOAD R7, -10` | `000_0111_0000_1_001010` | `LOAD   [0111]` | `-00010` |
| `DISPLAY R2` | `111_0010_0000_0_000000` | `DPL    [0010]` | `+00015` |
| `CLEAR` | `110_0000_0000_0_000000` | `CLR` | (vazio) |

---

## Pinos principais (DE2-115)

| Sinal | Pino |
|-------|------|
| `clk` (CLOCK_50) | `PIN_Y2` |
| `btn_clear` (KEY[0], liga/desliga) | `PIN_M23` |
| `btn_send` (KEY[1], enviar) | `PIN_M21` |
| `lcd_on` (LCD_ON) | `PIN_L5` |

Os demais pinos (switches, dados, RS, RW e EN do LCD) estão em `module_mini_cpu.qsf`.
O sinal `LCD_BLON` não é usado, pois o LCD da DE2-115 não tem backlight.

---

## Especificações

| Item | Especificação |
|------|---------------|
| Placa | DE2-115 (Terasic) |
| FPGA | Cyclone IV — EP4CE115F29C7 |
| Clock | 50 MHz |
| Ferramenta | Quartus Prime Lite 21.1 |
| Linguagem | Verilog HDL |
| Registradores | 16 × 16 bits (com sinal) |
| Display | LCD HD44780 2×16 |
