#version 440
// Glitch dos temas da ilha: só as fatias deslocadas e as franjas de cor, sobre a foto da gota; onde nada mudou sai
// transparente, então o conteúdo vivo continua por baixo. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    float forca;
    float passo;
};
layout(binding = 1) uniform sampler2D fonte;
float h(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
void main() {
    vec2 uv = qt_TexCoord0, px = uv * tam;
    float alt = 5.0 + 16.0 * h(vec2(passo, 3.0)), i = floor(px.y / alt);
    float liga = step(0.5, h(vec2(i, passo + 1.0)));
    float of = (h(vec2(i, passo)) - 0.5) * 60.0 * forca * liga / tam.x;
    float d = (2.0 + 7.0 * h(vec2(passo, 9.0))) * forca / tam.x;
    vec2 q = uv + vec2(of, 0.0);
    vec4 a = texture(fonte, q + vec2(d, 0.0)), b = texture(fonte, q), c = texture(fonte, q - vec2(d, 0.0));
    vec4 r = vec4(a.r, b.g, c.b, max(a.a, max(b.a, c.a)));
    vec4 orig = texture(fonte, uv);
    float dif = max(max(abs(r.r - orig.r), abs(r.g - orig.g)), abs(r.b - orig.b));
    fragColor = r * step(0.04, dif + liga * step(0.5, forca) * 0.05) * qt_Opacity;
}
