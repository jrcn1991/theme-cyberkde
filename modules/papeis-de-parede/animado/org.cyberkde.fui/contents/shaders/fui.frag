#version 440
// Papel de parede FUI (CyberKDE): o fundo da referência "Cyberpunk 2077 UI Art" (GIF de 481 quadros a
// 30 ms), medido quadro a quadro:
//  - base cinza muito escura (#111) e só o canal da cor de luz por cima (na Arasaka, G e B ficam em 17
//    e o vermelho vai de 36 no topo a 67 na faixa enfumaçada de baixo);
//  - feixes diagonais subindo para a direita (~12,5°) quase PARADOS: o que anda são os pulsos de luz que
//    correm ao longo deles (~1,1 altura de tela por segundo, ~15 px/quadro a 800 px) com rastro e um
//    brilho em cruz na cabeça; os tracejados fora de foco fluem devagar; o arranjo dos feixes troca por
//    dissolução ao longo de um ciclo de 14,4 s;
//  - retículo HUD fraco à esquerda que balança devagar (período ~4,5 s);
//  - grão novo a cada quadro (desvio ~4/255), poeira e arranhões de filme;
//  - glitch de 3 quadros por ciclo: tinta azul-arroxeada, faixas deslocadas e riscos horizontais ciano/vermelho.
// Unidades: altura da tela = 1 (x vai de 0 à proporção da tela). y cresce para baixo.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;            // tamanho em px
    float t;             // tempo da cena em s (já multiplicado pela velocidade)
    float quadro;        // contador de quadros (grão, poeira)
    float intensidade;   // 0..2 (1 = a referência)
    float glitch;        // 0..1 (o QML liga por ~3 quadros a cada ciclo)
    float entrada;       // 0..1 (o fundo surge do preto no começo)
    float respira;       // multiplicador lento do brilho (pulso de luz do ciclo)
    float grao;          // 0..1 (0 no quadro estático em alta resolução, que fica limpo de ruído animado)
    vec4 corLuz;         // cor dos feixes (núcleo)
    vec4 corNevoa;       // cor da fumaça
    vec4 corBase;        // fundo
};

const float CICLO = 14.4;

// hashes sem seno (D. Hoskins): só float, estáveis em GLSL 120/100 e sem padrão de grade
float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float ruido(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * ruido(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
    return v;
}
// janela suave 0→1→0 entre a e b (com rampa r)
float janela(float x, float a, float b, float r) { return smoothstep(a, a + r, x) * (1.0 - smoothstep(b - r, b, x)); }
// vida de um elemento ao longo do ciclo: aceso entre a e b (frações do ciclo), dissolvendo em f
float vida(float a, float b, float f) {
    float c = fract(t / CICLO);
    return max(janela(c, a, b, f), max(janela(c + 1.0, a, b, f), janela(c - 1.0, a, b, f)));
}

// ---- feixe: reta por "a" com ângulo "ang" (radianos, positivo = sobe para a direita), de s0 a s1
struct Feixe { vec2 a; float ang; float s0; float s1; float w; };
vec2 dirDe(float ang) { return vec2(cos(ang), -sin(ang)); }
// coordenadas (s ao longo, d de lado)
vec2 noFeixe(vec2 p, Feixe f) {
    vec2 dr = dirDe(f.ang), q = p - f.a;
    return vec2(dot(q, dr), dot(q, vec2(-dr.y, dr.x)));
}
float perfil(float d, float w) {
    if (abs(d) > 0.35) return 0.0;          // longe do feixe: só o halo largo, já desprezível
    float x = d / w;
    // (mais luz espalhada quanto mais largo: o núcleo de um feixe desfocado é mais fraco)
    return exp(-x * x) + 0.38 * exp(-abs(d) / (w * 5.0)) + 0.14 * exp(-abs(d) / (w * 20.0)) + 0.03 * exp(-abs(d) / 0.09);
}
// feixe com foco variando ao longo: "desf" multiplica a largura no começo (s0) e vai a 1 no fim (s1)
float feixeFoco(vec2 sd, Feixe f, float desf) {
    float u = clamp((sd.x - f.s0) / max(0.01, f.s1 - f.s0), 0.0, 1.0);
    float k = mix(desf, 1.0, smoothstep(0.0, 0.85, u));
    return perfil(sd.y, f.w * k) / sqrt(k);
}
// pulso que corre ao longo do feixe: cabeça quase quadrada (borrão de movimento) e rastro atrás.
// Devolve a intensidade; "cab" recebe a posição da cabeça (s) e a força do pulso.
float pulso(vec2 sd, Feixe f, float v, float periodo, float fase, float w, out vec2 cab) {
    float comp = (f.s1 - f.s0) + 0.6;
    float tt = mod(t - fase, periodo);
    cab = vec2(0.0);
    float s = f.s0 - 0.3 + tt * v;
    float forca = tt * v < comp ? janela(s, f.s0 - 0.2, f.s1 + 0.2, 0.25) : 0.0;
    cab = vec2(s, forca);
    if (forca <= 0.0 || abs(sd.y) > 0.06) return 0.0;
    float u = sd.x - s;
    // cabeça: bloco claro quase retangular (~0,018 × 0,012 da altura), com um halo curto
    float bloco = exp(-pow(abs(u) / 0.009, 4.0) - pow(abs(sd.y) / 0.006, 4.0));
    float halo = exp(-pow(u / 0.03, 2.0)) * exp(-abs(sd.y) / (w * 4.0));
    float rastro = u < 0.0 ? (exp(u / 0.16) * 0.30 + exp(u / 0.035) * 0.35) * exp(-pow(sd.y / (w * 2.0), 2.0)) : 0.0;
    return (bloco * 2.4 + halo * 0.9 + rastro) * forca;
}
// tracejado fora de foco (o "texto" desfocado ao longo dos feixes): blocos com borda mole que fluem
float tracejado(vec2 sd, float celula, float vel, float larg, float semente) {
    if (abs(sd.y) > larg * 3.5) return 0.0;
    float x = (sd.x - t * vel) / celula;
    float c = floor(x), f = fract(x);
    float on = step(0.38, h11(c + semente));
    float comp = mix(0.25, 0.8, h11(c * 1.7 + semente));
    float borda = 0.18;
    float bloco = smoothstep(0.0, borda, f) * (1.0 - smoothstep(comp - borda, comp, f));
    float lado = exp(-pow(sd.y / larg, 2.0));
    return on * bloco * lado * mix(0.5, 1.0, h11(c + semente * 3.1));
}
// partículas (bokeh) numa faixa em volta do feixe, derivando devagar e cintilando
float particulas(vec2 sd, float celula, float faixa, float semente) {
    if (abs(sd.y) > faixa + 0.015) return 0.0;
    float acc = 0.0;
    float x = sd.x / celula;
    for (int k = -1; k <= 1; k++) {
        float c = floor(x) + float(k);
        float r = h11(c + semente);
        if (r < 0.45) continue;
        float deriva = t * mix(0.01, 0.05, h11(c * 3.3 + semente));
        vec2 centro = vec2((c + h11(c * 5.1 + semente)) * celula + deriva, (h11(c * 7.7 + semente) - 0.5) * 2.0 * faixa);
        float raio = mix(0.0025, 0.011, pow(h11(c * 9.1 + semente), 2.0));
        float dist = length(sd - centro);
        float disco = 1.0 - smoothstep(raio * 0.45, raio, dist);
        float pisca = 0.55 + 0.45 * sin(t * mix(1.5, 4.0, h11(c + 2.0)) + c);
        acc += disco * pisca * mix(0.35, 0.9, h11(c * 2.9 + semente));
    }
    return acc;
}

// ---- a luz da cena (feixes, pulsos, tracejados, partículas e retículo); a névoa vem da textura
float cena(vec2 p, float asp) {
    float luz = 0.0;
    vec2 cab;
    // ---- arranjo A (começo do ciclo): feixe principal alto, tracejado desfocado em cima à direita
    float vA = vida(-0.12, 0.42, 0.10);
    if (vA > 0.001) {
        Feixe f1 = Feixe(vec2(0.0, 0.51), 0.218, -0.1, asp + 0.2, 0.0034);
        vec2 sd = noFeixe(p, f1);
        float l = feixeFoco(sd, f1, 3.2) * janela(sd.x, f1.s0, f1.s1, 0.3) * 0.62;
        // barra perpendicular desfocada que cruza o feixe (a "trava" da referência)
        vec2 bq = (sd - vec2(1.05, 0.0)) / vec2(0.011, 0.034);
        l += exp(-pow(max(abs(bq.x) - 0.6, 0.0) * 2.2, 2.0) - pow(max(abs(bq.y) - 0.6, 0.0) * 2.2, 2.0)) * 0.55;
        // bloco comprido desfocado logo acima do feixe, à direita
        vec2 bb = (sd - vec2(1.42, 0.032)) / vec2(0.085, 0.010);
        l += exp(-pow(max(abs(bb.x) - 0.8, 0.0) * 3.0, 2.0) - pow(max(abs(bb.y) - 0.5, 0.0) * 2.0, 2.0)) * 0.6;
        l += pulso(sd, f1, 1.15, 4.1, 0.3, f1.w, cab);
        vec2 hp = f1.a + dirDe(f1.ang) * cab.x;   // brilho em cruz na cabeça
        l += cab.y * (0.55 * exp(-abs(p.x - hp.x) / 0.0016) * exp(-abs(p.y - hp.y) / 0.045)
                    + 0.30 * exp(-abs(p.y - hp.y) / 0.0012) * exp(-abs(p.x - hp.x) / 0.10));
        l += pulso(sd, f1, 0.75, 6.3, 2.9, f1.w, cab) * 0.8;
        l += tracejado(sd + vec2(0.0, 0.035), 0.065, 0.14, 0.013, 3.0) * janela(sd.x, 0.0, 0.75, 0.2) * 0.75;
        l += tracejado(sd + vec2(0.0, -0.012), 0.045, 0.10, 0.011, 5.0) * janela(sd.x, -0.1, 0.45, 0.2) * 0.6;
        l += particulas(sd, 0.07, 0.07, 11.0) * 0.6;
        // feixe curto e fino logo abaixo
        Feixe f2 = Feixe(vec2(0.46, 0.52), 0.18, 0.0, 0.46, 0.0016);
        vec2 sd2 = noFeixe(p, f2);
        l += perfil(sd2.y, f2.w) * janela(sd2.x, f2.s0, f2.s1, 0.08) * 0.75;
        l += pulso(sd2, f2, 0.9, 3.3, 1.2, f2.w, cab) * 0.9;
        // tracejado grosso desfocado em cima à direita
        Feixe f3 = Feixe(vec2(0.85, 0.235), 0.20, 0.0, 1.0, 0.016);
        vec2 sd3 = noFeixe(p, f3);
        l += tracejado(sd3, 0.09, 0.05, 0.018, 7.0) * janela(sd3.x, 0.0, 1.0, 0.2) * 0.95;
        l += perfil(sd3.y, 0.004) * janela(sd3.x, 0.2, 1.0, 0.3) * 0.45;
        luz += l * vA;
    }
    // ---- arranjo B (meio): feixe principal mais baixo à esquerda, dois paralelos, tracejado à esquerda
    float vB = vida(0.30, 0.74, 0.10);
    if (vB > 0.001) {
        Feixe g1 = Feixe(vec2(0.0, 0.62), 0.205, -0.1, asp + 0.2, 0.0032);
        vec2 sd = noFeixe(p, g1);
        float l = feixeFoco(sd, g1, 2.8) * janela(sd.x, g1.s0, g1.s1, 0.3) * 0.62;
        l += pulso(sd, g1, 1.25, 3.6, 0.8, g1.w, cab);
        vec2 hp = g1.a + dirDe(g1.ang) * cab.x;
        l += cab.y * (0.55 * exp(-abs(p.x - hp.x) / 0.0016) * exp(-abs(p.y - hp.y) / 0.045)
                    + 0.30 * exp(-abs(p.y - hp.y) / 0.0012) * exp(-abs(p.x - hp.x) / 0.10));
        l += tracejado(sd + vec2(0.0, -0.02), 0.05, 0.16, 0.010, 13.0) * janela(sd.x, -0.1, 0.55, 0.2) * 0.7;
        l += particulas(sd, 0.06, 0.08, 17.0) * 0.6;
        Feixe g2 = Feixe(vec2(0.38, 0.62), 0.205, 0.0, 0.9, 0.0015);
        vec2 sd2 = noFeixe(p, g2);
        l += perfil(sd2.y, g2.w) * janela(sd2.x, g2.s0, g2.s1, 0.1) * 0.7;
        l += pulso(sd2, g2, 0.85, 2.7, 1.9, g2.w, cab) * 0.9;
        Feixe g3 = Feixe(vec2(0.6, 0.30), 0.23, 0.0, 1.3, 0.020);
        vec2 sd3 = noFeixe(p, g3);
        l += perfil(sd3.y, g3.w) * janela(sd3.x, g3.s0, g3.s1, 0.35) * 0.30;
        l += tracejado(sd3, 0.11, 0.04, 0.02, 21.0) * janela(sd3.x, 0.3, 1.3, 0.3) * 0.5;
        luz += l * vB;
    }
    // ---- arranjo C (fim): feixes baixos à esquerda indo ao alto à direita, mais leves e desfocados
    float vC = vida(0.60, 0.98, 0.10);
    if (vC > 0.001) {
        Feixe k1 = Feixe(vec2(0.0, 0.74), 0.25, -0.1, asp + 0.2, 0.0034);
        vec2 sd = noFeixe(p, k1);
        float l = feixeFoco(sd, k1, 3.5) * janela(sd.x, k1.s0, k1.s1, 0.3) * 0.55;
        l += pulso(sd, k1, 1.05, 4.6, 2.2, k1.w, cab);
        vec2 hp = k1.a + dirDe(k1.ang) * cab.x;
        l += cab.y * (0.55 * exp(-abs(p.x - hp.x) / 0.0016) * exp(-abs(p.y - hp.y) / 0.045)
                    + 0.30 * exp(-abs(p.y - hp.y) / 0.0012) * exp(-abs(p.x - hp.x) / 0.10));
        l += pulso(sd, k1, 1.5, 5.9, 4.1, k1.w, cab) * 0.7;
        l += particulas(sd, 0.08, 0.1, 23.0) * 0.55;
        Feixe k2 = Feixe(vec2(0.9, 0.16), 0.19, 0.0, 1.0, 0.022);
        vec2 sd2 = noFeixe(p, k2);
        l += tracejado(sd2, 0.10, 0.06, 0.022, 29.0) * janela(sd2.x, 0.0, 1.0, 0.25) * 0.85;
        Feixe k3 = Feixe(vec2(1.0, 0.36), 0.16, 0.0, 0.8, 0.0017);
        vec2 sd3 = noFeixe(p, k3);
        l += perfil(sd3.y, k3.w) * janela(sd3.x, k3.s0, k3.s1, 0.15) * 0.6;
        l += pulso(sd3, k3, 0.8, 3.9, 0.4, k3.w, cab) * 0.8;
        luz += l * vC;
    }

    // ---- retículo HUD fraco à esquerda (balança devagar; some no fim do ciclo)
    float vR = vida(-0.10, 0.62, 0.12);
    if (vR > 0.001) {
        vec2 c = vec2(0.40 + 0.012 * sin(t * 1.4), 0.45 + 0.006 * sin(t * 0.9 + 1.0));
        vec2 q = p - c;
        float r = length(q), ang = atan(q.y, q.x);
        float anel = exp(-pow((r - 0.135) / 0.0035, 2.0)) * 0.14 + exp(-pow((r - 0.122) / 0.0025, 2.0)) * 0.06
                   + exp(-pow((r - 0.13) / 0.03, 2.0)) * 0.05;                 // o disco escuro-avermelhado em volta
        float marcas = exp(-pow((r - 0.146) / 0.006, 2.0)) * smoothstep(0.75, 0.9, fract(ang * 6.0 / 3.14159 + t * 0.03)) * 0.14;
        float cruz = exp(-abs(q.x + 0.025) / 0.0018) * smoothstep(0.17, 0.12, abs(q.y)) * 0.16
                   + exp(-abs(q.y) / 0.0018) * smoothstep(0.07, 0.05, abs(q.x)) * smoothstep(0.008, 0.016, abs(q.x)) * 0.2;
        float centro = exp(-pow((r - 0.011) / 0.0025, 2.0)) * 0.45;
        // "texto" desfocado do retículo (blocos pequenos em cima à direita)
        vec2 tq = (q - vec2(0.05, -0.08)) / vec2(0.022, 0.009);
        float txt = exp(-pow(max(abs(tq.x) - 1.0, 0.0) * 3.0, 2.0) - pow(max(abs(tq.y) - 1.0, 0.0) * 3.0, 2.0)) * step(0.4, fract(tq.x * 0.9)) * 0.35;
        luz += (anel + marcas + cruz + centro + txt) * vR * (0.85 + 0.15 * sin(t * 3.0));
    }
    return luz;
}

vec2 fumacaCalc(vec2 uv, float asp) {
    vec2 p = vec2(uv.x * asp, uv.y);
    // fumaça: fbm esticada ao longo da diagonal, derivando devagar
    float ca = cos(0.2), sa = sin(0.2);
    vec2 pr = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
    float n = fbm(pr * vec2(1.6, 4.2) + vec2(t * 0.012, 0.0));
    float n2 = fbm(pr * vec2(3.5, 9.0) - vec2(t * 0.02, t * 0.004) + 7.0);
    // faixa enfumaçada de baixo (a massa vermelha difusa sob os feixes)
    float yb = 0.71 - 0.10 * (p.x / asp);
    float dy = p.y - yb;   // borda de cima mais definida que a de baixo
    float faixa = exp(-pow(dy / (dy < 0.0 ? 0.06 : 0.12), 2.0)) * (0.55 + 0.75 * n);
    float manchas = fbm(p * vec2(7.0, 7.0) + 3.0);                  // textura suja, quase parada
    float nevoa = 0.42 + 0.45 * n * n + 0.75 * faixa + 0.25 * n2 * faixa + 0.30 * (manchas - 0.5);
    nevoa *= mix(0.78, 1.0, smoothstep(0.0, 0.5, p.y));            // topo um pouco mais escuro
    // manchas cinzas finas do filme
    float mg = fbm(p * 22.0 + 41.0) * fbm(p * 4.0 + 17.0);
    float suj = smoothstep(0.25, 0.42, mg);
    return vec2(clamp(nevoa * 0.5, 0.0, 1.0), suj);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float asp = res.x / res.y;
    // glitch: faixas horizontais deslocadas
    float g = glitch;
    if (g > 0.0) {
        float faixaY = floor(uv.y * res.y / mix(6.0, 26.0, h11(floor(quadro))));
        if (h11(faixaY + floor(quadro) * 13.0) < 0.35 * g) uv.x += (h11(faixaY * 3.7 + quadro) - 0.5) * 0.06 * g;
    }
    vec2 p = vec2(uv.x * asp, uv.y);
    vec2 fm = fumacaCalc(uv, asp);
    float nevoa = fm.x * 2.0;
    float luz = cena(p, asp) * intensidade * respira;

    // vinheta (cantos e borda direita mais escuros): só na luz e na fumaça; a base cinza fica
    vec2 v = (uv - vec2(0.42, 0.55)) * vec2(1.0, 1.25);
    float vin = 1.0 - 0.45 * smoothstep(0.3, 0.95, length(v));
    vec3 cor = corBase.rgb + vin * (corNevoa.rgb * nevoa + corLuz.rgb * (1.0 - exp(-luz * 1.15)) * 1.05);

    // filme: arranhões verticais fixos, poeira e grão novo a cada quadro
    float px = uv.x * res.x;
    float arr = 0.0;
    for (int k = 0; k < 4; k++) {
        float xs = h11(float(k) * 7.3 + 1.0) * res.x;
        arr += exp(-abs(px - xs) / 0.7) * 0.05 * (0.6 + 0.4 * h11(floor(quadro / 3.0) + float(k))) * smoothstep(0.0, 0.3, fract(uv.y * 0.7 + h11(float(k))));
    }
    vec2 cel = floor(uv * res / 2.0);
    float suj = 0.0;
    {
        vec2 pp = vec2(uv.x * asp, uv.y);
        suj += fm.y * 0.022;                                               // manchas cinzas finas (da fumaça)
        float lote = floor(quadro / 15.0);
        for (int k = 0; k < 6; k++) {
            float sk = float(k) * 11.7 + lote * 3.3;
            vec2 c0 = vec2(h11(sk) * asp, h11(sk + 1.3));
            float an = h11(sk + 2.1) * 3.14159;
            vec2 dr = vec2(cos(an), sin(an));
            vec2 q = pp - c0;
            float al = dot(q, dr), la = dot(q, vec2(-dr.y, dr.x));
            float comp = mix(0.02, 0.12, h11(sk + 4.4));
            suj += exp(-abs(la) * res.y / 0.6) * step(abs(al), comp) * 0.06 * step(0.35, h11(sk + 7.0));
        }
    }
    float poeira = step(0.99965, h21(cel + floor(quadro / 8.0) * 7.13)) * 0.22;
    float gr = (h21(uv * res + fract(quadro * 0.6180339) * 917.0) - 0.5) * 0.034 * grao
             + (ruido(uv * res / 2.5 + quadro * 31.7) - 0.5) * 0.020 * grao;
    cor += vec3(arr + poeira + suj) * vec3(1.0, 0.85, 0.85) + gr * vec3(1.0, 0.6, 0.6);

    // glitch: tinta azul-arroxeada e riscos horizontais ciano/vermelho
    if (g > 0.0) {
        cor += vec3(0.03, 0.08, 0.19) * g * (0.8 + 0.4 * h21(cel + quadro));
        for (int k = 0; k < 9; k++) {
            float s = float(k) + floor(quadro) * 0.37;
            float yk = h11(s * 3.1 + 0.5);
            float x0 = h11(s * 5.3) * 0.6, x1 = x0 + mix(0.15, 0.55, h11(s * 9.7));
            float linha = (1.0 - smoothstep(0.0, 1.6 / res.y, abs(uv.y - yk))) * step(x0, uv.x) * step(uv.x, x1);
            vec3 cl = h11(s * 2.2) < 0.6 ? vec3(0.35, 0.95, 0.88) : vec3(1.0, 0.30, 0.35);
            cor = mix(cor, cl, linha * 0.75 * g);
        }
    }
    cor *= entrada;
    fragColor = vec4(clamp(cor, 0.0, 1.0), 1.0) * qt_Opacity;
}
