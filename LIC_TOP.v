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
	output 						SCK
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



reg clk_8m;
reg rst_n;
reg IIC_en_tri;


initial begin
	clk_8m = 1'b0;
	rst_n = 1'b0;
	#100 rst_n = 1'b1;
forever begin
	#(50) clk_8m = ~clk_8m;
end
end

// assign TRI = (R1[0] & !R1[1])?  1'b1 : 1'b0;
// reg [1:0] R1;
// always  @(posedge clk_8m) begin 
// 	if(rst_n == 1'b0) begin
// 		R1 <= 2'b00;
// 	end
// 	else begin
// 		R1[1] <= R1[0];
// 		R1[0] <= R;
// 	end
	
// end

// reg R;

// initial begin
// 	rst_n = 1'b0;
// 	R = 1'b0;
// 	IIC_en_tri = 1'b0;
// 	#(10000) rst_n = 1'b1;
// 	#(10000) IIC_en_tri = 1'b1;

// 	#(10000) IIC_en_tri = 1'b0;
// end

iic_drive iic_drive_r(
	.clk_8m				(clk_8m				),
	.clk_i				(clk_i				), 
	.rst_n				(rst_n				),
	.wr_rd_flag			(wr_rd_flag			),	//0 wr -- 1 rd
	.start_en			(start_en			),
	.i2c_device_addr	(i2c_device_addr	),
	.register			(register			),
	.data_byte			(data_byte			),
	.scl				(SCK				),
	.sda				(SDI				),
	.busy				(busy				),
	.err                (err                ),
	.rd_data			(rd_data			)	
);
iic_reg_init iic_reg_init_r(
	.clk_i				(clk_i				), 
	.rst_n				(rst_n				),
	.wr_rd_flag			(wr_rd_flag			),	//0 wr -- 1 rd
	.start_en			(start_en			),
	.i2c_device_addr	(i2c_device_addr	),
	.register			(register			),
	.data_byte			(data_byte			),
	.busy				(busy				),
	.err                (err                ),
	.IIC_START			(IIC_START			),
	.IIC_config_busy	(IIC_config_busy	)
);	


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

