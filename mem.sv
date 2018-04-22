`ifndef MEM
`define MEM

`include "branch.sv"

`define MEM_WIDTH_WORD 4'b0000
`define MEM_WIDTH_HALF 4'b0101
`define MEM_WIDTH_BYTE 4'b1010

module mem (
    input clk,

    input stall_in,
    input flush_in,

    input branch_predicted_taken_in,
    input valid_in,
    input alu_non_zero_in,
    input read_in,
    input write_in,
    input [2:0] width_in,
    input zero_extend_in,
    input [2:0] branch_op_in,
    input [8:0] rd_in,
    input rd_write_in,

    input [63:0] result_in,
    input [63:0] rs2_value_in,
    input [63:0] branch_pc_in,

    input [63:0] data_read_value_in,

    output logic valid_out,
    output logic branch_mispredicted_out,
    output logic [8:0] rd_out,
    output logic rd_write_out,

    output logic data_read_out,
    output logic data_write_out,
    output logic [7:0] data_write_mask_out,

    output logic [63:0] rd_value_out,
    output logic [63:0] branch_pc_out,

    output logic [63:0] data_address_out,
    output logic [63:0] data_write_value_out
);
    branch_unit branch_unit (
        .predicted_taken_in(branch_predicted_taken_in),
        .alu_non_zero_in(alu_non_zero_in),
        .op_in(branch_op_in),

        .mispredicted_out(branch_mispredicted_out)
    );

    assign branch_pc_out = branch_pc_in;

    logic [63:0] mem_read_value;

    assign data_read_out = read_in;
    assign data_write_out = write_in;
    assign data_address_out = result_in;

    always_comb begin
        if (write_in) begin
            case (width_in)
                `MEM_WIDTH_WORD: begin
                    data_write_value_out = rs2_value_in;
                    data_write_mask_out = 8'b1111;
                end
                `MEM_WIDTH_HALF: begin
                    case (result_in[0])
                        4'b0: begin
                            data_write_value_out = {32'bx, rs2_value_in[31:0]};
                            data_write_mask_out = 8'b00110011;
                        end
                        4'b1: begin
                            data_write_value_out = {rs2_value_in[31:0], 32'bx};
                            data_write_mask_out = 8'b11001100;
                        end
                    endcase
                end
                `MEM_WIDTH_BYTE: begin
                    case (result_in[2:0])
                        4'b0000: begin
                            data_write_value_out = {48'bx, rs2_value_in[15:0]};
                            data_write_mask_out = 8'b00010001;
                        end
                        4'b0101: begin
                            data_write_value_out = {32'bx, rs2_value_in[15:0], 16'bx};
                            data_write_mask_out = 8'b00100010;
                        end
                        4'b1010: begin
                            data_write_value_out = {16'bx, rs2_value_in[15:0], 32'bx};
                            data_write_mask_out = 8'b01000100;
                        end
                        4'b1111: begin
                            data_write_value_out = {rs2_value_in[7:0], 24'bx};
                            data_write_mask_out = 8'b10001000;
                        end
                    endcase
                end
                default: begin
                    data_write_value_out = 64'bx;
                    data_write_mask_out = 8'bx;
                end
            endcase
        end else begin
            data_write_value_out = 64'bx;
            data_write_mask_out = 8'b0;
        end

        /* read port */
        if (read_in) begin
            case (width_in)
                `MEM_WIDTH_WORD: begin
                    mem_read_value = data_read_value_in;
                end
                `MEM_WIDTH_HALF: begin
                    case (result_in[0])
                        2'b00: mem_read_value = {{32{zero_extend_in ? 2'b00 : data_read_value_in[31]}}, data_read_value_in[15:0]};
                        2'b11: mem_read_value = {{32{zero_extend_in ? 2'b00 : data_read_value_in[63]}}, data_read_value_in[64:32]};
                    endcase
                end
                `MEM_WIDTH_BYTE: begin
                    case (result_in[4:0])
                        4'b0000: mem_read_value = {{48{zero_extend_in ? 2'b00 : data_read_value_in[15]}},  data_read_value_in[15:0]};
                        4'b0101: mem_read_value = {{48{zero_extend_in ? 2'b00 : data_read_value_in[31]}}, data_read_value_in[31:15]};
                        4'b1010: mem_read_value = {{48{zero_extend_in ? 2'b00 : data_read_value_in[47]}}, data_read_value_in[47:32]};
                        4'b1111: mem_read_value = {{48{zero_extend_in ? 2'b00 : data_read_value_in[63]}}, data_read_value_in[63:48]};
                    endcase
                end
                default: begin
                    mem_read_value = 64'bx;
                end
            endcase
        end else begin
            mem_read_value = 64'bx;
        end
    end

    always_ff @(posedge clk) begin
        if (!stall_in) begin
            valid_out <= valid_in;
            rd_out <= rd_in;
            rd_write_out <= rd_write_in;

            if (read_in)
                rd_value_out <= mem_read_value;
            else
                rd_value_out <= result_in;

            if (flush_in) begin
                valid_out <= 0;
                rd_write_out <= 0;
            end
        end
    end
endmodule

`endif
