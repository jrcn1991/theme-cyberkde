#version 440
// Logo/emblema da corporação numa cor só, em dois tons: a parte mais clara do desenho na cor cheia, a mais escura
// a 38%, para o recorte interno (as folhas da Biotechnica, o olho da NetWatch) não virar uma mancha. "lo" e "hi" são
// as luminâncias das cores do SVG; com hi <= lo (uma cor só), tudo na cor cheia.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 cor;
    float lo;
    float hi;
};
layout(binding = 1) uniform sampler2D fonte;
void main() {
    vec4 s = texture(fonte, qt_TexCoord0);
    float a = s.a, tom = 1.0;
    if (hi > lo && a > 0.0) {
        vec3 c = s.rgb / a;
        tom = mix(0.38, 1.0, clamp((dot(c, vec3(0.3, 0.59, 0.11)) - lo) / (hi - lo), 0.0, 1.0));
    }
    fragColor = vec4(cor.rgb, 1.0) * cor.a * a * tom * qt_Opacity;
}
