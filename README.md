# BassttAdder：ZX-1 分模块 Verilog 学习项目

这是一个用来练习 **Verilog 层次化设计、多模块连接和 FPGA 板级验证** 的学习项目。最终目标是在 ZX-1 开发板上实现一个**由按键输入、LED 和六位数码管显示的可视化二进制加法器**。

> **目前还不是加法器。** 当前只实现了第一步：四路按键输入分别消抖，消抖后的 S1～S4 状态一一对应驱动 LED1～LED4。算术逻辑、数码管译码和扫描驱动尚未实现。

## 当前模块结构

```text
ZX-1 按键 keys[3:0]（低有效）
          │
          ▼
  input_stage.v       两级同步 + 独立消抖
          │ sws_output[3:0]（低有效）
          ▼
  leds_displayer.v    同序连接到四路 LED
          │
          ▼
ZX-1 LED leds[3:0]（低电平点亮）
```

`BassttAdder.v` 是顶层模块：声明板级引脚和中间连线，例化 `input_stage` 与 `leds_displayer`，通过 `.子模块端口(顶层信号)` 将它们连接。这样按键处理和输出显示可以分别修改、验证。

输入模块按板载 **50 MHz** 时钟设置了不同的确认时间：按下连续约 **5 ms** 后生效，以减少短按漏检；松开连续约 **20 ms** 后生效，以降低回弹引起的重复触发。`KEY_COUNT`、`CLOCK_HZ`、`PRESS_MS`、`RELEASE_MS` 都是模块参数。消抖输出是**按住期间持续有效的电平**，不是“一次按下一个脉冲”；后续若用于加法器操作，应另行生成单周期按键事件。

## 工程文件

| 文件 | 作用 |
| --- | --- |
| `BassttAdder.v` | 顶层：外部接口与子模块接线 |
| `input_stage.v` | 按键同步与独立消抖 |
| `leds_displayer.v` | 将消抖后的按键状态映射到 LED |
| `BassttAdder.qpf` / `BassttAdder.qsf` | Quartus 工程修订、源文件和管脚约束 |
| `BassttAdder.sdc` | 50 MHz 时钟（20 ns）约束 |
| `Makefile` | 检查、编译、下载等命令 |

`sim/` 用于本地仿真，已被 `.gitignore` 忽略；`db/`、`incremental_db/`、`output_files/` 等生成目录也不会纳入 Git。仓库不包含预编译的下载文件。

## ZX-1 板卡与引脚参考

目标板资料中的 FPGA 为 **Cyclone IV E EP4CE10F17C8N**（Quartus 工程器件名 `EP4CE10F17C8`），板载时钟为 **50 MHz**。以下是本工程使用的顶层信号与资料中的管脚对应关系：

| 顶层信号 | ZX-1 管脚 | 说明 |
| --- | --- | --- |
| `clk` | E1 | 50 MHz 时钟 |
| `rst_n` | K1 | 核心板系统复位，低有效；**不同于四个用户按键** |
| `keys[0]`～`keys[3]` | L3 / L1 / J6 / N1 | 四个用户按键，按下为 0 |
| `leds[0]`～`leds[3]` | T12 / P8 / M8 / M10 | 四个板载 LED，输出 0 时点亮 |

**未来的数码管部分尚未接入当前顶层或 QSF。** ZX-1 资料给出的参考管脚是：段选 `seg[0]`～`seg[7]` 对应 T11 / T10 / T9 / T8 / T7 / T6 / T5 / T4；位选 `sel[0]`～`sel[2]` 对应 M7 / N6 / L6。板上为六位连体共阳极数码管，段选低电平点亮，位选经 74HC138 和三极管驱动；后续需编写动态扫描模块。资料未给出可以据此确认的数码管商业型号。

> **引脚仅供参考，不可直接照搬到其他开发板。** 即使同称 ZX-1，也请先核对自己板子的版本、丝印、原理图、FPGA 封装、电压和 Quartus 器件设置，再实际测试按键位次和 LED 对应关系。特别注意：底板四个用户按键与核心板的系统复位/重新配置小按键不是同一组。不要仅凭这张表接线或烧写配置 Flash。

本项目的板卡信息参照下载资料中的 `ZX_1开发板用户手册.pdf`、`ZX_NO1.pdf` / `ZX_NO2.pdf` 原理图及管脚分配文件；原厂资料不包含在本仓库中。

## 构建与上板

本机使用 Quartus Prime Lite 25.1std；`Makefile` 中 `QBIN`、`SFL` 和默认 USB-Blaster 名称是**本机环境假设**，移植前必须修改。确保所装 Quartus 版本支持目标 Cyclone IV E 器件。

```sh
make check                  # 分析与展开
make build                  # 完整编译，生成 output_files/BassttAdder.sof
make report                 # 查看时序和资源报告
jtagconfig                  # 板子上电，确认 JTAG 线缆和器件
make program                # JTAG 临时下载 .sof；断电后失效
```

若线缆名不同，使用 `make program CABLE='jtagconfig 显示的名称'`。`make program` **不会自动重新编译**，下载前先执行 `make build`。`make flash-jtag` 会改写板载配置 Flash，不属于日常验证步骤；仅在确认板卡、下载口、Flash 类型与参数之后使用。

## 下一步

1. 保持输入、运算和显示模块的接口独立。
2. 为按键操作生成单次触发事件，加入二进制加法逻辑。
3. 加入数码管编码与动态扫描，展示操作数及结果，并分别仿真、上板验证。

## 许可证

本项目采用 [MIT License](LICENSE)。

## Choose Life

<img width="1080" height="723" alt="ChooseLife" src="https://github.com/user-attachments/assets/e75574a2-d737-4999-9eda-97ace082a824" />

<img width="1920" height="1920" alt="D75C00D76AE467D615249CAA7313645F" src="https://github.com/user-attachments/assets/300cacbb-eb72-42a8-8a00-dd8f469736d0" />

<img width="1256" height="1292" alt="ezgif com-gif-maker" src="https://github.com/user-attachments/assets/d67c7685-7a46-4537-90f2-6e23dc352f62" />
