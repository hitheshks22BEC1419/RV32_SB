
module rvcore_tb;
    reg clk;
    reg reset;
    reg [31:0] mem_rdata;
    reg mem_rbusy, mem_wbusy;

    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wmask;

    reg sobel_busy;
    wire sobel_enable, sobel_in_addr, sobel_out_addr;

    
    rvcore_sv rvcore(
        .clk(clk),
        .mem_addr(mem_addr),  // address bus
        .mem_wdata(mem_wdata), // data to be written
        .mem_wmask(mem_wmask), // write mask for the 4 bytes of each word
        .mem_rdata(mem_rdata), // input lines for both data and instr
        .mem_rstrb(mem_rstrb), // active to initiate memory read (used by IO)
        .mem_rbusy(mem_rbusy), // asserted if memory is busy reading value
        .mem_wbusy(mem_wbusy), // asserted if memory is busy writing value
        .reset(reset),      // set to 0 to reset the processor

        .sobel_busy(sobel_busy),
        .sobel_enable(sobel_enable),

        .sobel_in_addr(sobel_in_addr), 
        .sobel_out_addr(sobel_out_addr));

     
    /*
    module rvcore_verilog(
        input          clk,

        output [31:0] mem_addr,  // address bus
        output [31:0] mem_wdata, // data to be written
        output  [3:0] mem_wmask, // write mask for the 4 bytes of each word
        input  [31:0] mem_rdata, // input lines for both data and instr
        output        mem_rstrb, // active to initiate memory read (used by IO)
        input         mem_rbusy, // asserted if memory is busy reading value
        input         mem_wbusy, // asserted if memory is busy writing value
        input         reset,      // set to 0 to reset the processor

        //hks start
            input               sobel_busy,
            output  reg         sobel_enable,

            output  reg [31:0]  sobel_in_addr, sobel_out_addr
            //output  reg [15:0]  sobel_img_height, sobel_img_width
        ///hks end
        );
    */

    reg [31:0]instruct [0:4];


    initial begin 
        clk = 0;
        
        mem_rbusy = 0;
        mem_wbusy = 0;
        sobel_busy = 0;
        //load first data into CPU Reg then do the stuff
        instruct[0] = 32'b0000000_00000_00000_010_00011_0000011;
        instruct[1] = 32'b0000000_00010_00000_000_00001_0010011; //loading reg1 with val 2
        instruct[2] = 32'b0000000_00011_00000_000_00010_0010011; //loading reg2 with val 3
        instruct[3] = 32'b0000000_00010_00001_000_00011_0110011; //loading reg3 = reg1+reg2 ; 5
//        mem_rdata = instruct[0];
//        mem_wbusy = 1;
//        #16;
//        mem_wbusy = 0;
        mem_rdata = instruct[1];
        #16;
        mem_rdata = instruct[2];
        #16;
        mem_rdata = instruct[3];
        #16;
        #16;
        $stop;
    end
    always #2 clk = ~clk;

    always@(rvcore.registerFile)begin
        $display("%d %d %d %d",rvcore.registerFile[0],rvcore.registerFile[1],rvcore.registerFile[2],rvcore.registerFile[3]);
        $display("%d",rvcore.state);
    end
    

    
endmodule
