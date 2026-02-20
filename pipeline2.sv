

module pipeline2 #(
    parameter int PIPELINE_STAGES = 2,
    parameter WIDTH = 32
)(
    input wire clk,rst,
    input wire valid_in,
    input wire [2:0] func3,
    input wire [WIDTH-1:0] rs1,rs2,
    input wire [4:0] rd_tag_in,

    output logic valid_out,
    output logic [WIDTH-1:0] result_out,
    output logic [4:0] rd_tag_out,
    output logic busy

);

    typedef enum logic [1:0] {IDLE,CALC,DONE} state_t;
    state_t state;

    logic [2*WIDTH-1:0] accumulator;
    logic [WIDTH:0] op_a,op_b;
    logic [3:0] count;

    logic neg_result; // ??

    logic [2:0] stored_func3;
    logic [4:0] stored_tag;

    logic is_rs1_signed, is_rs2_signed; //Sign Handling

    logic [WIDTH-1:0] pipe_data [PIPELINE_STAGES-1:0]; //Pipeline Handling
    logic [PIPELINE_STAGES-1:0] pipe_valid;

    always_comb begin
        case (func3)
            3'b001:begin    //MULH
                is_rs1_signed = 1;
                is_rs2_signed = 1;
            end
            3'b011:begin    //MULHsU
                is_rs1_signed = 1;
                is_rs2_signed = 0;
            end
            default:begin   //MUL , MULHU
                is_rs1_signed = 1;
                is_rs2_signed = 1;
            end
        endcase
    end
    
    logic [2*WIDTH-1:0] result_comb;
    always_comb begin
        result_comb = op_a*op_b;
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            state <= IDLE;
            valid_out <= 0;
            busy <= 0;
            accumulator <= 0;
            count <= 0;
            rd_tag_out <= 0;
        end else begin
            case(state)
                IDLE:begin
                    valid_out <= 0;
                    if(valid_in)begin
                        state <= CALC;
                        busy <= 1;
                        stored_tag <= rd_tag_in;
                        stored_func3 <= func3;
                        count <= 0;
                        accumulator <= 0;

                        op_a <= (is_rs1_signed && rs1[31]) ? -rs1: rs1;
                        op_b <= (is_rs2_signed && rs2[31]) ? -rs2: rs2;

                        neg_result <= (is_rs1_signed && rs1[31])^ (is_rs2_signed && rs2[31]);
                    end
                end

                CALC: begin
                    if (count == 8)
                        state <= DONE;
                    else begin
                        pipe_data[0] <= result_comb;    //done for  retiming
                        pipe_valid[0] <= valid_in;      //the design compiler will
                                                        //automatically move the 
                                                        //computation here                                           
                        
                        for(int i = 1;i<PIPELINE_STAGES;i++)begin
                            pipe_data[i] <= pipe_data[i-1];
                            pipe_valid[i] <= pipe_valid[i-1];
                        end

                    end
                end 

                DONE: begin
                    state <= IDLE;
                    busy <= 0;
                    valid_out <= 1;
                    rd_tag_out <= stored_tag;

                    accumulator = neg_result ? -pipe_valid[PIPELINE_STAGES-1]:pipe_valid[PIPELINE_STAGES-1];
                    if(stored_func3 == 3'b000)
                        result_out <= accumulator[31:0];
                    else
                        result_out <= accumulator[63:32];

                end
            endcase
        end
    end


    /*
    logic [WIDTH-1:0] pipe_data [PIPELINE_STAGES-1:0];
    logic [PIPELINE_STAGES-1:0] pipe_valid;

    always_ff @(posedge clk or posedege rst)begin
        if(rst)begin
            for(int i = 0;i< PIPELINE_STAGES;i++)begin
                pipe_data[i] <= '0;
                pipe_valid[i] <= 1'b0;
            end
        end
        else begin
            pipe_data[0] <= result_comb;    //done for  retiming
            pipe_valid[0] <= valid_in;      //the design compiler will
                                            //automatically move the 
                                            //computation here                                           
            for(int i = 1;i<PIPELINE_STAGES;i++)begin
                pipe_data[i] <= pipe_data[i-1];
                pipe_valid[i] <= pipe_valid[i-1];
            end
        end
    end
    */
endmodule