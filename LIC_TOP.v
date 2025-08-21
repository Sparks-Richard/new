`timescale 1ns / 1ps

module IIC_Top(
    inout               SDI,        // I2C数据线（双向）
    output              SCK,        // I2C时钟线
    input               sysclk_p,   // 差分时钟输入+
    input               sysclk_n,   // 差分时钟输入-
    output              clk_24m ,    // 24MHz时钟输出（供摄像头使用）
     output cam_rst      // 连接到Y26
);

// 内部信号声明
reg     [3:0]   count_reg;       // 时钟分频计数器
reg             clk_i;           // I2C控制时钟（0.8MHz）
reg     [1:0]   IIC_en_tri_r;    // I2C使能信号寄存器
wire            IIC_config_busy; // I2C配置忙信号（未使用）
wire    [7:0]   i2c_device_addr; // I2C设备地址（来自VIO）
wire    [15:0]  register;        // 寄存器地址（来自VIO）
wire    [7:0]   data_byte;       // 写入数据（来自VIO）
wire    [7:0]   rd_data;         // 读取数据（来自I2C驱动）
wire            busy;            // 忙信号（来自I2C驱动）
wire            err;             // 错误信号（来自I2C驱动）
wire            start_en;        // 启动使能（内部生成）
wire            wr_rd_flag;      // 读写标志（来自VIO）
wire            IIC_START;       // I2C启动信号
wire    [7:0]   nstate;          // 下一状态（来自I2C驱动）
wire    [15:0]  Rec_count;       // 状态计数器（来自I2C驱动）
wire TESTSDI;                    // SDA测试信号

// SDA三态控制信号
wire sda_i, sda_o, sda_t;

// 三态控制输出
assign SDI = sda_t ? 1'bz : sda_o;  // 标准三态控制

// 输入信号监控
assign sda_i = SDI;                 // 监控SDA线状态
assign TESTSDI = sda_i;             // 连接输入信号到测试端口，用于ILA观测

// I2C启动信号生成（上升沿检测）
assign IIC_START = IIC_en_tri_r[1] & (~IIC_en_tri_r[0]);

// 生成clk_i时钟（0.8MHz）
// 8MHz时钟分频10次得到0.8MHz（8MHz/10=0.8MHz）
always @(posedge clk_8m or negedge rst_n) begin
    if(!rst_n) begin
        clk_i <= 1'b0;
        count_reg <= 4'd0;
    end
    else begin
        if(count_reg == 4'd39) begin 
            count_reg <= 4'd0;
            clk_i <= ~clk_i;
        end
        else begin
            count_reg <= count_reg + 1'b1;
        end
    end
end

// I2C使能信号同步（防抖动）
always @(posedge clk_i) begin
    IIC_en_tri_r <= {IIC_en_tri_r[0], IIC_en_tri};
end

// I2C驱动模块实例化
iic_drive iic_drive_r(
    .clk_8m(clk_8m),             // 8MHz主时钟
    .clk_i(clk_i),               // I2C控制时钟（0.8MHz）
    .rst_n(rst_n),               // 复位信号
    .wr_rd_flag(wr_rd_flag),     // 读写标志：0=写，1=读
    .start_en(IIC_START),        // 启动使能
    .i2c_device_addr(i2c_device_addr), // I2C设备地址
    .register(register),         // 寄存器地址
    .data_byte(data_byte),       // 写入数据
    .scl(SCK),                   // I2C时钟线输出
    .sda(SDI),                   // I2C数据线（双向）
    .busy(busy),                 // 忙信号
    .err(err),                   // 错误指示
    .rd_data(rd_data),           // 读取的数据
    .sda_o(sda_o),               // SDA输出值
    .sda_t(sda_t),               // SDA三态控制
    .sda_i(sda_i),               // SDA输入值
    .Rec_count(Rec_count),       // 状态计数器
    .nstate(nstate)              // 下一状态
);
wire clk_50m;
// 时钟管理模块（生成8MHz和24MHz时钟）
clk_wiz_0 clk_wiz_u (
    .clk_out1(clk_8m),   // 8MHz时钟（用于FPGA逻辑）
    .clk_out2(clk_24m),  // 24MHz时钟（提供给摄像头）
    .clk_out3(clk_50m),
    .locked(rst_n),      // 锁定信号作为复位
    .clk_in1_p(sysclk_p), // 差分时钟+
    .clk_in1_n(sysclk_n)  // 差分时钟-
);

// VIO控制接口（虚拟IO）
vio_0 vio_u (
    .clk(clk_8m),               // 采样时钟（8MHz）
    .probe_in0(busy),           // 输入：忙信号
    .probe_out0(wr_rd_flag),    // 输出：读写标志
    .probe_out1(IIC_en_tri),    // 输出：I2C使能
    .probe_out2(i2c_device_addr), // 输出：设备地址
    .probe_out3(register),      // 输出：寄存器地址
    .probe_out4(data_byte)      // 输出：写入数据
);

// ILA调试接口（集成逻辑分析仪）
ila_0 ila_u (
    .clk(clk_8m), // 采样时钟（8MHz）
    
    // 探针信号
    .probe0(sda_o),      // SDA输出值
    .probe1(SCK),        // SCL时钟
    .probe2(busy),       // 忙信号
    .probe3(TESTSDI),    // SDA实际值
    .probe4(rd_data),    // 读取数据
    .probe5(sda_t),      // SDA三态控制
    .probe6(nstate),     // 下一状态
    .probe7(clk_i),      // I2C控制时钟（0.8MHz）
    .probe8(Rec_count),  // 状态计数器
    .probe9(err) ,
    .probe10(cam_rst),  // 复位信号
    .probe11(clk_24m)           // 错误信号
);

// 实例化复位模块
cam_reset_min reset_min(
    .clk_50m(clk_50m),
    .cam_rst(cam_rst)
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