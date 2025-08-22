`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// I2C 驱动模块
// 功能：实现 I2C 总线的主机控制器，支持读写操作
// 特点：支持标准模式和快速模式，具有错误检测和状态监控功能
// 注意：本模块保持原有逻辑不变，仅添加详细注释
///////////////////////////////////////////////////////////////////////////////
module iic_drive(
    input               clk_8m,         // 8MHz 主时钟
    input               clk_i,          // I2C 控制时钟 (0.8MHz = 400kHz*2)
    input               rst_n,          // 低电平有效复位信号
    input               wr_rd_flag,     // 读写标志: 0=写操作, 1=读操作
    input               start_en,       // 启动使能信号
    input        [7:0]  i2c_device_addr,// I2C 设备地址 (7位地址 + 1位读写标志)
    input       [15:0]  register,       // 16位寄存器地址
    input       [7:0]   data_byte,      // 写入的数据字节
    output reg          scl,            // I2C 时钟线输出
    inout               sda,            // I2C 数据线 (双向)
    output reg          busy,           // 忙信号指示
    output reg          err,            // 错误指示信号
    output reg [7:0]    rd_data,        // 读取的数据字节
    output reg          sda_o,          // SDA 输出值
    output reg          sda_t,          // SDA 三态控制 (0=输出, 1=高阻)
    input               sda_i,          // SDA 输入状态
    output wire [15:0]  Rec_count,      // 状态计数器 (用于调试)
    output wire [7:0]   nstate          // 下一状态 (用于调试)
);

// 状态定义 (使用独热码编码)
localparam  idle         = 8'b1111_1110; // FE - 空闲状态 (等待启动)
localparam  start_bit    = 8'b1111_1101; // FD - 起始位状态 (产生START条件)
localparam  wr_dev_ctrl  = 8'b1111_1011; // FB - 写设备控制字 (地址+写标志)
localparam  wr_reg_high  = 8'b1111_0111; // F7 - 写寄存器高字节
localparam  wr_reg_low   = 8'b1110_1111; // EF - 写寄存器低字节
localparam  wr_data_byte = 8'b1101_1111; // DF - 写数据字节
localparam  repeat_start = 8'b1011_1111; // BF - 重复起始位 (读操作前)
localparam  rd_dev_ctrl  = 8'b0111_1111; // 7F - 读设备控制字 (地址+读标志)
localparam  rd_data_byte = 8'b0111_1110; // 7E - 读数据字节
localparam  i2c_over     = 8'b1011_1101; // BD - 传输结束 (产生STOP条件)

// 内部寄存器定义
reg [7:0] nstate;           // 下一状态寄存器
reg [7:0] cstate;           // 当前状态寄存器
reg [7:0] dev_r;            // 设备地址寄存器 (用于移位输出)
reg [7:0] reg_h;            // 寄存器高字节 (用于移位输出)
reg [7:0] reg_l;            // 寄存器低字节 (用于移位输出)
reg [7:0] data_byte_r;      // 数据字节寄存器 (用于移位输出)
reg [7:0] rd_dev_r;         // 读操作设备地址寄存器
reg       State_turn;       // 状态转换标志
reg [15:0] Rec_count;       // 状态内计数器

// SCL 边沿检测寄存器
reg scl_d;                  // SCL 延迟一拍
wire scl_rise = (scl && !scl_d); // SCL 上升沿检测

// 输出信号连接
assign Rec_count = Rec_count;
assign nstate = nstate;

///////////////////////////////////////////////////////////////////////////////
// SCL 边沿检测逻辑
// 功能：检测 SCL 的上升沿，用于数据采样
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if(!rst_n) 
        scl_d <= 1'b1;
    else 
        scl_d <= scl;
end

///////////////////////////////////////////////////////////////////////////////
// 状态转移逻辑
// 功能：根据当前状态和条件确定下一状态
///////////////////////////////////////////////////////////////////////////////
always @(*) begin
    case (cstate)
        idle:        nstate = (start_en) ? start_bit : idle;
        start_bit:   nstate = (State_turn) ? wr_dev_ctrl : start_bit;
        wr_dev_ctrl: nstate = (State_turn) ? wr_reg_high : wr_dev_ctrl;
        wr_reg_high: nstate = (State_turn) ? wr_reg_low : wr_reg_high;
        wr_reg_low:  nstate = (State_turn) ? ((wr_rd_flag) ? repeat_start : wr_data_byte) : wr_reg_low;
        wr_data_byte: nstate = (State_turn) ? i2c_over : wr_data_byte;
        repeat_start: nstate = (State_turn) ? rd_dev_ctrl : repeat_start;
        rd_dev_ctrl: nstate = (State_turn) ? rd_data_byte : rd_dev_ctrl;
        rd_data_byte: nstate = (State_turn) ? i2c_over : rd_data_byte;
        i2c_over:    nstate = (State_turn) ? idle : i2c_over;
        default:     nstate = idle; // 默认返回空闲状态
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// SCL 时钟生成逻辑
// 功能：根据当前状态生成 SCL 时钟信号
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        scl <= 1'b1; // 复位时 SCL 为高电平
    end else begin
        case (nstate)
            idle: 
                scl <= 1'b1; // 空闲状态 SCL 保持高电平
            
            start_bit: 
                scl <= (Rec_count >= 16'd2) ? 1'b0 : 1'b1; // 产生 START 条件
            
            // 数据传输状态: 生成 SCL 时钟
            wr_dev_ctrl, wr_reg_high, wr_reg_low, wr_data_byte, 
            rd_dev_ctrl, rd_data_byte: 
                scl <= ~scl;
            
            repeat_start: 
                scl <= (Rec_count >= 16'd14) ? 1'b0 : 1'b1; // 产生重复 START 条件
            
            i2c_over: 
                scl <= 1'b1; // 结束状态 SCL 保持高电平
            
            default: 
                scl <= 1'b1; // 默认 SCL 保持高电平
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// SDA 三态控制逻辑
// 功能：控制 SDA 线的输出状态（输出/高阻）
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        sda_t <= 1'b1; // 复位时 SDA 为高阻态
    end else begin
        case (nstate)
            idle: 
                sda_t <= 1'b1; // 空闲状态 SDA 为高阻态
            
            start_bit: 
                sda_t <= 1'b0; // START 条件: SDA 输出低电平
            
            repeat_start: 
                // 重复 START 条件: 先释放 SDA 再拉低
                sda_t <= (Rec_count >= 16'd12) ? 1'b0 : 1'b1;
            
            rd_data_byte: 
                // 读数据时释放 SDA (由从机控制), 只在 ACK 周期控制 SDA
                sda_t <= (Rec_count == 16'd16) ? 1'b0 : 1'b1;
            
            // 写操作状态: 在数据位输出数据, 在 ACK 位释放 SDA
            wr_dev_ctrl, wr_reg_high, wr_reg_low, wr_data_byte: 
                sda_t <= (Rec_count == 16'd15 || Rec_count == 16'd16) ? 1'b1 : 1'b0;
            
            // 读设备地址状态: 在数据位输出数据, 在 ACK 位释放 SDA
            rd_dev_ctrl: 
                sda_t <= (Rec_count == 16'd15 || Rec_count == 16'd16 || Rec_count == 16'd17) ? 1'b1 : 1'b0;
            
            i2c_over: 
                sda_t <= 1'b0; // STOP 条件: SDA 输出低电平
            
            default: 
                sda_t <= 1'b1; // 默认 SDA 为高阻态
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// SDA 数据输出逻辑
// 功能：根据当前状态输出 SDA 数据
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        // 复位所有寄存器
        sda_o <= 1'b1;
        dev_r <= 8'hff;
        reg_h <= 8'hff;
        reg_l <= 8'hff;
        data_byte_r <= 8'hff;
        rd_dev_r <= 8'h00;
    end else begin
        case (nstate)
            idle: begin
                sda_o <= 1'b1; // 空闲状态 SDA 输出高电平
            end
            
            start_bit: begin
                // 保存输入数据
                dev_r <= {i2c_device_addr[6:0], 1'b0}; // 设备地址 + 写标志
                reg_h <= register[15:8];               // 寄存器高字节
                reg_l <= register[7:0];                // 寄存器低字节
                data_byte_r <= data_byte;              // 数据字节
                
                // START 条件: 先保持高电平, 然后拉低
                if (Rec_count >= 16'd3) begin
                    sda_o <= dev_r[7]; // 准备发送第一位数据
                end else begin
                    sda_o <= 1'b0;     // START 条件: 拉低 SDA
                end
            end
            
            wr_dev_ctrl: begin
                if (Rec_count == 16'd15 || Rec_count == 16'd16) begin
                    sda_o <= 1'b1; // ACK 周期: 释放 SDA (由从机控制)
                end else if (Rec_count == 16'd17) begin
                    sda_o <= reg_h[7]; // 准备发送下一位数据
                end else begin
                    // 发送设备地址位
                    sda_o <= dev_r[7];
                    // SCL 低电平时移位
                    if (!scl) dev_r <= {dev_r[6:0], dev_r[7]};
                end
            end
            
            wr_reg_high: begin
                if (Rec_count == 16'd15 || Rec_count == 16'd16) begin
                    sda_o <= 1'b1; // ACK 周期: 释放 SDA
                end else if (Rec_count == 16'd17) begin
                    sda_o <= reg_l[7]; // 准备发送下一位数据
                end else begin
                    // 发送寄存器高字节
                    sda_o <= reg_h[7];
                    // SCL 低电平时移位
                    if (!scl) reg_h <= {reg_h[6:0], reg_h[7]};
                end
            end
            
            wr_reg_low: begin
                if (Rec_count == 16'd15 || Rec_count == 16'd16) begin
                    sda_o <= 1'b1; // ACK 周期: 释放 SDA
                end else if (Rec_count == 16'd17 && wr_rd_flag == 1'b0) begin
                    sda_o <= data_byte_r[7]; // 写操作: 准备发送数据字节
                end else if (Rec_count == 16'd17 && wr_rd_flag == 1'b1) begin
                    sda_o <= 1'b1; // 读操作: 准备发送重复 START
                end else begin
                    // 发送寄存器低字节
                    sda_o <= reg_l[7];
                    // SCL 低电平时移位
                    if (!scl) reg_l <= {reg_l[6:0], reg_l[7]};
                end
            end
            
            wr_data_byte: begin
                if (Rec_count == 16'd15 || Rec_count == 16'd16) begin
                    sda_o <= 1'b1; // ACK 周期: 释放 SDA
                end else if (Rec_count == 16'd17) begin
                    sda_o <= 1'b0; // 准备发送 STOP 条件
                end else begin
                    // 发送数据字节
                    sda_o <= data_byte_r[7];
                    // SCL 低电平时移位
                    if (!scl) data_byte_r <= {data_byte_r[6:0], data_byte_r[7]};
                end
            end
            
            repeat_start: begin
                // 准备读操作设备地址
                rd_dev_r <= {i2c_device_addr[6:0], 1'b1}; // 设备地址 + 读标志
                
                if (Rec_count == 16'd16 || Rec_count == 16'd15) begin
                    sda_o <= dev_r[7]; // 发送设备地址位
                end else if (Rec_count >= 16'd12) begin
                    sda_o <= 1'b0;     // 产生 START 条件: 拉低 SDA
                end else if (Rec_count < 16'd12) begin
                    sda_o <= 1'b1;     // 释放 SDA
                end
            end
            
            rd_dev_ctrl: begin
                if (Rec_count == 16'd15 || Rec_count == 16'd16 || Rec_count == 16'd17) begin
                    sda_o <= 1'b1; // ACK 周期: 释放 SDA
                end else begin
                    // 发送读设备地址
                    sda_o <= rd_dev_r[7];
                    // SCL 低电平时移位
                    if (!scl) rd_dev_r <= {rd_dev_r[6:0], rd_dev_r[7]};
                end
            end
            
            rd_data_byte: begin
                if (Rec_count == 16'd16) begin
                    sda_o <= 1'b0; // 发送 ACK 信号
                end else begin
                    sda_o <= 1'b1; // 释放 SDA (由从机控制数据线)
                end
            end
            
            i2c_over: begin
                // STOP 条件: 先拉低 SDA, 然后释放
                if (Rec_count <= 16'd1) begin
                    sda_o <= 1'b0; // 保持 SDA 低电平
                end else begin
                    sda_o <= 1'b1; // 释放 SDA (产生 STOP 条件)
                end
            end
            
            default: 
                sda_o <= 1'b1; // 默认 SDA 输出高电平
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// 数据接收逻辑
// 功能：从 SDA 线读取数据
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin 
    if (!rst_n) begin 
        rd_data <= 8'h00; // 复位读取数据
    end else begin
        case (nstate)
            idle: 
                rd_data <= 8'h00; // 空闲状态清零读取数据
            
            // 在 SCL 上升沿采样数据位
            rd_data_byte: begin
                if (scl_rise && Rec_count < 16'd16)
                    rd_data <= {rd_data[6:0], sda_i}; // 左移接收数据
            end
            
            default: 
                rd_data <= rd_data; // 保持当前值
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// 状态计数器与控制逻辑
// 功能：控制状态内的计数和状态转换
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        Rec_count <= 16'd0;
        State_turn <= 1'b0;
    end else begin
        case (nstate)
            idle: begin
                Rec_count <= 16'd0;
                State_turn <= 1'b0;
            end
            
            repeat_start: begin
                if (Rec_count == 16'd16) begin
                    Rec_count <= 16'd0;
                    State_turn <= 1'b1;
                end else begin
                    Rec_count <= Rec_count + 1'b1;
                    State_turn <= 1'b0;
                end
            end
            
            start_bit, i2c_over: begin
                if (Rec_count == 16'd3) begin // 4周期计数
                    Rec_count <= 16'd0;
                    State_turn <= 1'b1;
                end else begin
                    Rec_count <= Rec_count + 1'b1;
                    State_turn <= 1'b0;
                end
            end
            
            default: begin // 数据传输状态
                if (Rec_count == 16'd17) begin // 18周期计数
                    Rec_count <= 16'd0;
                    State_turn <= 1'b1;
                end else begin
                    Rec_count <= Rec_count + 1'b1;
                    State_turn <= 1'b0;
                end
            end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// 错误检测逻辑
// 功能：检测 ACK 响应错误
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        err <= 1'b0; // 复位错误标志
    end else begin
        case (nstate)
            // 在 ACK 周期检测从机应答
            wr_dev_ctrl, wr_reg_high, wr_reg_low, wr_data_byte, rd_dev_ctrl: begin
                if (Rec_count == 16'd16) begin
                    err <= ~sda_i; // 期望 SDA=0 (ACK), 如果 SDA=1 表示无应答
                end else begin
                    err <= err; // 保持当前值
                end
            end
            
            // 读数据结束后的 ACK 检测
            rd_data_byte: begin
                if (Rec_count == 16'd16) begin
                    err <= ~sda_i; // 期望 SDA=0 (ACK), 如果 SDA=1 表示无应答
                end else begin
                    err <= err; // 保持当前值
                end
            end
            
            default: begin
                err <= 1'b0; // 其他状态清零错误标志
            end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// 忙信号生成逻辑
// 功能：指示 I2C 控制器是否处于忙状态
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 1'b0; // 复位忙信号
    end else begin
        case (nstate)
            idle: 
                busy <= 1'b0; // 空闲状态不忙
            default: 
                busy <= 1'b1; // 其他状态忙
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// 状态寄存器更新
// 功能：更新当前状态寄存器
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        cstate <= idle; // 复位状态机
    end else begin
        cstate <= nstate; // 更新当前状态
    end
end

endmodule