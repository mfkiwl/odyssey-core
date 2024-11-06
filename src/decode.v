`include "config.v"

// Processor decode unit
module decode #(
    parameter DATA_WIDTH = 32,
    parameter ALU_CONTROL_BITS = 3,
	parameter LOG2_REGISTERS = 5,
    parameter BYTE_DATA_WIDTH = 4
)
(
    // Decode unit interface
    input  wire [DATA_WIDTH-1:0] inst,
    input  wire compute_req,
    output wire compute_valid,

    // LSU interface
    output wire mem_req,
    output wire mem_we,
    input  wire mem_valid,
    output wire [BYTE_DATA_WIDTH-1:0] mem_byte_enable,

    // Register file interface
    output wire [LOG2_REGISTERS-1:0] addr_rd,
    output wire [LOG2_REGISTERS-1:0] addr_rs1,
    output wire [LOG2_REGISTERS-1:0] addr_rs2,

    output wire [1:0] rd_select,
    output wire rf_enable,
    output wire [DATA_WIDTH-1:0] direct_store, 

    // ALU interface
    input  wire less_comp,
    input  wire equal_comp,

    output wire [ALU_CONTROL_BITS-1:0] alu_control,
    output wire signed_flag,
    output wire [DATA_WIDTH-1:0] imm,
    output wire select_imm,
    output wire select_pc,
    
    // Global control
    input  wire clk,
    input  wire rst
);

reg [ALU_CONTROL_BITS-1:0] alu_control_reg;
reg select_imm_reg;
reg [DATA_WIDTH-1:0] direct_store_reg;
reg signed_flag_reg;
reg [BYTE_DATA_WIDTH-1:0] mem_byte_enable_reg;
reg rf_enable_reg;
reg mem_req_reg;
reg compute_valid_reg;
reg compute_valid_reg_new;
reg mem_we_reg;

reg [6:0] opcode;
reg [2:0] funct3;
reg [6:0] funct7;

reg [4:0] rd, rs1, rs2;

reg [11:0] imm_s;
reg [11:0] imm_i;

reg [11:0] pc_jump;

reg select_pc_reg;
reg [1:0] rd_select_reg;

// Internal assignments
assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];

assign rd = inst[11:7];
assign rs1 = inst[19:15];
assign rs2 = inst[24:20];

assign imm_s = {inst[31:25], inst[11:7]};
assign imm_i = {inst[31:20]};

// External assignments
assign addr_rd = rd;
assign addr_rs1 = rs1;
assign addr_rs2 = rs2;

// Sign extension of immediate value
assign imm = (imm_i[11]) ? {20'hFFFFF, imm_i} : {20'h00000, imm_i};

assign alu_control = alu_control_reg;
assign select_imm = select_imm_reg;
assign signed_flag = signed_flag_reg;
assign mem_byte_enable = mem_byte_enable_reg;

assign select_pc = select_pc_reg;
assign rd_select = rd_select_reg;
assign rf_enable = rf_enable_reg;

assign mem_req = mem_req_reg;
assign compute_valid = compute_valid_reg;

assign mem_we = mem_we_reg;

assign direct_store = direct_store_reg;

always @(opcode, funct3, funct7, imm_i, imm_s, less_comp) begin
    // TODO: Fix for pc increase
    select_pc_reg <= 0;
    rd_select_reg <= 0;
    select_imm_reg <= 1'b0;

    // Calculate instruction
    case (opcode)
        // R instructions
        7'b0110011: begin
            case (funct3)
                // ADD and SUB
                3'b000: begin
                    case (funct7)
                        // ADD
                        7'b0000000: begin
                            alu_control_reg <= ADD_SUB_OP;
                        end

                        // SUB
                        7'b0100000: begin
                            alu_control_reg <= ADD_SUB_OP;
                        end

                        // Default
                        default: begin
                            alu_control_reg <= ADD_SUB_OP;
                        end
                    endcase
                end

                // SLL - Shift Left Logical
                3'b001: begin
                    alu_control_reg <= LLS_OP;
                end
                
                // XOR
                3'b100: begin
                    alu_control_reg <= XOR_OP;
                end
                
                // SRL and SRA
                3'b101: begin
                    case (funct7)
                        // SRL - Shift Right Logical
                        7'b0000000: begin
                            alu_control_reg <= RLS_OP;
                        end

                        // SRA - Shift Right Arithmetic
                        7'b0100000: begin
                            // TODO: Fix
                            alu_control_reg <= RLS_OP;
                        end

                        // Default
                        default: begin
                            alu_control_reg <= RLS_OP;
                        end
                    endcase
                end
                
                // OR
                3'b110: begin
                    alu_control_reg <= OR_OP;
                end
                
                // AND
                3'b111: begin
                    alu_control_reg <= AND_OP;
                end

                // SLT
                3'b010: begin
                    direct_store_reg <= less_comp ? 1 : 0;
                    rd_select_reg <= 2'b01;
                end
                
                // SLTU
                3'b011: begin
                    direct_store_reg <= less_comp ? 1 : 0;
                    rd_select_reg <= 2'b01;
                end
                
                default: begin
                    alu_control_reg <= ADD_SUB_OP;
                end
            endcase
        end

        // I instructions - Execute
        7'b0010011: begin
            select_imm_reg <= 1'b1;

            case (funct3)
                // ADDI
                3'b000: begin
                    alu_control_reg <= ADD_SUB_OP;
                end

                // XORI
                3'b100: begin
                    alu_control_reg <= XOR_OP;
                end

                // OR
                3'b110: begin
                    alu_control_reg <= OR_OP;
                end

                // AND
                3'b111: begin
                    alu_control_reg <= AND_OP;
                end
                
                // Shift Left Immediate
                3'b001: begin
                    case (imm_i[11:5])
                        // SLLI
                        7'h00: begin
                            alu_control_reg <= LLS_OP;
                        end
                        // Default
                        default: begin
                            alu_control_reg <= LLS_OP;
                        end
                    endcase
                end
                
                // Shift Right Immediate
                3'b101: begin
                    case (imm_i[11:5])
                        // SRLI
                        7'h00: begin
                            alu_control_reg <= RLS_OP;
                        end

                        // SRAI
                        // TODO: Fix difference with MSB extend
                        7'h20: begin
                            alu_control_reg <= RLS_OP;
                        end

                        // Default
                        default: begin
                            alu_control_reg <= RLS_OP;
                        end
                    endcase
                end

                // SLTI
                3'b010: begin
                    direct_store_reg <= less_comp ? 1 : 0;

                    rd_select_reg <= 2'b01;
                end

                // SLTIU
                3'b011: begin
                    signed_flag_reg <= 1'b0;
                    
                    direct_store_reg <= less_comp ? 1 : 0;
                    
                    rd_select_reg <= 2'b01;
                end

                // Default
                default: begin
                    alu_control_reg <= ADD_SUB_OP;
                end
            endcase
        end

        // I instructions - Load
        7'b0000011: begin
            select_imm_reg <= 1'b1;
            alu_control_reg <= ADD_SUB_OP;
            mem_we_reg <= 1'b0;
            rd_select_reg <= 2'b10;

            case (funct3)
                // Byte
                3'b000: begin
                    mem_byte_enable_reg <= 4'b0001;
                end

                // Half
                3'b001: begin
                    mem_byte_enable_reg <= 4'b0011;
                end

                // Word
                3'b010: begin
                    mem_byte_enable_reg <= 4'b1111;
                end

                // TODO: Fix zero extend - Byte
                3'b100: begin
                    mem_byte_enable_reg <= 4'b0001;
                end

                // TODO: Fix zero extend - Half
                3'b101: begin
                    mem_byte_enable_reg <= 4'b0011;
                end

                // Default
                default: begin
                    mem_byte_enable_reg <= 4'b0000;
                end
            endcase
        end

        // S instructions
        7'b0100011: begin
            case (funct3)
                // SB - Store Byte
                3'b000: begin
                    mem_byte_enable_reg <= 4'b0001;

                    alu_control_reg <= ADD_SUB_OP;
                end
                // SH - Store Half
                3'b001: begin
                    mem_byte_enable_reg <= 4'b0011;

                    alu_control_reg <= ADD_SUB_OP;
                end
                // SW - Store Word
                3'b010: begin
                    mem_byte_enable_reg <= 4'b1111;

                    alu_control_reg <= ADD_SUB_OP;
                end

                // Default
                default: begin
                    mem_byte_enable_reg <= 4'b0000;
                    
                    alu_control_reg <= ADD_SUB_OP;
                end
            endcase
        end
        
        // B instructions
        7'b1100011: begin
            // case (funct3)
            // TODO: Logic
            // First compares values rs1 and rs2 and afterwards
            // increases the value of the PC
            // endcase
        end
        
    // Default
    default: begin
        alu_control_reg <= ADD_SUB_OP;
    end
    
    endcase
end

// State machine variables
localparam S_WAIT = 0;
localparam S_COMPUTE = 1;
localparam S_COMPUTE_VALID = 2;
localparam S_MEM_REQ = 3;
localparam S_MEM_VALID = 4;

reg [2:0] c_state, n_state;

// Implementing state transition logic
always @(*) begin
    compute_valid_reg_new = 1'b0;
    mem_req_reg = 1'b0;
    rf_enable_reg = 1'b0;

	case (c_state)
        S_WAIT: begin
            if(compute_req) begin
                n_state = S_COMPUTE;
            end
            else begin
                n_state = S_WAIT;
            end
        end
        S_COMPUTE: begin
            if(~(opcode == 7'b0000011 || opcode == 7'b1100011 || opcode == 7'b1110011)) begin
                rf_enable_reg = 1'b1;
            end

            if(opcode == 7'b0000011 || opcode == 7'b0000011) begin
                n_state = S_MEM_REQ;
            end
            else begin
                n_state = S_COMPUTE_VALID;
            end
        end
        S_COMPUTE_VALID: begin
            compute_valid_reg_new = 1'b1;

            n_state = S_WAIT;

            if(compute_req) begin
                n_state = S_COMPUTE_VALID;
            end
            else begin
                n_state = S_WAIT;
            end
        end
        S_MEM_REQ: begin
            mem_req_reg = 1'b1;

            if(mem_valid) begin
                n_state = S_MEM_VALID;
            end
            else begin
                n_state = S_MEM_REQ;
            end
        end
        S_MEM_VALID: begin
            if(opcode == 7'b0000011) begin
                rf_enable_reg = 1'b1;
            end

            if(mem_valid) begin
                n_state = S_MEM_VALID;
            end
            else begin
                n_state = S_COMPUTE_VALID;
            end
        end
        default: begin
            n_state = S_WAIT;
        end
    endcase
end

// Sequential - FSM logic
always @(posedge clk) begin
    if(rst) begin
		c_state <= S_WAIT;
    end
    else begin
        c_state <= n_state;

        compute_valid_reg <= compute_valid_reg_new;
    end
end

endmodule
