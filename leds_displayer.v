// LED 低电平点亮；消抖后的按键也低电平有效，因此直接对应。
module leds_displayer (
    input  wire [3:0] leds_input,
    output wire [3:0] leds_output
);
    assign leds_output = leds_input;
endmodule
