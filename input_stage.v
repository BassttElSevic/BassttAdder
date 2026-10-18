// 按键消抖：机械触点在按下/松开的瞬间可能快速地在 0 和 1 之间跳动。
// 只有新电平连续维持足够长，才更新对外输出；短暂抖动不会传给后级模块。
// 输入、输出均低有效：0 表示按下，1 表示松开。输出是持续状态，不是单拍脉冲。
//
// 请注意，我这里这么整，是基于我的板子的情况的，如果要参考，请不要照搬
//
// 包括我这里由于我板子的LED也是低电平点亮的，所以，如果要移植到话，请参考你自己的板子
//
// KEY_COUNT 是按键路数；CLOCK_HZ 是 clk 的频率；两个时间参数的单位是 ms。
// 按下确认得快一些以免漏掉短按，松开确认得慢一些以防回弹重复触发。
// 时间参数须大于 0；这些默认值对应 ZX-1 的 50 MHz 时钟。
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
    // 毫秒换算成时钟拍数：50 MHz 时 1 ms = 50,000 拍，
    // 因而默认按下需 250,000 拍、松开需 1,000,000 拍。
    localparam integer MS_PER_SECOND = 1_000;
    localparam integer CYCLES_PER_MS = (CLOCK_HZ + MS_PER_SECOND - 1)
                                     / MS_PER_SECOND; // 向上取整，避免整数除法低估时钟拍数
    localparam integer PRESS_CYCLES = CYCLES_PER_MS * PRESS_MS;  // 按下需要多少拍，由于这里是5ms,所以我们50,000 * 5
    localparam integer RELEASE_CYCLES = CYCLES_PER_MS * RELEASE_MS; // 松开需要多少拍，同上，由于这里是20ms,我们需要50,000 * 20 拍

    // 计数器按两个门限中较大的一个确定宽度，不必手写固定的位数。
    localparam integer MAX_CYCLES = (PRESS_CYCLES > RELEASE_CYCLES)
                                   ? PRESS_CYCLES : RELEASE_CYCLES;

    // 为了存下这个数，最多需要几个二进制位
    // 这里的 $clog2 是系统函数，以2为底的对数向上去整
    localparam integer COUNT_BITS = (MAX_CYCLES > 1) ? $clog2(MAX_CYCLES) : 1;
    // 从 0 开始数，数满 N 拍时比较的末值就是 N-1。
    // 先使用 32 位常量再截取所需位数，避免 Quartus 的宽度截断警告。
    localparam [31:0] PRESS_LAST_FULL = PRESS_CYCLES - 1;
    localparam [31:0] RELEASE_LAST_FULL = RELEASE_CYCLES - 1;
    localparam [COUNT_BITS-1:0] PRESS_LAST = PRESS_LAST_FULL[COUNT_BITS-1:0];
    localparam [COUNT_BITS-1:0] RELEASE_LAST = RELEASE_LAST_FULL[COUNT_BITS-1:0];

    // 第一步：同步。外部按键随时可能改变，不保证与 clk 边沿对齐。
    // sw_meta 是第一级，可能遇到亚稳态；只让第二级 sw_sync 进入后面的逻辑。
    // 这两级解决跨时钟采样问题，不负责消除机械抖动。
    reg [KEY_COUNT-1:0] sw_meta;
    reg [KEY_COUNT-1:0] sw_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位后认为所有按键都是松开的（低有效，所以是 1）。
            sw_meta <= {KEY_COUNT{1'b1}};
            sw_sync <= {KEY_COUNT{1'b1}};
        end else begin
            sw_meta <= sws;       // 本拍采样原始引脚
            sw_sync <= sw_meta;   // 下一拍取得上一级的值
        end
    end

    // 之所以用<=就是为了以拍为节奏

    // 这里的第一级只是为了承担风险的，第二级才是我们要传递过去的

    // 第二步：每个按键独立消抖。generate 会在综合时展开 KEY_COUNT 份
    // 完全相同的电路：每路都有自己的 count 和已确认电平 stable_n。
    genvar i;

    // 这里的genvar不是数值，我们只是需要把这个生成我们需要的分数的独立电路
    // 在编译的时候，这个会展开

    generate
        for (i = 0; i < KEY_COUNT; i = i + 1) begin : button
            reg [COUNT_BITS-1:0] count;
            reg stable_n; // 这里比较迷惑，这个东西的赋值其实在下面
            
            // 要记住，这个不是时序的，而是同时展开的

            wire [COUNT_BITS-1:0] last_count;

            // stable_n=1 表示当前认为松开，等待 0 持续 PRESS_MS；
            // stable_n=0 表示当前认为按下，等待 1 持续 RELEASE_MS。
            assign last_count = stable_n ? PRESS_LAST : RELEASE_LAST;

            always @(posedge clk or negedge rst_n) begin
                // 情况A,复位
                if (!rst_n) begin
                    count    <= {COUNT_BITS{1'b0}};
                    stable_n <= 1'b1; // 刚复位时认为按键未按下
                // 计数器清零
                //
                // 情况B：现在看到的状态和原来的状态相同
                end else if (sw_sync[i] == stable_n) begin
                    // 观察值等于已确认值：没有待确认的变化。
                    // 若之前刚开始计时又抖回去，也在这里清零重新等待。
                    count <= {COUNT_BITS{1'b0}};
                // 作废，重新开始数
                //
                // 情况C是数够了，而且状态不同
                // 这说明新电平没有弹回原来的状态，且持续了规定的时间，于是，
                // 把新状态给更新
                end else if (count == last_count) begin // 如果这里数够了，就确认按钮的新状态
                    // 新电平一直与 stable_n 不同并数满门限，承认状态变化。
                    stable_n <= sw_sync[i];
                    count    <= {COUNT_BITS{1'b0}};
                // D没数够
                // 继续数
                end else begin
                    // 新电平还没持续够久，继续计数；此时对外输出不变。
                    count <= count + 1'b1;
                end
            end

            // 只把已确认的状态送出；原始 sws 的抖动不直接到达输出。
            assign sws_output[i] = stable_n;
        end
    endgenerate
endmodule
