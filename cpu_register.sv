`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.01.2026 14:45:05
// Design Name: 
// Module Name: cpu_register
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cpu_register(
    input wire clk,rst,
    input wire [4:0] a_rs1,a_rs2, b_rs1,b_rs2,
    input wire [4:0] a_rd,b_rd,
    input wire [31:0] a_wd, b_wd,
    input wire a_we, b_we,

    output logic [31:0] a_data1,a_data2, b_data1,b_data2
    

    );
    
    logic [31:0] bank [0:31];
    
    int i;

    //write operations
    always_ff@(posedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0;i <32;i = i+1)begin
                bank[i] <= 32'b0;
            end
        end
        else begin
 
            if(a_we && a_rd != 0)
                bank[a_rd] <= a_wd;
            if(b_we && b_rd != 0)
                bank[b_rd] <= b_wd; //preference given to portB incase of overlap

            bank[0] <= 32'b0;

        end

    end
    

    //read operations

    always_comb begin
        a_data1 = bank[a_rs1];
        a_data2 = bank[a_rs2];
    
        b_data1 = bank[b_rs1];
        b_data2 = bank[b_rs2];
    end

//
//verification
//

`ifndef SYNTHESIS
    //WAW
    property no_waw;
        @(posedge clk) disable iff(rst)
        !(a_we && b_we && (a_rd == b_rd));
    endproperty
    assert property(no_waw)
        else $fatal("WAW hazard time = %t a_rd = %0d b_rd = %0d ",$time,a_rd,b_rd);

    //raw
    property no_raw;
        @(posedge clk) disable iff(rst)
        !(
     (a_we && ((a_rs1==a_rd)||(a_rs2==a_rd)||(b_rs1==a_rd)||(b_rs2==a_rd))) ||
     (b_we && ((a_rs1==b_rd)||(a_rs2==b_rd)||(b_rs1==b_rd)||(b_rs2==b_rd))) );
    endproperty
    assert property(no_raw)
        else $fatal("raw hazard time = %t ",$time);

    //X0
    property x0;
        @(posedge clk) disable iff(rst)
        bank[0] == 32'b0;
    endproperty
    assert property(x0)
        else $fatal("X0 error time = %t",$time);


`endif

endmodule
