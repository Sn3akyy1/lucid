#version 440
// lens's adjustments, one pass. compile: qsb --qt6 -o adjust.frag.qsb adjust.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float exposure;
    float contrast;
    float highlights;
    float shadows;
    float saturation;
    float vibrance;
    float warmth;
    float tint;
    float fade;
    float mono;
};
layout(binding = 1) uniform sampler2D source;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void main() {
    vec4 px = texture(source, qt_TexCoord0);
    if (px.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 c = px.rgb / px.a;

    // white balance and exposure in linear light
    vec3 lin = pow(max(c, vec3(0.0)), vec3(2.2));
    lin *= vec3(1.0 + warmth * 0.18 + tint * 0.06, 1.0 - tint * 0.12, 1.0 - warmth * 0.18 + tint * 0.06);
    lin *= exp2(exposure * 2.0);
    c = pow(max(lin, vec3(0.0)), vec3(1.0 / 2.2));

    // shadows and highlights move the tone alone, so colours hold; black stays black
    float l = dot(c, LUMA);
    float lo = (1.0 - smoothstep(0.05, 0.6, l)) * smoothstep(0.0, 0.12, l);
    float hi = smoothstep(0.4, 1.0, l);
    float nl = l + shadows * 0.3 * lo + highlights * 0.3 * hi * (highlights > 0.0 ? 1.5 * max(0.0, 1.0 - l) : 1.0);
    c *= l > 0.0001 ? max(nl, 0.0) / l : 1.0;

    // contrast: an s-curve to add, a pull to the middle to take away
    c = clamp(c, 0.0, 1.0);
    if (contrast > 0.0)
        c = mix(c, c * c * (3.0 - 2.0 * c), contrast);
    else
        c = mix(c, vec3(0.5) + (c - vec3(0.5)) * 0.5, -contrast);

    // saturation, and vibrance that leaves already strong colours alone
    float g = dot(c, LUMA);
    float spread = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
    c = mix(vec3(g), c, (1.0 + saturation) * (1.0 + vibrance * (1.0 - spread)));

    // a matte finish: blacks lifted, whites eased down
    c = c * (1.0 - fade * 0.22) + fade * 0.12;

    c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), mono);

    c = clamp(c, 0.0, 1.0);
    fragColor = vec4(c * px.a, px.a) * qt_Opacity;
}
