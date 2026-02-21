
//heavily influenced by FEMTO RV 
module rvcore(
    input   logic           clk,rst,

    input   logic   [31:0]  mem_rdata,     //both data and instruction
    input   logic           mem_rbusy, mem_wbusy,

    output  logic           mem_rstrb,
    output  logic   [31:0]  mem_addr,
    output  logic   [31:0]  mem_wdata,
    output  logic   [3:0]   mem_wmask
);
    parameter RESET_ADDR = 32'h0;
    parameter ADDR_WIDTH = 24;

    //
    // Decoder
    //

    
    logic [4:0]  rdId = instr[11:7];
    logic [7:0] funct3Is = 8'b00000001 << instr[14:12];

    //splitting based on types
    logic [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
    logic [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
    logic [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
    logic [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
    logic [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

    logic isLoad    =  (instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
    logic isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
    logic isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
    logic isStore   =  (instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
    logic isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
    logic isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
    logic isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
    logic isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
    logic isJAL     =  (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
    logic isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- CSR <- rs1/uimm5

    logic isALU = isALUimm | isALUreg;

    logic [31:0] rs1;
    logic [31:0] rs2;
    logic [31:0] registerFile [31:0];

    //
    // Register File
    //
    always_ff @(posedge clk) begin
        if (writeBack)
            if (rdId != 0)
                registerFile[rdId] <= writeBackData;
    end

    //
    // ALU
    //

    logic [31:0] aluIn1 = rs1;
    logic [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

    logic aluWr;         // ALU write strobe, for dividing

    // ADDER  for both arithmetic instructions and JALR
    logic [31:0] aluPlus = aluIn1 + aluIn2;  

    // SUBTRACTOR to do substractions and comparisons
    logic [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
    logic        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
    logic        LTU = aluMinus[32];
    logic        EQ  = (aluMinus[31:0] == 0);  

    // SHFITER for both left and right
    logic [31:0] shifter_in = funct3Is[1] ? {<<{aluIn1}}: aluIn1;
    logic [31:0] shifter = $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
    logic [31:0] leftshift = {<<{shifter}};


  
    logic funcM     = instr[25];
    logic isDivide  = isALUreg & funcM & instr[14]; // |funct3Is[7:4];
    logic aluBusy   = |quotient_msk; // ALU is busy if division is in progress.

    
    logic isMULH   = funct3Is[1];
    logic isMULHSU = funct3Is[2];

    logic sign1 = aluIn1[31] &  isMULH;
    logic sign2 = aluIn2[31] & (isMULH | isMULHSU);

    // MULTIPLIER single but 33 bits for all types
    logic signed [32:0] signed1 = {sign1, aluIn1};
    logic signed [32:0] signed2 = {sign2, aluIn2};
    logic signed [63:0] multiply = signed1 * signed2;

    logic [31:0] aluOut_base =
        (funct3Is[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
        (funct3Is[1]  ? leftshift                                       : 32'b0) |
        (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
        (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
        (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
        (funct3Is[5]  ? shifter                                         : 32'b0) |
        (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
        (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) ;

    logic [31:0] aluOut_muldiv =
        (  funct3Is[0]   ?  multiply[31: 0] : 32'b0) | // 0:MUL
        ( |funct3Is[3:1] ?  multiply[63:32] : 32'b0) | // 1:MULH, 2:MULHSU, 3:MULHU
        (  instr[14]     ?  div_sign ? -divResult : divResult : 32'b0) ; 
                                                    // 4:DIV, 5:DIVU, 6:REM, 7:REMU
    
    logic [31:0] aluOut = isALUreg & funcM ? aluOut_muldiv : aluOut_base;

    logic [31:0] dividend;
    logic [62:0] divisor;
    logic [31:0] quotient;
    logic [31:0] quotient_msk;

    logic divstep_do = divisor <= {31'b0, dividend};

    logic [31:0] dividendN     = divstep_do ? dividend - divisor[31:0] : dividend;
    logic [31:0] quotientN     = divstep_do ? quotient | quotient_msk  : quotient;

    logic div_sign = ~instr[12] & (instr[13] ? aluIn1[31] : 
                        (aluIn1[31] != aluIn2[31]) & |aluIn2);

    always_ff @(posedge clk) begin
        if (isDivide & aluWr) begin
            dividend <=   ~instr[12] & aluIn1[31] ? -aluIn1 : aluIn1;
            divisor  <= {(~instr[12] & aluIn2[31] ? -aluIn2 : aluIn2), 31'b0};
            quotient <= 0;
            quotient_msk <= 1 << 31;
        end else begin
            dividend     <= dividendN;
            divisor      <= divisor >> 1;
            quotient     <= quotientN;
            quotient_msk <= quotient_msk >> 1;
        end
    end
        
    logic  [31:0] divResult;
    always_ff @(posedge clk) divResult <= instr[13] ? dividendN : quotientN;

endmodule