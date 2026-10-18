// 四路按键消抖：输入和输出都为低有效（按下为 0）。
// 50 MHz 时钟下，输入保持新状态约 20 ms 才更新输出。
module input_stage (
   
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  sws,
    output wire [3:0]  sws_output

);
    // 外部按键异步于 clk，先用两级触发器同步。
    reg [3:0] sw_meta;
    reg [3:0] sw_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta <= 4'b1111;
            sw_sync <= 4'b1111;
        end else begin
            sw_meta <= sws;
            sw_sync <= sw_meta;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : button
            reg [19:0] count;
            reg stable_n;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count    <= 20'd0;
                    stable_n <= 1'b1;
                end else if (sw_sync[i] == stable_n) begin
                    // 电平未变化，或抖动回到原来的状态，重新计时。
                    count <= 20'd0;
                end else if (count == 20'd999_999) begin
                    // 新电平持续 1,000,000 个时钟周期（约 20 ms）。
                    stable_n <= sw_sync[i];
                    count    <= 20'd0;
                end else begin
                    count <= count + 20'd1;
                end
            end

            assign sws_output[i] = stable_n;
        end
    endgenerate
endmodule
