#version 440
// Silhueta de uma imagem (logo/emblema da corporação) numa cor só, mantendo o alfa.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 cor;
};
layout(binding = 1) uniform sampler2D fonte;
void main() {
    float a = texture(fonte, qt_TexCoord0).a;
    fragColor = vec4(cor.rgb, 1.0) * cor.a * a * qt_Opacity;
}
