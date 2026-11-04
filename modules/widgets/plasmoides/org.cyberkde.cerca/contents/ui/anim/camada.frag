#version 440
// Camada única sobre a grade do Cyber Fence, para o que é da cerca inteira e não de um ícone: o cartão central,
// o anel e as faíscas da explosão, as linhas de varredura, as bandas do braindance e a borda do sandevistan.
// Um quad só, em qualquer número de ícones, e só enquanto AnimIcones.qml anima. "modo" é o modoCamada de
// contents/animacoes-icones.json. Tempos em ms. "sai": 0 na entrada, de 0 a 1 na saída. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    float t;
    float total;
    float pre;
    float d;
    float sai;
    float modo;
    vec4 cor;
    vec4 cor2;
    vec4 texto;
};

const float PI = 3.14159265;
float h21(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
float e(float a, float b, float x) { return smoothstep(a, b, x); }
vec4 luz(vec3 c, float a) { return vec4(c * a, a); }
vec4 sobre(vec4 cima, vec4 baixo) { return cima + baixo * (1.0 - cima.a); }
float caixa(vec2 p, vec2 m) { return step(abs(p.x), m.x) * step(abs(p.y), m.y); }
// medido na referência: o anel faz 80% do raio em metade do tempo
float voo(float u) { return 1.0 - pow(1.0 - clamp(u, 0.0, 1.0), 2.2); }
float vn(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.7) * 0.15; }

// explosão tóxica: o gás que se espalha do centro, com bolhas e ruído químico, no lugar do anel
vec4 gas(vec2 px, vec2 p, float u, float quadro) {
    vec2 pe = p / (tam * 0.5), q = p / (min(tam.x, tam.y) * 0.16);
    float w = fbm(q * 0.9 + vec2(0.0, -t * 0.0012));
    float w2 = fbm(q * 1.7 + w * 1.8 + vec2(t * 0.0007, 0.0));
    float frente = voo(u) * 1.3, dist = length(pe) + (w2 - 0.5) * 0.6;
    float some = 1.0 - e(0.3, 1.0, u);
    float dens = e(frente, frente - 0.45, dist) * some;
    // pulsa irregular, por manchas: o brilho doentio
    float puls = 0.6 + 0.4 * h21(vec2(floor(t / 47.0), 2.0));
    float mancha = step(0.78, h21(floor(px / 5.0) + floor(t / 61.0))) * e(0.5, 0.7, w2);
    vec3 c = mix(cor2.rgb, cor.rgb, e(0.5, 0.78, w2));
    float a = dens * (0.05 + 0.2 * w2) * puls + mancha * dens * 0.16;
    a += exp(-abs(dist - frente) * 9.0) * step(0.52, w2) * 0.3 * some;
    vec4 r = luz(c, clamp(a, 0.0, 0.42));
    // bolhas que sobem e estouram
    vec2 cel = floor((px + vec2(0.0, t * 0.035)) / 12.0), f = fract((px + vec2(0.0, t * 0.035)) / 12.0) * 12.0 - 6.0;
    float hb = h21(cel + 11.0), vida = fract(t / 380.0 + hb * 5.0);
    float anel = exp(-abs(length(f - (vec2(h21(cel + 3.0), h21(cel + 5.0)) - 0.5) * 5.0) - (1.2 + 2.2 * hb) * (0.6 + vida)) / 0.45);
    r = sobre(luz(cor2.rgb, anel * step(0.8, hb) * step(vida, 0.82) * e(0.12, 0.3, dens / max(some, 0.001)) * some * 0.8), r);
    // ruído químico: grãos que piscam
    return sobre(luz(cor.rgb, step(0.99, h21(px + quadro * 1.7)) * dens * 0.7), r);
}

// o cartão central: abre de uma fenda, rasga, carrega e estoura em anel; um gêmeo cinza sai do lado
// estilo: 0 com estouro, 1 limpa (só o cartão e o voo), 2 tóxica (gás no lugar do estouro)
vec4 explosao(vec2 px, int estilo) {
    vec2 c = tam * 0.5, p = px - c;
    float esc = clamp(min(tam.x, tam.y) / 260.0, 0.75, 1.3), quadro = floor(t / 33.0);
    vec2 m = vec2(17.0, 22.0) * esc;
    float u = (t - pre) / d, carga = e(50.0, pre, t);
    if (sai > 0.0) {                    // a saída é a da referência: fecha em fenda, por último
        float f = e(0.45, 1.0, sai);
        m *= vec2(1.0 - f * 0.94, 1.0);
        float corroi = estilo == 2 ? step(e(0.15, 0.9, sai), fbm(px / 3.0) * 0.95) : 1.0;
        return luz(texto.rgb, caixa(p, m) * corroi * (1.0 - e(0.92, 1.0, sai)));
    }
    float abre = floor(clamp(t / 66.0, 0.0, 1.0) * 3.0 + 0.999) / 3.0;
    float some = 1.0 - e(0.55, 0.95, u), pisca = t < pre ? mix(0.45, 1.0, step(0.28, h21(vec2(quadro, 3.0)))) : 1.0;
    if (estilo == 1) pisca = 1.0;
    if (estilo == 2) { pisca = 0.75 + 0.25 * h21(vec2(floor(t / 47.0), 6.0)); some = step(e(0.1, 0.75, u), fbm(px / 3.0) * 0.95); }
    float linha = floor(px.y / 2.0);
    float rasgo = t < pre + 40.0 ? (h21(vec2(linha, quadro)) - 0.5) * (2.0 + 16.0 * carga) * step(0.55, h21(vec2(linha * 0.5, quadro + 7.0))) : 0.0;
    if (estilo != 0) rasgo = 0.0;
    vec2 pc = p + vec2(rasgo, 0.0);
    float cartao = caixa(pc, vec2(m.x, m.y * abre));
    if (estilo == 0) cartao *= 1.0 - 0.5 * step(0.8, h21(vec2(linha, quadro + 2.0))) * carga;
    vec4 r = luz(texto.rgb, cartao * pisca * some);
    // o gêmeo cinza, à direita
    float g = estilo == 2 ? 0.0 : e(0.0, 0.14, u) * some * (estilo == 1 ? 0.7 : 1.0);
    r = sobre(r, luz(mix(cor.rgb, texto.rgb, 0.4), caixa(p - vec2(m.x * 2.1 * g, 0.0), m) * 0.55 * g));
    // ruído que incha em volta do cartão e vira a nuvem do estouro
    float raio = mix(m.y * 1.2, m.y * 2.0, carga) * (t < pre ? 1.0 : 1.0 + 1.3 * voo(u));
    float nuvem = exp(-dot(p, p) / max(1.0, raio * raio)) * step(0.62, h21(floor(px / vec2(3.0, 2.0)) + quadro));
    if (estilo == 0) r = sobre(luz(mix(cor.rgb, texto.rgb, 0.5), nuvem * 0.5 * carga * (1.0 - e(0.1, 0.5, u))), r);
    if (estilo == 2) r = sobre(luz(cor2.rgb, nuvem * 0.35 * carga * step(0.5, fract(px.y / 3.0))), r);
    if (u <= 0.0 || estilo == 1) return r;
    if (estilo == 2) return sobre(r, gas(px, p, u, quadro));
    // o anel, com a proporção da cerca, quebrado por setores
    vec2 pe = p / normalize(tam + 1.0) * 0.72;
    float dist = length(pe), ang = atan(pe.y, pe.x), R = length(tam) * 0.42, v = voo(u);
    float ond = exp(-abs(dist - R * v) / 2.0) * pow(max(0.0, 1.0 - u), 1.6) * step(0.3, h21(vec2(floor((ang + PI) * 11.0), 1.0)));
    r = sobre(luz(cor.rgb, ond), r);
    // faíscas: uma por setor, sem laço, para o custo não depender do número delas
    float setor = floor((ang + PI) / (2.0 * PI) * 40.0), hf = h21(vec2(setor, 9.0));
    float dentro = abs(fract((ang + PI) / (2.0 * PI) * 40.0) - 0.5 - (hf - 0.5) * 0.5) * 2.0 * PI / 40.0 * dist;
    float rf = (0.55 + 0.75 * hf) * R * v, compr = 3.0 + 22.0 * (1.0 - u);
    float fa = step(0.42, hf) * step(dentro, 0.7) * step(rf - compr, dist) * step(dist, rf) * pow(max(0.0, 1.0 - u), 1.2);
    return sobre(luz(hf > 0.85 ? texto.rgb : cor.rgb, fa), r);
}

// uma linha a toda a largura; "dir" = -1 sobe. A cauda são riscos, não um degradê
vec4 linhaScan(vec2 px, float y, float dir, vec3 c, float altura) {
    float dy = (px.y - y) * dir, q = floor(px.y / 2.0);
    float fio = exp(-abs(dy) / 1.1);
    float cauda = dy < 0.0 ? exp(dy / altura) * 0.32 * step(0.5, fract(px.y / 4.0)) * mix(0.35, 1.0, h21(vec2(q, floor(t / 33.0)))) : 0.0;
    float marca = step(0.97, fract(px.x / 24.0)) * exp(-abs(dy) / 5.0) * 0.8;
    return luz(mix(c, texto.rgb, fio * 0.7), clamp(fio + cauda + marca, 0.0, 1.0));
}

vec4 varredura(vec2 px) {
    float f = t / total, y = f * (tam.y + 8.0) - 4.0;
    return linhaScan(px, y, 1.0, cor.rgb, 34.0) * (1.0 - e(0.93, 1.0, f));
}

// duas camadas de gravação: cada banda atravessa a cerca num sentido; ao se cruzar, as cores trocam de brilho
vec4 braindance(vec2 px) {
    float f = clamp(t / (total - 260.0), 0.0, 1.0), L = tam.y + 8.0;
    vec4 r = linhaScan(px, f * L - 4.0, 1.0, cor.rgb, 26.0);
    r = sobre(linhaScan(px, tam.y + 4.0 - f * L, -1.0, cor2.rgb, 26.0), r);
    float borda = step(tam.x - 5.0, px.x) * step(0.5, fract(px.y / 6.0)) * step(abs(px.y - (1.0 - f) * tam.y), 18.0);
    return sobre(luz(cor2.rgb, borda * 0.7), r) * (1.0 - e(0.9, 1.0, f));
}

// tempo em câmera lenta: bordas tingidas e fatias verticais congeladas
vec4 sandevistan(vec2 px) {
    float a = e(0.0, 90.0, t) * (1.0 - e(pre, total, t)), dl = min(px.x, tam.x - px.x), dv = min(px.y, tam.y - px.y);
    float b = exp(-min(dl, dv) / 13.0) * 0.32 * step(0.5, fract(px.y / 4.0));
    float col = floor(px.x / 34.0), fatia = step(0.8, h21(vec2(col, 4.0))) * step(abs(fract(px.x / 34.0) - 0.5), 0.015) * 0.16;
    return luz(mix(cor.rgb, cor2.rgb, step(tam.x * 0.5, px.x)), clamp(b + fatia, 0.0, 1.0) * a);
}

void main() {
    vec2 px = qt_TexCoord0 * tam;
    int m = int(modo + 0.5);
    vec4 r = m == 0 ? explosao(px, 0) : m == 1 ? varredura(px) : m == 2 ? braindance(px) : m == 3 ? sandevistan(px)
           : explosao(px, m == 4 ? 1 : 2);
    fragColor = clamp(r, 0.0, 1.0) * qt_Opacity;
}
