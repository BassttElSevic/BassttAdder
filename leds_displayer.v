// LED 低电平点亮；消抖后的按键也低电平有效，因此直接对应。
module leds_displayer (
    input  wire [3:0] leds_input,
    output wire [3:0] leds_output
);
    assign leds_output = leds_input;
/*
always @(*) begin
    // 那个数字就亮几个，每次只按一个
    if (leds_input == 4'b1111) begin
        leds_output 
    end
end
*/

endmodule
