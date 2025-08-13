`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/03/12 14:11:50
// Design Name: 
// Module Name: IIC_Top
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


module IIC_Top(
	inout 						SDI,
	output 						SCK,
	input						sysclk_p,
	input						sysclk_n
//	input						clk_8m,
//	input 						rst_n,
//	input						IIC_en_tri,
//	output 						IIC_config_busy
    );
	
reg 	 [3:0]		count_reg;
reg 				clk_i;
reg 	 [1:0]		IIC_en_tri_r;
wire				IIC_config_busy;
wire	 [7:0]   	i2c_device_addr;
wire	[15:0]   	register;
wire	 [7:0]   	data_byte;
wire [7:0] rd_data;  // 添加这行
wire 				busy;
wire 				err;
wire 				start_en;
wire 				wr_rd_flag;
wire 				IIC_START;
//reg                 start_en;
assign IIC_START = IIC_en_tri_r[1]&(!IIC_en_tri_r[0]);
always @(posedge clk_8m or negedge rst_n) begin
	if(!rst_n) begin
		clk_i 		<= 1'b0;
		count_reg   <= 4'd0;
	end
	else begin
		if(count_reg == 4'd9) begin
			count_reg 	<= 4'd0;
			clk_i 		<= ~clk_i;
		end
		else begin
			count_reg 	<= count_reg + 1'b1;
			clk_i 		<= clk_i;
		end
	end
end


always@(posedge clk_i)
begin
	IIC_en_tri_r <= {IIC_en_tri_r[0],IIC_en_tri};
end	



// reg clk_8m;
// reg rst_n;
// reg IIC_en_tri; 


// initial begin
// 	clk_8m = 1'b0;
// forever begin
// 	#(50) clk_8m = ~clk_8m;
// end
// end

  clk_wiz_0 clk_wiz_u
   (
    // Clock out ports
    .clk_out1(clk_8m),     // output clk_out1
    // Status and control signals
    .locked(rst_n),       // output locked
   // Clock in ports
    .clk_in1_p(sysclk_p),    // input clk_in1_p
    .clk_in1_n(sysclk_n)    // input clk_in1_n
);
// initial begin
// 	rst_n = 1'b0;
//     //start_en = 1'b0;
// 	//R = 1'b0;
// 	IIC_en_tri = 1'b0;
// 	#(10000) rst_n = 1'b1;
// 	#(15000) IIC_en_tri = 1'b1;
//    // #(1000) start_en= 1'b1;
// 	#(15000) IIC_en_tri = 1'b0;

// end
wire sda_o;
iic_drive iic_drive_r(
	.clk_8m				(clk_8m				),
	.clk_i				(clk_i				), 
	.rst_n				(rst_n				),
	.wr_rd_flag			(wr_rd_flag			),	//0 wr -- 1 rd
	.start_en			(IIC_START			),
	.i2c_device_addr	(i2c_device_addr	),
	.register			(register			),
	.data_byte			(data_byte			),
	.scl				(SCK				),
	.sda				(SDI				),
	.busy				(busy				),
	.err                (err                ),
	.rd_data			(rd_data			),
	.sda_o(sda_o)	
);

vio_0 vio_u (
  .clk(clk_8m),                // input wire clk
  .probe_in0(busy),    // input wire [0 : 0] probe_in0
  .probe_out0(wr_rd_flag),  // output wire [0 : 0] probe_out0
  .probe_out1(IIC_en_tri),  // output wire [0 : 0] probe_out1
  .probe_out2(i2c_device_addr),  // output wire [0 : 0] probe_out2
  .probe_out3(register),  // output wire [0 : 0] probe_out3
  .probe_out4(data_byte)  // output wire [0 : 0] probe_out4
);

ila_0 ila_u (
	.clk(clk_8m), // input wire clk


	.probe0(sda_o), // input wire [0:0]  probe0  
	.probe1(SCK), // input wire [0:0]  probe1 
	.probe2(busy), // input wire [0:0]  probe2 
	.probe3(err), // input wire [0:0]  probe3 
	.probe4(rd_data)
);


// iic_reg_init iic_reg_init_r(
// 	.clk_i				(clk_i				), 
// 	.rst_n				(rst_n				),
// 	.wr_rd_flag			(wr_rd_flag			),	//0 wr -- 1 rd
// 	.start_en			(start_en			),
// 	.i2c_device_addr	(i2c_device_addr	),
// 	.register			(register			),
// 	.data_byte			(data_byte			),
// 	.busy				(busy				),
// 	.err                (err                ),
// 	.IIC_START			(IIC_START			),
// 	.IIC_config_busy	(IIC_config_busy	)
// );	


// .clk_8m				(clk_8m				),
// .clk_i				(clk_i				),
// .rst_n				(rst_n				),
// .wr_rd_flag			(wr_rd_flag			),
// .start_en			(start_en			),
// .i2c_device_addr	(i2c_device_addr	),
// .register			(register			),
// .data_byte			(data_byte			),
// .scl				(scl				),
// .sda				(sda				),
// .busy				(busy				),
// .err				(err				),
// .rd_data			(rd_data			)			



endmodule

