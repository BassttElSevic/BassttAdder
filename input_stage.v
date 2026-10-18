// 按键输入、输出均低有效；按下较快确认，松开较慢确认以抑制回弹。
// CLOCK_HZ 为实际板载时钟频率；时间参数以毫秒计，均须大于 0。
module input_stage #(
    parameter integer KEY_COUNT  = 4,
    parameter integer CLOCK_HZ   = 50_000_000,
    parameter integer PRESS_MS   = 5,
    parameter integer RELEASE_MS = 20
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [KEY_COUNT-1:0] sws,
    output wire [KEY_COUNT-1:0] sws_output
);
    localparam integer MS_PER_SECOND = 1_000;
    localparam integer CYCLES_PER_MS = (CLOCK_HZ + MS_PER_SECOND - 1)
                                     / MS_PER_SECOND; // 向上取整
    localparam integer PRESS_CYCLES = CYCLES_PER_MS * PRESS_MS;
    localparam integer RELEASE_CYCLES = CYCLES_PER_MS * RELEASE_MS;
    localparam integer MAX_CYCLES = (PRESS_CYCLES > RELEASE_CYCLES)
                                   ? PRESS_CYCLES : RELEASE_CYCLES;
    localparam integer COUNT_BITS = (MAX_CYCLES > 1) ? $clog2(MAX_CYCLES) : 1;
    localparam [31:0] PRESS_LAST_FULL = PRESS_CYCLES - 1;
    localparam [31:0] RELEASE_LAST_FULL = RELEASE_CYCLES - 1;
    localparam [COUNT_BITS-1:0] PRESS_LAST = PRESS_LAST_FULL[COUNT_BITS-1:0];
    localparam [COUNT_BITS-1:0] RELEASE_LAST = RELEASE_LAST_FULL[COUNT_BITS-1:0];

    // 外部按键异步于 clk，先用两级触发器同步。
    reg [KEY_COUNT-1:0] sw_meta;
    reg [KEY_COUNT-1:0] sw_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta <= {KEY_COUNT{1'b1}};
            sw_sync <= {KEY_COUNT{1'b1}};
        end else begin
            sw_meta <= sws;
            sw_sync <= sw_meta;
        end
    end

    genvar i;
    generate
        for (i = 0; i < KEY_COUNT; i = i + 1) begin : button
            reg [COUNT_BITS-1:0] count;
            reg stable_n;
            wire [COUNT_BITS-1:0] last_count;

            // 当前未按下：等待确认按下；当前已按下：等待确认松开。
            assign last_count = stable_n ? PRESS_LAST : RELEASE_LAST;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count    <= {COUNT_BITS{1'b0}};
                    stable_n <= 1'b1;
                end else if (sw_sync[i] == stable_n) begin
                    // 新电平一旦抖回已确认状态，就从头计时。
                    count <= {COUNT_BITS{1'b0}};
                end else if (count == last_count) begin
                    // 新电平达到对应门限，才确认按下或松开。
                    stable_n <= sw_sync[i];
                    count    <= {COUNT_BITS{1'b0}};
                end else begin
                    count <= count + 1'b1;
                end
            end

            assign sws_output[i] = stable_n;
        end
    endgenerate
endmodule
