`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/12/12 19:59:57
// Design Name: 
// Module Name: lab11
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
module segment_decoder(  
   input [4:0]y,
   output reg [6:0]x
   );
   always @ *
       case(y[4])
           0:begin
               case(y[3:0])
                   4'b0000: x = 7'b100_0000; //0000_001;   //case can only be used to reg!!
                   4'b0001: x = 7'b111_1001;//1001_111;
                   4'b0010: x = 7'b010_0100;//0010_010;
                   4'b0011: x = 7'b011_0000;//0000_110;//
                   4'b0100: x = 7'b001_1001;//1001_100;
                   4'b0101: x = 7'b001_0010;//0100_100;
                   4'b0110: x = 7'b000_0010;//0100_000;
                   4'b0111: x = 7'b111_1000;//0001_111;
                   4'b1000: x = 7'b000_0000;//0000_000;
                   4'b1001: x = 7'b001_0000;//0000_100;
                   4'b1010: x= 7'b000_1000; //A 000_1000        
                   4'b1011: x= 7'b000_0011; //b 110_0000
                   4'b1100: x= 7'b010_0111; //c 111_0010
                   4'b1101: x= 7'b010_0001; //d 100_0010
                   4'b1110: x= 7'b000_0110;//E  011_0000
                   default: x= 7'b000_1110;//F 011_1000
               endcase
           end
           1: begin
               case(y[3:0])
                    4'b0000:x=7'b010_1111;//r  111_1010
                    4'b0001:x=7'b000_1100;// P
                    4'b0010: x=7'b100_0001; // u
                    4'b0011: x=7'b100_1000;  // n
                    4'b0100: x=7'b100_1111;// I
                    default:;
               endcase
          end
           endcase
endmodule

module lab11( 
    input execute_clock,
    input state_reset,
    input [15:0]swt,
    input Clk100,
    output reg [7:0]an,  //引脚
    output [6:0]digit_x,   //数码管上显示的数字
    output reg [15:0]led,
    output reg [2:0]led16,
    output reg [2:0]led17
    );
    
    //controler部分
    reg signed [15:0]R[7:0];   //Register File
    reg signed [15:0]PC;       //Program Counter 
    reg [15:0]IR;   
    reg signed [15:0]MP;   //自己加的Memory Pointer,用于写指令到memory中
    reg n,z,p;
    
    //memory部分
    reg signed [15:0]memory[127:0];  //为防止空间不够，memory先开 x00--x7F 共 128个地址单元, 地址有八位,但MP有16位，注意MP不要超内存。
    reg [15:0]MAR,MDR;
    
    wire Clk5;
    clk_wiz_0(Clk5,,,Clk100);
    
    //状态
    reg [2:0]state;
    reg [2:0]nextstate;
    parameter S0=3'b000, S1=3'b001,S2=3'b010,S3=3'b011,S4=3'b100,S5=3'b101,S6=3'b110,S7=3'b111;
    //状态说明：
    //从内存中取指令： S0，S1，S2： #S0：PC到MAR,以及PC自增；#S1：memory到MDR  #S2： MDR到IR
    //译码器： S3 :case(IR[15:12])根据不同的opcode执行相应动作
    //返回S0，取下一条指令
    
    integer k;
    initial begin
    PC=16'h0000;
    IR=16'h0000;
    MAR=16'h0000;
    MDR=16'h0000;
    MP=16'h0000;
   
    //所有寄存器初始化
    R[7]=16'hFFFF;
    R[6]=16'h0005;
    for(k=0;k<=5;k=k+1) begin
    R[k]=16'h0000;
    end
    for(k=0;k<=2;k=k+1)begin
        case(k)
            0: memory[0]=16'b0001_001_000_1_00001;
            1: memory[1]=16'b0001_010_000_1_00010;
            2: memory[2]=16'b1100_000_110_000000;  //JMP
        endcase
    end 
    n=1'b1;
    z=1'b1;
    p=1'b1;
   //状态初始化
    state=S1;
    end
    
    //内存初始化
    //initial $readmemb("D:/Vivado_project/lab11new/lab11new.srcs/sources_1/new/test_program.mem",memory,0,6);
    reg output_memory=1'b0;   //为1表示显示的是内存的内容，为0表示输出的是寄存器的内容
    reg output_PC=1'b0;
    reg output_MP=1'b0;
    reg output_run=1'b0;
    reg [7:0]address_memory_show;  //该reg的内容表示：输出在七段数码管上的内存的地址
    reg [4:0]num_reg_show;     //该reg的内容表示：输出在七段数码管上是哪个寄存器
    
    reg signed[15:0]add_temp;
    reg signed[15:0]not_temp;
    reg signed[15:0]SEXT;
    
    //第一个always： 状态转换always
    always @(posedge execute_clock or posedge state_reset)begin
          if(state_reset) state=S1;
          else state=nextstate;
    end
    
    reg signed[15:0]temp_address;   //用来存放中间地址，LDI，STI
    reg signed[15:0]PC_record;
    
    //第二个always： 状态内容
    always @(state) begin   
          case(state)
            //*****************  S0 从内存中取指令 *****************
             S0: begin
                led=S0;
                IR=memory[PC];
                PC_record=PC+16'b1;
                nextstate=S6; 
             end
             //*************** S1 swt直接输入IR
             S1:begin
                led=S1;   //led用于指示工作状态
                IR=swt;
                nextstate=S3;
             end
             //********************** S3: 译码器 **********************
             S3: begin
                led=S3;
                case(IR[15:12])  //前4位为opcode
                 // ####1. OUTPUT####  1101_0xxx_xxxxx_RegisterNum[2:0] 
                 //                or  1101_110x_MemoryAddress[7:0]，
                 //                or 1101_100x_xxxx_xxxx(输出nzp)，1101_101x_xxxx_xxxx(输出PC) 
                 //                or 1101_111_xxxxxxxx ;执行PC
                     4'b1101: begin      
                        if(IR[11]==0) begin  //输出寄存器
                             num_reg_show={1'b0,IR[2:0]};                                                                                                                                              
                             output_memory=1'b0; 
                             output_MP=1'b0;
                             output_PC=1'b0;
                             output_run=1'b0;
                             nextstate=S1;
                        end
                        else begin
                            case(IR[11:9])
                                    3'b110: begin  //输出内存内容                                                                         
                                             address_memory_show=IR[7:0];  //8位地址
                                             output_memory=1'b1;
                                             output_MP=1'b0;
                                             output_PC=1'b0;
                                             output_run=1'b0;
                                             nextstate=S1;
                                    end 
                                    3'b100: begin   //输出nzp
                                            output_memory=1'b0;
                                            output_MP=1'b1;
                                            output_PC=1'b0;
                                            output_run=1'b0;
                                            nextstate=S1;
                                    end
                                    3'b101:begin   //输出PC
                                            output_memory=1'b0;
                                             output_MP=1'b0;
                                             output_PC=1'b1;
                                             output_run=1'b0;
                                             nextstate=S1;
                                    end
                                    3'b111: begin
                                            output_memory=1'b0;
                                            output_MP=1'b0;
                                            output_PC=1'b0;
                                            output_run=1'b1;
                                            nextstate=S0;
                                    end
                                    default:;    
                                endcase
                        end      
                     end  
                     //##### 2.ADD ###### 0001_DR_SR1_xxx_SR2 or 0101_DR_SR1_1_imm5 
                     4'b0001: begin
                            case(IR[5])
                                1'b1:  //立即数模式
                                begin
                                      SEXT={{11{IR[4]}},IR[4:0]};
                                      add_temp=( R[IR[8:6]] + SEXT);
                                end
                                //寄存器模式
                                default: begin
                                    add_temp=(R[IR[8:6]]+R[IR[2:0]]);
                                end
                            endcase
                            R[IR[11:9]]=add_temp;
                            //设置条件寄存器
                            if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                            else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                            else {n,z,p}={1'b1,1'b0,1'b0};
                            
                            nextstate=S1;
                        end
                        
                    //##### 3.AND ###### 0101_DR_SR1_xxx_SR2 or 0101_DR_SR1_1_imm5  
                    4'b0101:begin
                        case(IR[5])
                           //立即数模式
                           1'b1: R[IR[11:9]] = (R[IR[8:6]] &{ {11{IR[4]}} ,IR[4:0]});  //用{{}}进行SEXT
                           //寄存器模式
                           default: R[IR[11:9]]=(R[IR[8:6]] & R[IR[2:0]]);
                       endcase
                       //设置条件寄存器
                       if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                       else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                       else {n,z,p}={1'b1,1'b0,1'b0};
                       
                       nextstate=S1;
                    end
                    
                    // #####4.NOT #### 1001_DR_SR_xxxxxx
                    4'b1001: begin 
                       not_temp=(~ R[IR[8:6]]);  
                       R[IR[11:9]]=not_temp;     
                       nextstate=S1;      
                                
                        //设置条件寄存器
                       if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                       else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                       else {n,z,p}={1'b1,1'b0,1'b0};
   
                    end
                    
                    // ###### 5.BR ##### 0000_nzp_PCOffset[8:0]
                    4'b0000: begin
                        if({n&IR[11],z&IR[10],p&IR[9]})  begin 
                            add_temp=PC+{{7{IR[8]}},IR[8:0]};
                            nextstate=S4;                  
                        end
                        else begin 
                            PC=PC;
                            nextstate=S1;
                        end
                    end
                    
                    //###### 6.JMP  1100_xxx_BaseR[3:0]_xxxxxx   
                    4'b1100:begin 
                        PC=R[IR[8:6]];
                        nextstate=S1;
                    end                    
                    //##### 7.LD  0010_DR[3:0]_PCOffset9
                    4'b0010: begin
                        R[IR[11:9]]=memory[PC+{{7{IR[8]}},IR[8:0]}];
                        
                        if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                        else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                        else {n,z,p}={1'b1,1'b0,1'b0};
                        
                        nextstate=S1;
                    end
                    
                    //###### 8.LDR 0110_DR_BaseR_offset6
                    4'b0110: begin
                        R[IR[11:9]]=memory[R[IR[8:6]]+{{10{IR[5]}},IR[5:0]}];
                                            
                        if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                        else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                        else {n,z,p}={1'b1,1'b0,1'b0};
                        nextstate=S1;
                    end
                    
                    //###### 9 LDI 1010_DR_PCoffset9;  
                     4'b1010: begin
                        temp_address=memory[PC+{{7{IR[8]}},IR[8:0]}];
                        R[IR[11:9]]=memory[temp_address];
                                            
                        if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                        else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                        else {n,z,p}={1'b1,1'b0,1'b0};
                        nextstate=S1;
                    end   
                    
                    //###### 10.LEA 1110_DR_PCoffset9   
                    4'b1110:begin
                        R[IR[11:9]]=PC+{{7{IR[8]}},IR[8:0]};
                        
                         if(R[IR[11:9]]>16'h0000) {n,z,p}={1'b0,1'b0,1'b1};
                         else if (R[IR[11:9]]==16'h0000) {n,z,p}={1'b0, 1'b1,1'b0};
                         else {n,z,p}={1'b1,1'b0,1'b0};
                         nextstate=S1;
                    end
                    //####### 11.ST 0011_SR_PCOffset9    
                    4'b0011: begin
                           memory[PC+{{7{IR[8]}},IR[8:0]}]=R[IR[11:9]];         
                           nextstate=S1; 
                    end
                    //######  12 STR 0111_SR_BaseR_offset6;  
                    4'b0111:begin memory[R[IR[8:6]]+{{10{IR[5]}},IR[5:0]}] = R[IR[11:9]];
                            nextstate=S1;
                    end
                    //######  13.STI 1011_SR_PCOffset9
                    4'b1011:  begin
                           temp_address=memory[PC+{{7{IR[8]}},IR[8:0]}];
                           memory[temp_address]=R[IR[11:9]];
                           nextstate=S1;
                    end
                    //##### 14 HALT
                    4'b1111: begin
                        led=16'hffff;
                        nextstate=S1;
                    end
                    default: begin 
                        num_reg_show=4'b0000;
                        nextstate=S1;
                    end 
                endcase 
            end
             //S4       
             S4: begin  //PC
                    led=S4; 
                    PC=add_temp;
                    nextstate=S1;
             end    
             S6:begin  //S0
                led=S6;
                PC=PC_record;
                //if(PC>PC_record) PC=PC_record;
                nextstate=S3;
             end
             default:nextstate=S1;
            endcase
                          
    end
    
  //第三个always：  输出
   reg [12:0]cnt_show=13'h0;
   reg [4:0]show;
   
   always @(posedge Clk5)begin
        if(cnt_show >= 13'd5999)
            cnt_show    <= 13'h0;
        else
            cnt_show    <= cnt_show + 13'h1;
        case(output_memory)
            0: begin         
                    if(output_MP==1'b1) begin  //输出nzp内容
                          
                           if(cnt_show<=13'd999)begin 
                                  an= 8'b0111_1111;  show=n;//show=IR[15:12];
                              end
                         else if(cnt_show<=13'd1999)begin 
                                  an= 8'b1011_1111;  show=z;//show=IR[11:8];
                              end
                         else if(cnt_show<=13'd2999)begin 
                                  an= 8'b1101_1111; show=p;//show=IR[7:4];
                              end
                         else if(cnt_show<=13'd3999)begin 
                                  an= 8'b1111_1111; //show=IR[3:0];
                              end       
                         else if(cnt_show<=13'd4999)begin 
                                  an= 8'b1111_1111; //show=5'b10100; //I
                              end  
                         else begin 
                                  an= 8'b1111_1111; //show= 5'b10000; //r
                              end    
                    end
                    else if(output_PC==1'b1)begin  //输出PC内容
                           led16=3'b100;
                           led17=3'b100;
                           if(cnt_show<=13'd999)begin 
                                       an= 8'b0111_1111;  show=PC[15:12];
                                   end
                              else if(cnt_show<=13'd1999)begin 
                                       an= 8'b1011_1111;  show=PC[11:7];
                                   end
                              else if(cnt_show<=13'd2999)begin 
                                       an= 8'b1101_1111; show=PC[7:4];
                                   end
                              else if(cnt_show<=13'd3999)begin 
                                       an= 8'b1110_1111; show=PC[3:0];
                                   end       
                              else if(cnt_show<=13'd4999)begin 
                                       an= 8'b1111_1101; show=5'b10001;  //r
                                   end  
                              else begin 
                                       an= 8'b1111_1110; show=5'b01100; //C 
                                   end    
                    end
                    else if(output_run==1'b1)begin  //输出RUN
                               led16=3'b110;
                               led17=3'b110;
                               if(cnt_show<=13'd999)begin 
                                           an= 8'b0111_1111;  show=PC[15:12];
                                       end
                                  else if(cnt_show<=13'd1999)begin 
                                           an= 8'b1011_1111;  show=PC[11:7];
                                       end
                                  else if(cnt_show<=13'd2999)begin 
                                           an= 8'b1101_1111; show=PC[7:4];
                                       end
                                  else if(cnt_show<=13'd3999)begin 
                                           an= 8'b1110_1111; show=PC[3:0];
                                       end       
                                  else if(cnt_show<=13'd4999)begin 
                                           an= 8'b1111_1011; show=5'b10000;  //r
                                       end  
                                  else begin 
                                           an= 8'b1111_1101; show=5'b10010; //U
                                       end    
                    end
                    else begin  //输出寄存器内容
                        led16=3'b010;
                        led17=3'b010;
                        if(cnt_show<=13'd999)begin 
                                 an= 8'b0111_1111;   show=R[num_reg_show][15:12];//
                             end
                        else if(cnt_show<=13'd1999)begin 
                                 an= 8'b1011_1111;   show=R[num_reg_show][11:8];//num_reg_show;
                             end
                        else if(cnt_show<=13'd2999)begin 
                                 an= 8'b1101_1111;  show=R[num_reg_show][7:4];
                             end
                        else if(cnt_show<=13'd3999)begin 
                                 an= 8'b1110_1111;  show=R[num_reg_show][3:0];
                             end       
                        else if(cnt_show<=13'd4999)begin 
                                 an= 8'b1111_1101;  show=5'b10000;  //r
                             end  
                        else begin 
                                 an= 8'b1111_1110;  show=num_reg_show;
                             end    
                    end
             end    
             1:begin   //输出内存
                    led16=3'b001;
                    led17=3'b001;
                   if(cnt_show<=13'd999)begin 
                              an= 8'b0111_1111;   show=memory[address_memory_show][15:12];
                              end
                   else if(cnt_show<=13'd1999)begin 
                              an= 8'b1011_1111;   show=memory[address_memory_show][11:8];  //F
                              end
                    else if(cnt_show<=13'd2999)begin 
                              an= 8'b1101_1111;   show=memory[address_memory_show][7:4];
                              end
                    else if(cnt_show<=13'd3999)begin 
                              an= 8'b1110_1111;   show=memory[address_memory_show][3:0];
                              end       
                    else if(cnt_show<=13'd4999)begin 
                              an= 8'b1111_1101;  show=address_memory_show[7:4];
                              end  
                    else begin 
                              an= 8'b1111_1110;  show=address_memory_show[3:0];
                              end    
             end
         endcase 
    end
    segment_decoder sd(show,digit_x);
endmodule
