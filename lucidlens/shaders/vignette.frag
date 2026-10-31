#version 440
// darker (or lighter) towards the frame's corners, as an ellipse of the frame.
// compile: qsb --qt6 -o vignette.frag.qsb vignette.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;
};

void main() {
    float r = length((qt_TexCoord0 - vec2(0.5)) * 2.0) / 1.41421;
    float a = abs(amount) * smoothstep(0.3, 1.05, r) * 0.85;
    vec3 ink = amount > 0.0 ? vec3(0.0) : vec3(1.0);
    fragColor = vec4(ink * a, a) * qt_Opacity;
}
