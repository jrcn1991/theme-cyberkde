#version 440
// Decoração atrás de um ícone que anima (AnimIcones.qml): um quad por ícone, com o cartão da explosão ou
// a retícula e a barra de upload do quickhack. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    vec2 miolo;     // o tamanho do cartão ou do alvo
    float modo;     // 0 cartão, 1 retícula
    float fl;       // alerta (0–1, em degraus)
    float rasgo;    // ruído do voo
    float trava;    // retícula: 0 aberta, 1 no alvo
    float barra;    // upload: 0–1
    float semente;
    float quadro;
    vec4 cor;
    vec4 alerta;
};

float h21(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031 + semente * 0.0171); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
vec4 luz(vec3 c, float a) { return vec4(c * a, a); }
vec4 sobre(vec4 cima, vec4 baixo) { return cima + baixo * (1.0 - cima.a); }

void main() {
    vec2 px = qt_TexCoord0 * tam, p = px - tam * 0.5, m = miolo * 0.5;
    vec4 r = vec4(0.0);
    if (modo < 0.5) {
        float linha = floor(px.y / 2.0);
        vec2 b = abs(p + vec2((h21(vec2(linha, quadro)) - 0.5) * 8.0 * rasgo, 0.0));
        float cc = m.x + m.y - b.x - b.y;       // o canto cortado, como nos cartões da referência
        float dentro = step(b.x, m.x) * step(b.y, m.y) * step(5.0, cc);
        float borda = dentro * (1.0 - step(1.0, min(min(m.x - b.x, m.y - b.y), (cc - 5.0) * 0.7)));
        float falha = 1.0 - rasgo * step(0.72, h21(vec2(linha, quadro + 3.0)));
        vec3 c = alerta.rgb;
        r = sobre(luz(c, borda * 0.85), luz(c, dentro * (0.07 + 0.83 * fl))) * falha;
    } else {
        // quatro cantos, que travam em degraus
        vec2 h = m + 2.0 + (1.0 - trava) * 14.0;
        vec2 b = abs(p);
        float canto = step(b.x, h.x + 1.0) * step(b.y, h.y + 1.0) * (1.0 - step(b.x, h.x - 1.0) * step(b.y, h.y - 1.0));
        canto *= step(h.x - 7.0, b.x) * step(h.y - 7.0, b.y);
        r = luz(barra >= 1.0 ? cor.rgb : alerta.rgb, canto);
        // a barra, segmentada, logo abaixo do alvo
        float yb = h.y + 3.5;
        if (trava >= 1.0 && barra < 1.0 && abs(p.y - yb) < 1.5 && abs(p.x) < h.x + 1.0) {
            float f = (p.x + h.x + 1.0) / (2.0 * h.x + 2.0);
            float seg = step(0.3, fract(px.x / 4.0));
            r = sobre(luz(cor.rgb, seg * (f < barra ? 1.0 : 0.22)), r);
        }
    }
    fragColor = clamp(r, 0.0, 1.0) * qt_Opacity;
}
