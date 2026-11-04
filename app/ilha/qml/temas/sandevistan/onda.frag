#version 440
// Halo e onda do Sandevistan, em volta da gota (chanfro no canto de baixo à direita), num quad com margem "m".
// "halo" 0–1 enquanto o tempo está quase parado; "onda" 0–1 quando ele volta (< 0: sem onda): dois anéis, um em
// cada cor, separados, quebrados em fatias. Fundida à barra, nada por cima da barra. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    vec2 caixa;
    float m;
    float corte;
    float halo;
    float onda;
    float topo;
    vec4 cor1;
    vec4 cor2;
};
float h(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
vec4 luz(vec3 c, float a) { return vec4(c * a, a); }
vec4 sobre(vec4 a, vec4 b) { return a + b * (1.0 - a.a); }
void main() {
    vec2 q = qt_TexCoord0 * tam - m, b = caixa * 0.5, pr = q - b;
    vec2 dq = abs(pr) - b;
    float d = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0);
    d = max(d, (q.x + q.y - (caixa.x + caixa.y - corte)) * 0.7071);
    float fora = step(0.0, d) * (1.0 - topo * step(q.y, 3.0));
    float fatia = step(0.3, h(vec2(floor(q.y / 5.0), floor(onda * 6.0))));
    vec4 r = luz(cor2.rgb, fora * halo * (exp(-d / 5.0) * 0.32 + exp(-abs(d - 3.0) / 0.7) * 0.6));
    if (onda >= 0.0) {
        float s = onda, ra = 3.0 + 26.0 * s, rb = 3.0 + 26.0 * max(0.0, s - 0.12);
        r = sobre(luz(cor2.rgb, fora * fatia * exp(-abs(d - ra) / 1.1) * (1.0 - s)), r);
        r = sobre(luz(cor1.rgb, fora * fatia * exp(-abs(d - rb) / 1.1) * (1.0 - s) * 0.85), r);
    }
    fragColor = clamp(r, 0.0, 1.0) * qt_Opacity;
}
