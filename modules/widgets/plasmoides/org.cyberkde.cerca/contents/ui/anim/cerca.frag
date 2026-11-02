#version 440
// Animações de exibição e ocultação do Cyber Fence (AnimacaoCerca.qml): um shader só, com uma variante
// por valor de "modo" (a ordem é a de contents/animacoes.json). "p" vai de 0 (nada) a 1 (a cerca inteira);
// em p = 1 a saída é exatamente o conteúdo. Saída = entrada ao contrário, e "saida" inverte o sentido das
// variantes que têm direção (a varredura sempre desce, por exemplo). A área do efeito passa do alvo
// "margem" px em cada lado, para o brilho e as peças soltas. Saída em alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;        // tamanho do alvo em px
    float margem;
    float p;
    float saida;     // 0 entrada, 1 saída
    float modo;
    float semente;
    vec4 cor;        // destaque
    vec4 cor2;       // secundária
};
layout(binding = 1) uniform sampler2D fonte;

const float CORTE = 12.0;     // chanfro da moldura (canto de cima à esquerda e de baixo à direita)

float h11(float q) { q = fract(q * 0.1031 + semente * 0.0173); q *= q + 33.33; q *= q + q; return fract(q); }
float h21(vec2 q) { vec3 r = fract(vec3(q.xyx) * 0.1031 + semente * 0.0173); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
float ruido(vec2 q) {
    vec2 i = floor(q), f = fract(q), u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 q) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * ruido(q); q = q * 2.03 + 7.1; a *= 0.5; }
    return v;
}
float e(float a, float b, float x) { return smoothstep(a, b, x); }
float sat(float x) { return clamp(x, 0.0, 1.0); }
// dentro do alvo (px em coordenadas do alvo)
vec4 amostra(vec2 px) {
    if (px.x < 0.0 || px.y < 0.0 || px.x > tam.x || px.y > tam.y) return vec4(0.0);
    return texture(fonte, px / tam);
}
vec4 luz(vec3 c, float a) { return vec4(c * a, a * 0.8); }     // quase aditiva, para somar ao conteúdo
vec4 sobre(vec4 cima, vec4 baixo) { return cima + baixo * (1.0 - cima.a); }

// distância com sinal à moldura chanfrada (< 0 dentro)
float sdCaixa(vec2 px, vec2 t) {
    vec2 c = t * 0.5, d = abs(px - c) - c;
    float caixa = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    float a = (CORTE - px.x - px.y) * 0.7071;                       // canto de cima à esquerda
    float b = (px.x + px.y - (t.x + t.y - CORTE)) * 0.7071;         // canto de baixo à direita
    return max(caixa, max(a, b));
}
float sdMoldura(vec2 px) { return sdCaixa(px, tam); }
// posição ao longo do contorno (0..1), partindo do canto de cima à esquerda, nos dois sentidos (como o Chanfro)
float contorno(vec2 px) {
    float w = tam.x, h = tam.y, dx = min(px.x, w - px.x), dy = min(px.y, h - px.y), s;
    if (dy < dx) s = px.y < h * 0.5 ? px.x : h + px.x;
    else s = px.x < w * 0.5 ? px.y : w + px.y;
    return sat(s / (w + h));
}
float borda(float sd, float larg) { return 1.0 - e(larg * 0.5, larg * 0.5 + 1.0, abs(sd)); }
float brilho(float sd, float r) { return exp(-max(sd, 0.0) / r) * step(0.0, sd) ; }

// ---- 0 traçado em linhas (GIF "Animação de janelas" do netwatch-os): o contorno chanfrado se traça do
// canto nos dois sentidos, com ponta brilhante e trechos soltos, e quadradinhos piscam (até ~0,5); a faixa do
// título e as divisões se traçam (0,38–0,66); o conteúdo acende em blocos, liga/desliga célula a célula (0,52–0,95)
void trecho(vec2 px, vec2 a, vec2 b, inout float dist, inout float s, inout float soma) {
    vec2 ab = b - a;
    float L = length(ab), u = clamp(dot(px - a, ab) / (L * L), 0.0, 1.0), d = length(px - a - ab * u);
    if (d < dist) { dist = d; s = soma + u * L; }
    soma += L;
}
vec4 tracado(vec2 px) {
    float w = tam.x, h = tam.y, c = min(CORTE, min(w, h) * 0.5), dist = 1e6, s = 0.0, L = 0.0;
    // o MESMO caminho do Chanfro.qml, a partir do canto cortado de cima à esquerda
    vec2 A = vec2(0.5, c + 0.5), B = vec2(c + 0.5, 0.5), C = vec2(w - 0.5, 0.5), D = vec2(w - 0.5, h - c - 0.5), E = vec2(w - c - 0.5, h - 0.5), F = vec2(0.5, h - 0.5);
    trecho(px, A, B, dist, s, L); trecho(px, B, C, dist, s, L); trecho(px, C, D, dist, s, L);
    trecho(px, D, E, dist, s, L); trecho(px, E, F, dist, s, L); trecho(px, F, A, dist, s, L);
    float t = min(s, L - s) / (L * 0.5);                        // 0 no canto … 1 onde os dois sentidos se encontram
    float tr = sat((p - 0.04) / 0.46), passo = floor(p * 36.0), ativo = step(0.001, p);
    float some = 1.0 - e(0.88, 1.0, p);
    float cel = floor(t * 44.0);
    // fica o traço até a ponta, com falhas logo atrás dela; à frente, trechos soltos que aparecem antes
    float atras = tr - t, frente = t - tr;
    float falha = step(0.34, h21(vec2(cel, passo)));
    float fio = step(0.0, atras) * mix(falha, 1.0, max(e(0.03, 0.10, atras), step(1.0, tr)));
    float solto = step(0.0, frente) * (1.0 - e(0.06, 0.15, frente)) * step(0.62, h21(vec2(cel, floor(passo * 0.5) + 5.0))) * step(tr, 0.999);
    float linha = 1.0 - e(0.55, 1.35, dist);
    float cab = exp(-abs(atras) * L * 0.5 / 7.0) * step(tr, 0.999);
    vec4 l = luz(cor.rgb, linha * (fio + solto * 0.8) * some * ativo * 0.95);
    l = sobre(luz(cor2.rgb, ((1.0 - e(1.0, 2.2, dist)) + exp(-dist / 4.0) * 0.45) * cab * ativo), l);
    float dentro = step(sdMoldura(px), -1.0);
    // quadradinhos soltos: contorno de 1 px em células escolhidas, 1–2 quadros cada
    vec2 cq = floor(px / 46.0), fq = px - (cq + 0.5) * 46.0;
    float hq = h21(cq + 11.0), iq = 0.08 + h21(cq + 3.0) * 0.36;
    float lado = 5.0 + 9.0 * h21(cq + 7.0);
    float quad = 1.0 - e(0.4, 1.1, abs(max(abs(fq.x), abs(fq.y)) - lado));
    float piscaq = step(hq, 0.20) * e(iq, iq + 0.005, p) * (1.0 - e(iq + 0.075, iq + 0.08, p));
    piscaq *= mix(1.0, step(0.3, h21(cq + passo)), 0.8);
    l = sobre(luz(cor.rgb, quad * piscaq * dentro * 0.85), l);
    // faixa do título (linha mais grossa, da esquerda) e divisões internas tracejadas
    float tf = sat((p - 0.38) / 0.18), yt = min(40.0, h * 0.4);
    float faixa = (1.0 - e(0.8, 1.6, abs(px.y - yt))) * step(px.x, tf * w) * step(0.001, tf);
    float faixaC = exp(-abs(px.x - tf * w) / 5.0) * (1.0 - e(1.0, 3.0, abs(px.y - yt))) * step(tf, 0.999) * step(0.001, tf);
    float nx = max(2.0, floor(w / 104.0)), ny = max(1.0, floor((h - yt) / 84.0));
    float q = (px.y - yt) / (h - yt), r = px.x / w;
    float dv = abs(fract(r * nx + 0.5) - 0.5) * w / nx, dh = abs(fract(q * ny + 0.5) - 0.5) * (h - yt) / ny;
    float tv = sat((p - 0.44) / 0.2);
    float tracoD = step(0.42, fract((px.x + px.y) / 12.0));
    float div = (1.0 - e(0.3, 1.0, min(dv, dh))) * step(0.0, q) * tracoD * step(dv < dh ? q : r, tv) * step(0.001, tv);
    float fimDiv = 1.0 - e(0.78, 0.96, p);
    l = sobre(luz(cor.rgb, faixa * 0.8 * some * dentro), l);
    l = sobre(luz(cor2.rgb, faixaC * dentro), l);
    l = sobre(luz(cor.rgb, div * 0.34 * fimDiv * dentro), l);
    // conteúdo em blocos: cada célula liga e desliga até firmar
    vec2 cc = floor(px / 20.0);
    float ini = 0.52 + h21(cc) * 0.33, on = step(ini, p);
    float firme = e(ini + 0.075, ini + 0.08, p);
    on *= mix(step(0.45, h21(cc + passo * 3.0)), 1.0, firme);
    vec4 col = amostra(px) * on;
    col = sobre(luz(cor.rgb, on * (1.0 - firme) * 0.32 * dentro), col);
    return sobre(l, col);
}
// ---- 1 moldura traçada: duas linhas saem do canto e se encontram; o conteúdo acende em blocos
vec4 moldura(vec2 px) {
    float sd = sdMoldura(px), tr = sat(p / 0.5), t = contorno(px);
    float feita = step(t, tr) * step(0.001, p);
    float some = 1.0 - e(0.82, 1.0, p);
    float cab = exp(-max(tr - t, 0.0) * 14.0) * feita * (1.0 - e(0.46, 0.56, p));
    vec4 l = luz(cor.rgb, (borda(sd, 1.6) * 0.95 + brilho(sd, 5.0) * 0.3) * feita * some);
    l = sobre(luz(cor2.rgb, (borda(sd, 2.6) + brilho(sd, 9.0) * 0.8) * cab), l);
    vec2 c = floor(px / 22.0);
    float r = h21(c), ini = 0.42 + r * 0.46, on = e(ini, ini + 0.06, p);
    float flash = on * (1.0 - e(ini + 0.06, ini + 0.14, p));
    vec4 col = amostra(px) * on;
    col = sobre(luz(cor.rgb, flash * 0.55 * step(sd, 0.0)), col);
    return sobre(l, col);
}
// ---- 2 varredura: uma faixa desce revelando (na saída, desce apagando)
vec4 varredura(vec2 px) {
    float y = px.y / tam.y, f = p * 1.28 - 0.14;
    float d = saida > 0.5 ? (1.0 - y) - f : y - f;       // < 0: revelado
    vec4 col = amostra(px) * (1.0 - e(-0.005, 0.005, d));
    float rastro = (1.0 - e(0.0, 0.16, -d)) * step(d, 0.0);
    float linha = exp(-abs(d) * tam.y / 2.2);
    float dentro = step(0.0, px.x) * step(px.x, tam.x);
    float forca = sat(p * 12.0) * (1.0 - e(0.9, 1.0, p));
    col = sobre(luz(cor.rgb, rastro * 0.32 * forca * step(sdMoldura(px), 0.0)), col);
    return sobre(luz(cor2.rgb, linha * forca * dentro), col);
}
// ---- 3 glitch RGB: fatias deslocadas e canais separados que assentam em degraus
vec4 glitch(vec2 px) {
    float t = floor(p * 11.0), res = (1.0 - p) * (1.0 - p);
    float hs = 10.0 + 22.0 * h11(t + 3.0), i = floor(px.y / hs);
    float of = (h21(vec2(i, t)) - 0.5) * 90.0 * res * step(0.35, h21(vec2(i + 9.0, t)));
    float on = step(h21(vec2(i, t * 0.5 + 2.0)), p * 1.7 - 0.2);
    float d = 2.0 + 16.0 * res;
    vec2 q = px + vec2(of, 0.0);
    vec4 a = amostra(q + vec2(d, 0.0)), b = amostra(q), c = amostra(q - vec2(d, 0.0));
    float fim = e(0.86, 1.0, p);
    vec4 col = vec4(a.r, b.g, c.b, max(a.a, max(b.a, c.a)));
    col = mix(col, b, fim);
    return col * on;
}
// ---- 4 CRT: uma linha cresce do centro e abre na vertical; a saída colapsa na linha e no ponto
vec4 crt(vec2 px) {
    vec2 st = px / tam - 0.5;
    float hw = e(0.0, 0.30, p), v = max(e(0.26, 0.82, p), 0.004);
    float mx = step(abs(st.x), hw * 0.5 + 0.001), my = step(abs(st.y), v * 0.5);
    vec4 col = amostra(vec2(px.x, (st.y / v + 0.5) * tam.y)) * mx * my * e(0.26, 0.5, p);
    float clarao = (1.0 - e(0.3, 1.0, p));
    float linhas = 0.86 + 0.14 * sin(px.y * 2.2);
    col.rgb *= mix(1.0, linhas, 1.0 - e(0.8, 1.0, p));
    col.rgb += col.a * cor2.rgb * clarao * 0.65;
    float fio = exp(-abs(abs(st.y) - v * 0.5) * tam.y / 1.8) * mx * sat(p * 14.0) * (1.0 - e(0.72, 0.92, p));
    return sobre(luz(mix(cor.rgb, cor2.rgb, 0.6), fio), col);
}
// ---- 5 decodificar: células acendem em ordem aleatória, piscando código antes do conteúdo
vec4 decodificar(vec2 px) {
    vec2 c = floor(px / 16.0), f = fract(px / 16.0);
    float r = h21(c) * 0.68, a = e(r, r + 0.02, p), b = e(r + 0.16, r + 0.20, p);
    float t = floor(p * 26.0);
    vec2 g = floor(f * vec2(4.0, 5.0));
    float gl = step(0.5, h21(g + c * 7.0 + t)) * step(0.12, f.x) * step(f.x, 0.88) * step(0.12, f.y) * step(f.y, 0.88);
    float dentro = step(sdMoldura(px), 0.0);
    vec4 col = amostra(px) * b;
    return sobre(luz(mix(cor.rgb, cor2.rgb, h21(c + 3.0) * 0.5), gl * a * (1.0 - b) * 0.9 * dentro), col);
}
// ---- 6 holograma: projeção que abre da linha do meio, tingida, com linhas e cintilação
vec4 holograma(vec2 px) {
    float y = abs(px.y / tam.y - 0.5), ab = e(0.0, 0.62, p), my = 1.0 - e(ab * 0.5 - 0.004, ab * 0.5 + 0.004, y);
    float t = floor(p * 32.0), tinta = 1.0 - e(0.6, 1.0, p);
    float pis = mix(0.72 + 0.28 * h11(t), 1.0, e(0.8, 1.0, p));
    float of = (h21(vec2(floor(px.y / 7.0), t)) - 0.5) * 7.0 * tinta;
    vec4 tx = amostra(px + vec2(of, 0.0));
    float lum = dot(tx.rgb, vec3(0.3, 0.6, 0.1));
    vec3 hol = cor2.rgb * (lum * 0.8 + tx.a * 0.12) * (0.75 + 0.25 * sin(px.y * 1.9));
    vec4 col = vec4(mix(tx.rgb, hol, tinta), tx.a) * my * pis * e(0.04, 0.3, p);
    float fio = exp(-abs(y - ab * 0.5) * tam.y / 2.0) * step(0.0, px.x) * step(px.x, tam.x) * sat(p * 12.0) * (1.0 - e(0.56, 0.72, p));
    return sobre(luz(cor2.rgb, fio), col);
}
// ---- 7 cacos: losangos que crescem do centro para fora (na saída, de fora para o centro)
vec4 cacos(vec2 px) {
    float c = 44.0;
    vec2 uv = vec2(px.x + px.y, px.x - px.y) / c, id = floor(uv), f = fract(uv) - 0.5;
    vec2 cw = vec2(id.x + id.y + 1.0, id.x - id.y) * c * 0.5;
    float d = length((cw - tam * 0.5) / tam) * 1.25;
    float r = h21(id) * 0.18;
    float q = sat((p * 1.55 - (saida > 0.5 ? 1.0 - sat(d) : sat(d)) * 0.55 - r) / 0.62);
    float g = q * 0.56, md = max(abs(f.x), abs(f.y));
    float on = 1.0 - e(g - 0.012, g, md);
    float aresta = on * e(g - 0.05, g - 0.012, md) * (1.0 - e(0.7, 1.0, q)) * step(0.001, q);
    vec4 col = amostra(px) * on * step(0.001, q);
    return sobre(luz(cor.rgb, aresta * 0.85 * step(sdMoldura(px), 0.0)), col);
}
// ---- 8 desintegrar: desfaz com borda incandescente e faíscas (ao entrar, materializa)
vec4 desintegrar(vec2 px) {
    float n = fbm(px / 34.0 + 3.0) * 0.82 + 0.09 * h21(floor(px / 3.0));
    float th = p * 1.25 - 0.13, d = th - n;
    float on = e(-0.012, 0.012, d);
    float brasa = (1.0 - e(0.0, 0.028, abs(d))) * 0.9;
    float forca = sat(p * 10.0) * (1.0 - e(0.9, 1.0, p)) * step(sdMoldura(px), 2.0);
    vec4 col = amostra(px) * on;
    col = sobre(luz(mix(cor.rgb, cor2.rgb, e(0.03, 0.0, abs(d))), brasa * forca), col);
    vec2 g = floor(vec2(px.x, px.y + (1.0 - p) * 46.0) / 5.0);
    float fa = step(0.975, h21(g)) * (1.0 - e(0.0, 0.1, abs(d + 0.03)));
    return sobre(luz(cor2.rgb, fa * forca), col);
}
// ---- 9 persiana: lâminas que abrem do meio, em cascata de cima para baixo
vec4 persiana(vec2 px) {
    float al = 24.0, i = floor(px.y / al), y = fract(px.y / al) - 0.5, n = max(1.0, floor(tam.y / al));
    float pos = sat(i / n);
    if (saida > 0.5) pos = 1.0 - pos;
    float q = sat(p * 1.55 - pos * 0.55);
    float on = 1.0 - e(q * 0.5 - 0.02, q * 0.5 + 0.001, abs(y));
    float fio = exp(-abs(abs(y) - q * 0.5) * al / 1.3) * (1.0 - e(0.7, 1.0, q)) * step(0.001, q);
    vec4 col = amostra(px) * on * step(0.001, q);
    return sobre(luz(cor.rgb, fio * 0.8 * step(sdMoldura(px), 0.0)), col);
}
// ---- 10 pixel: blocos grandes tingidos em que a resolução dobra em degraus
vec4 pixel(vec2 px) {
    float n = floor((1.0 - p) * 6.0), b = pow(2.0, n + 1.0);
    if (n < 0.5 && p > 0.9) b = 1.0;
    vec2 c = floor(px / b), q = (c + 0.5) * b;
    vec4 col = amostra(q);
    float on = step(h21(c + n), p * 1.9);
    float tinta = (1.0 - p) * 0.75;
    col.rgb = mix(col.rgb, cor.rgb * col.a, tinta);
    float base = step(sdMoldura(q), 0.0) * (1.0 - e(0.5, 0.9, p)) * 0.5;
    return sobre(col * on, luz(cor.rgb, base * on * step(0.001, p)));
}
// ---- 11 neon: a moldura acende como um tubo, falhando até firmar, e o conteúdo entra piscando
vec4 neon(vec2 px) {
    float sd = sdMoldura(px), t = floor(p * 15.0);
    float tubo = step(h11(t + 1.0) * 0.62, p * 1.5) * e(0.0, 0.08, p);
    float cont = step(h11(t * 1.7 + 5.0) * 0.55, (p - 0.42) * 2.4) * e(0.42, 0.5, p);
    cont = mix(cont, 1.0, e(0.82, 0.95, p));
    float some = 1.0 - e(0.84, 1.0, p);
    vec4 col = amostra(px) * cont;
    float g = borda(sd, 2.0) + exp(-abs(sd) / 5.0) * 0.5 + exp(-abs(sd) / 15.0) * 0.26;
    vec4 l = luz(mix(cor.rgb, vec3(1.0), borda(sd, 1.0) * 0.5), g * tubo * some);
    return sobre(l, col);
}
// ---- 12 cascata: em sequência entre as cercas; cada uma entra deslizando atrás de uma frente em ponta
vec4 cascata(vec2 px) {
    float dir = saida > 0.5 ? -1.0 : 1.0;
    float q = 1.0 - pow(1.0 - p, 3.0);
    vec2 s = px + vec2((1.0 - q) * 46.0 * dir, 0.0);
    float x = saida > 0.5 ? tam.x - px.x : px.x;
    float ponta = abs(px.y / tam.y - 0.5) * 34.0;
    float d = (x + ponta) / (tam.x + 34.0) - (p * 1.2 - 0.1);
    vec4 col = amostra(s) * (1.0 - e(-0.008, 0.008, d));
    float fio = exp(-abs(d) * tam.x / 2.4) * sat(p * 12.0) * (1.0 - e(0.86, 1.0, p)) * step(-1.0, px.y) * step(px.y, tam.y + 1.0);
    float rastro = step(d, 0.0) * (1.0 - e(0.0, 0.3, -d)) * 0.2 * (1.0 - e(0.86, 1.0, p));
    col = sobre(luz(cor.rgb, rastro * step(sdMoldura(s), 0.0)), col);
    return sobre(luz(cor2.rgb, fio), col);
}
// ---- 13 chanfro: uma faixa diagonal listrada, com fio de luz na frente, varre de um canto ao outro
vec4 chanfro(vec2 px) {
    float d = (px.x + px.y) / (tam.x + tam.y);
    if (saida > 0.5) d = 1.0 - d;
    float f = p * 1.34 - 0.17, x = d - f;                       // < 0: revelado
    vec4 col = amostra(px) * (1.0 - e(-0.15, -0.145, x));
    float lista = step(0.5, fract((px.x + px.y) / 16.0));
    float faixa = (1.0 - e(-0.002, 0.002, x)) * e(-0.152, -0.147, x);
    float forca = sat(p * 12.0) * (1.0 - e(0.9, 1.0, p)) * step(sdMoldura(px), 0.0);
    col = sobre(luz(cor.rgb, faixa * lista * 0.9 * forca), col);
    return sobre(luz(cor2.rgb, exp(-abs(x) * (tam.x + tam.y) / 2.4) * forca), col);
}
// ---- 14 cascata em pilha (GIF "Modal do Projeto alt1" do netwatch-os, medido a ~33 ms por quadro): a cabeça
// entra sozinha deslizando 28 px da direita (~200 ms, freando), espera ~60 ms; o corpo desce dela (~300 ms,
// freando) com a moldura crescendo e o conteúdo acende de cima para baixo. Dois ecos do contorno, 14 e 28 px
// para baixo e à esquerda, lembram as cartas de baixo (o painel seguinte nasce a +28, -26 px do anterior).
vec4 empilhar(vec2 px) {
    float w = tam.x, h = tam.y, hc = min(40.0, h);
    float ph = sat(p / 0.32), s = 1.0 - pow(1.0 - ph, 3.0);
    float gb = sat((p - 0.38) / 0.5);
    float by = mix(hc, h, 1.0 - pow(1.0 - gb, 2.4));
    vec2 q = px - vec2((1.0 - s) * 28.0, 0.0);
    float sd = sdCaixa(q, vec2(w, by)), dentro = step(sd, 0.0), ativo = step(0.001, p);
    float aparece = e(0.0, 0.14, p) * mix(0.55 + 0.45 * step(0.4, h11(floor(p * 40.0))), 1.0, e(0.2, 0.3, p));
    // conteúdo: de cima para baixo; a cabeça (o título) vem junto com ela
    float fy = (q.y - hc) / max(1.0, h - hc), fr = sat((p - 0.40) / 0.60) * 1.4;
    float c = q.y < hc ? 1.0 : 1.0 - e(fr - 0.4, fr, fy);
    vec4 col = amostra(q) * dentro * c * aparece;
    vec4 fundo = vec4(mix(vec3(0.05), cor.rgb, 0.13), 1.0) * 0.92 * dentro * aparece * (1.0 - e(0.9, 1.0, p));
    col = sobre(col, fundo);
    float fim = 1.0 - e(0.9, 1.0, p);
    vec4 l = luz(cor.rgb, borda(sd, 1.2) * fim * aparece * 0.95);
    float aba = (1.0 - e(0.6, 1.4, abs(q.y - hc))) * step(0.0, q.x) * step(q.x, w) * (1.0 - e(0.1, 0.5, gb));
    l = sobre(luz(cor.rgb, aba * aparece), l);
    float base = exp(-abs(q.y - by) / 2.0) * step(0.0, q.x) * step(q.x, w) * step(0.001, gb) * (1.0 - e(0.72, 1.0, gb));
    l = sobre(luz(cor2.rgb, base * 0.9), l);
    vec4 r = sobre(l, col);
    // ecos: só fora da cerca
    float jan = e(0.08, 0.3, p) * (1.0 - e(0.7, 0.96, p)) * step(0.0, sd);
    float eco1 = borda(sdCaixa(q + vec2(14.0, -13.0), vec2(w, by)), 1.0) * 0.5;
    float eco2 = borda(sdCaixa(q + vec2(28.0, -26.0), vec2(w, by)), 1.0) * 0.28;
    return sobre(r, luz(cor.rgb, max(eco1, eco2) * jan * ativo));
}
// ---- 15 dissolução: só opacidade (a do movimento reduzido)
vec4 dissolucao(vec2 px) { return amostra(px) * p; }

void main() {
    vec2 px = qt_TexCoord0 * (tam + 2.0 * margem) - margem;
    int m = int(modo + 0.5);
    vec4 c;
    if (m == 0) c = tracado(px);
    else if (m == 1) c = moldura(px);
    else if (m == 2) c = varredura(px);
    else if (m == 3) c = glitch(px);
    else if (m == 4) c = crt(px);
    else if (m == 5) c = decodificar(px);
    else if (m == 6) c = holograma(px);
    else if (m == 7) c = cacos(px);
    else if (m == 8) c = desintegrar(px);
    else if (m == 9) c = persiana(px);
    else if (m == 10) c = pixel(px);
    else if (m == 11) c = neon(px);
    else if (m == 12) c = cascata(px);
    else if (m == 13) c = chanfro(px);
    else if (m == 14) c = empilhar(px);
    else c = dissolucao(px);
    fragColor = clamp(c, 0.0, 1.0) * qt_Opacity;
}
