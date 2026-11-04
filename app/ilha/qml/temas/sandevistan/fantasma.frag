#version 440
// Um fantasma do Sandevistan: a foto da gota num instante passado, tingida numa cor da paleta, em linhas de 3 px
// e fatias de 6 px que se deslocam em degraus; "come" 0–1 apaga as fatias. Onde a gota está agora ("dentro", em px
// do fantasma), só o contorno: o rastro fica atrás e não tapa o conteúdo. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    vec4 cor;
    float come;
    float passo;
    vec4 dentro;
};
layout(binding = 1) uniform sampler2D fonte;
float h(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
void main() {
    vec2 uv = qt_TexCoord0, px = uv * tam;
    float faixa = floor(px.y / 6.0);
    float of = (h(vec2(faixa, passo)) - 0.5) * 10.0 * step(0.62, h(vec2(faixa, passo + 3.0))) / tam.x;
    vec4 s = texture(fonte, uv + vec2(of, 0.0));
    vec2 o = 2.0 / tam;
    float viz = min(min(texture(fonte, uv + vec2(o.x, 0)).a, texture(fonte, uv - vec2(o.x, 0)).a),
                    min(texture(fonte, uv + vec2(0, o.y)).a, texture(fonte, uv - vec2(0, o.y)).a));
    float sob = step(dentro.x, px.x) * step(px.x, dentro.z) * step(dentro.y, px.y) * step(px.y, dentro.w);
    s *= mix(1.0, clamp((s.a - viz) * 2.0, 0.0, 1.0), sob);
    float lin = 0.45 + 0.55 * step(0.5, fract(px.y / 3.0));
    float vivo = step(come, h(vec2(faixa, 7.0)) * 0.98 + 0.01);
    float l = max(s.r, max(s.g, s.b)) / max(s.a, 0.001);
    vec3 c = cor.rgb * (0.5 + 0.5 * l);
    fragColor = vec4(c * s.a, s.a) * lin * vivo * qt_Opacity;
}
