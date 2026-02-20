
module pipeline1(
    input wire clk,rst,
    
    //control interface
    input wire valid_in,
    input wire [3:0] op,        //op[3] decides arithmetic or not(shift right)
    input wire [4:0] rd_tag_in,

    //data interface
    input wire [31:0] rs1_data,
    input wire [31:0] rs2_data,

    //output interface
    output logic valid_out,
    output logic [4:0] rd_tag_out,
    output logic [31:0] result_out

);
    logic is_sra, is_leftshift;
    logic [4:0] shift_amt;

    assign is_sra = op[3];
    assign is_leftshift = ~(op[2]);
    assign shift_amt = rs2_data[4:0];

    //
    // Barrel Shifter - we reverse incase of leftshift
    //

    logic [31:0] stage1,stage2,stage3,stage4,stage5;
    logic fill_bit;
    
    assign fill_bit = is_sra ? rs1_data[31]:1'b0;
    
    always_comb begin
        logic [31:0] shift_in;
        if(is_leftshift) begin
            for(int i = 0;i<32;i++)
                shift_in[i] = rs1_data[31-i];
        end
        else begin
            shift_in = rs1_data;
        end

        //stage 1 - shift by 16
        if(shift_amt[4])
            stage1 = {{16{fill_bit}},shift_in[31:16]};
        else
            stage1 = shift_in;
        
        if(shift_amt[3])
            stage2 = {{8{fill_bit}},stage1[31:8]};
        else
            stage2 = stage1;
        
        if(shift_amt[2])
            stage3 = {{4{fill_bit}},stage2[31:4]};
        else
            stage3 = stage2;
        
        if(shift_amt[1])
            stage4 = {{2{fill_bit}},stage3[31:2]};
        else
            stage4 = stage3;
        
        if(shift_amt[0])
            stage5 = {{fill_bit},stage4[31:1]};
        else
            stage5 = stage4;

    end

    logic [31:0] shift_final;

    always_comb begin
        if(is_leftshift)begin
            for(int i = 0;i <32;i++)
                shift_final[i] = stage5[31-i];
        end
        else begin
            shift_final = stage5;
        end
    end


    //
    // Boolean Logic Unit
    //
    logic [31:0] logic_final;

    always_comb begin
        case(op[2:0])
            3'd4: logic_final = rs1_data^rs2_data;
            3'd6: logic_final = rs1_data|rs2_data;
            3'd7: logic_final = rs1_data&rs2_data;
            default: logic_final = 32'd0;
        endcase
    end

    //
    // Final Mux
    //
    logic [31:0] final_out;
    
    always_comb begin
        if(op[2:0] == 3'd1 || op[2:0] == 3'd5)
            final_out = shift_final;
        else
            final_out = logic_final;
    end

    //
    //  Reset and pipeline register
    //

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            valid_out <= 1'b0;
            result_out <= 32'b0;
            rd_tag_out <= 5'b0;
        end
        else begin
            valid_out <= valid_in;
            result_out <= final_out;
            rd_tag_out <= rd_tag_in;
        end
    end

endmodule