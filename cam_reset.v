module cam_reset_min(
    input clk_50m,
    output reg cam_rst  // 连接到Y26
);

reg [23:0] cnt;
always @(posedge clk_50m) begin
    if (cnt < 24'd50_000) begin  // 1ms复位脉冲
        cam_rst <= 0;    // 拉低复位
        cnt <= cnt + 1;
    end else begin
        cam_rst <= 1;    // 释放复位
    end
end




endmodule
