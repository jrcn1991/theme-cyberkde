#version 440
// Efeito por ícone das animações de ícones do Cyber Fence (AnimIcones.qml): vale só enquanto o ícone anima
// (layer do delegate). "q" vai de 0 (nada) a 1 (o ícone inteiro); "modo" é o modoShader de
// contents/animacoes-icones.json. Em q = 1 a saída é exatamente o ícone. Alfa pré-multiplicado.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;
    float margem;   // px além do item em cada lado (sandevistan; ver icone.vert)
    float q;
    float q2;       // 2ª camada (braindance)
    float modo;
    float semente;
    float flash;    // tinge o ícone na cor (só com flash > 0)
    float ab;       // franjas nas cores da paleta, em px (só com ab > 0); nunca canais RGB soltos
    vec3 gx;        // sandevistan: onde cada fantasma está em relação ao ícone (px)
    vec3 go;        // e a opacidade de cada um
    vec4 cor;
    vec4 cor2;
};
layout(binding = 1) uniform sampler2D fonte;

float h21(vec2 p) { vec3 r = fract(vec3(p.xyx) * 0.1031 + semente * 0.0171); r += dot(r, r.yzx + 33.33); return fract((r.x + r.y) * r.z); }
float e(float a, float b, float x) { return smoothstep(a, b, x); }
vec4 luz(vec3 c, float a) { return vec4(c * a, a); }
vec4 sobre(vec4 cima, vec4 baixo) { return cima + baixo * (1.0 - cima.a); }

float vn(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float cinza(vec4 c) { return dot(c.rgb, vec3(0.3, 0.59, 0.11)); }

void main() {
    vec2 uv = qt_TexCoord0, px = uv * tam;
    int m = int(modo + 0.5);
    vec4 c = texture(fonte, uv), r = c;
    if (m == 0) {                       // decodificar: blocos de bits que resolvem
        vec2 b = floor(px / 6.0), f = fract(px / 6.0);
        float h = h21(b) * 0.6, on = e(h, h + 0.04, q), ok = step(h + 0.32, q);
        float quadro = floor(q * 14.0), g = step(0.42, h21(b + quadro));
        float bit = step(0.34, h21(floor(f * 2.0) + b + quadro)) * step(f.x, 0.84) * step(f.y, 0.84);
        vec3 tom = step(0.86, h21(b + 5.0)) > 0.5 ? cor2.rgb : cor.rgb;
        r = sobre(c * ok, luz(tom, on * (1.0 - ok) * g * bit * step(0.02, texture(fonte, (b + 0.5) * 6.0 / tam).a)));
    } else if (m == 1) {                // varredura: a linha é a da camada; aqui, a borda de revelação na cor
        float faixa = (q - uv.y) * tam.y;
        r = c * step(0.0, faixa) + luz(cor.rgb, c.a * step(0.0, faixa) * (1.0 - step(5.0, faixa)) * 0.85 * (1.0 - step(1.0, q)));
    } else if (m == 2) {                // montagem: cantos, contorno que corre, preenchimento em fileiras
        vec2 d = 1.2 / tam, cc = abs(px - tam * 0.5);
        float a = c.a, viz = texture(fonte, uv + vec2(d.x, 0)).a + texture(fonte, uv - vec2(d.x, 0)).a + texture(fonte, uv + vec2(0, d.y)).a + texture(fonte, uv - vec2(0, d.y)).a;
        float borda = clamp(abs(a * 4.0 - viz), 0.0, 1.0);
        float tr = e(uv.y * 0.5 + uv.x * 0.2, uv.y * 0.5 + uv.x * 0.2 + 0.08, q * 1.3);
        float fileira = floor((1.0 - uv.y) * 7.0) / 7.0, fill = step(fileira, (q - 0.5) / 0.42);
        float hs = min(tam.x, tam.y) * 0.5 - 1.0;
        float canto = step(hs - 1.0, max(cc.x, cc.y)) * step(max(cc.x, cc.y), hs) * step(hs - 6.0, cc.x) * step(hs - 6.0, cc.y);
        r = sobre(luz(cor.rgb, canto * step(0.02, q) * (1.0 - step(0.86, q))), sobre(c * fill, luz(cor.rgb, borda * tr * (1.0 - e(0.8, 1.0, q)))));
    } else if (m == 3) {                // glitch: faixas deslocadas, em poucos degraus longos
        float t = floor(q * 5.0), fx = floor(px.y / 7.0), h = h21(vec2(t, fx));
        float of = step(0.55, h) * (1.0 - q) * (h - 0.75) * 0.5;
        r = texture(fonte, uv + vec2(of, 0)) * step(h21(vec2(fx, t + 9.0)), q * 1.7 + 0.1);
    } else if (m == 4) {                // pixel: blocos tingidos que dobram de resolução
        float n = floor((1.0 - q) * 4.0), b = pow(2.0, n + 1.0);
        if (q > 0.92) b = 1.0;
        vec4 s = texture(fonte, (floor(px / b) + 0.5) * b / tam);
        s.rgb = mix(s.rgb, cor.rgb * s.a, (1.0 - q) * 0.7);
        r = s * step(h21(floor(px / b) + n), q * 2.0);
    } else if (m == 5) {                // explosão: rasgo do voo; q = 1 parado
        float quadro = floor(semente * 3.0 + q * 16.0), lin = floor(px.y / 2.0), h = h21(vec2(lin, quadro));
        float of = (1.0 - q) * (h - 0.5) * 0.34 * step(0.45, h21(vec2(lin * 0.5, quadro)));
        r = texture(fonte, uv + vec2(of, 0));
        r *= 1.0 - (1.0 - q) * step(0.7, h);
        if (q < 1.0) { float g = cinza(r); r.rgb = mix(r.rgb, vec3(g), (1.0 - q) * 0.8); }
    } else if (m == 7) {                // quickhack: silhueta na cor; o upload acende o ícone de baixo para cima
        float linha = step(0.5, fract(px.y / 3.0));
        float sobe = step(1.0 - uv.y, q);
        r = sobre(c * sobe, luz(cor.rgb, c.a * (1.0 - sobe) * (0.16 + 0.26 * linha)));
    } else if (m == 8) {                // braindance: duas camadas de scan, uma de cada cor, que se fundem
        float lin = step(0.5, fract(px.y / 3.0));
        float sep = (1.0 - q) * 0.09, cA = texture(fonte, uv + vec2(sep, 0)).a, cB = texture(fonte, uv - vec2(sep, 0)).a;
        r = sobre(c * q, sobre(luz(cor.rgb, cA * q2 * (1.0 - q) * (0.25 + 0.6 * lin)), luz(cor2.rgb, cB * flash * (1.0 - q) * (0.25 + 0.6 * (1.0 - lin)))));
    } else if (m == 9) {                // sandevistan: até 3 fantasmas parados no ar, só a silhueta em fatias
        float lin = 0.45 + 0.55 * step(0.5, fract(px.y / 3.0));
        for (int k = 0; k < 3; k++) {
            float a = go[k] > 0.0 ? texture(fonte, uv - vec2(gx[k] / tam.x, 0)).a : 0.0;
            r = sobre(r, luz(k == 1 ? cor2.rgb : cor.rgb, a * go[k] * lin));
        }
    } else if (m == 11) {               // explosão tóxica: q = limpeza (0 contaminado), q2 = o que sobra (saída)
        float n = vn(px / 6.0 + semente) * 0.8 + vn(px / 2.5 + semente) * 0.2;
        vec2 o = 2.5 / tam;
        float viz = min(min(texture(fonte, uv + vec2(o.x, 0)).a, texture(fonte, uv - vec2(o.x, 0)).a),
                        min(texture(fonte, uv + vec2(0, o.y)).a, texture(fonte, uv - vec2(0, o.y)).a));
        float borda = c.a * (1.0 - viz);
        // a limpeza desce de cima, com frente irregular
        float sujo = step(0.0, uv.y - (q * 1.4 - 0.25) + (n - 0.5) * 0.35) * step(q, 0.999);
        float puls = 0.65 + 0.35 * h21(vec2(floor(q * 23.0 + semente), 3.0));
        vec3 tox = mix(cor2.rgb, cor.rgb, step(0.72, n)) * puls;
        r = c;
        r.rgb = mix(r.rgb, tox * c.a, sujo * 0.85);
        r *= 1.0 - borda * sujo * step(0.5, n);                  // a borda roída
        vec2 cel = floor(px / 5.0), f = fract(px / 5.0) - 0.5;    // bolhas na parte suja
        r = sobre(luz(cor2.rgb, step(abs(length(f) - 0.3), 0.09) * step(0.86, h21(cel + 3.0)) * c.a * sujo * 0.85), r);
        r *= step(1.0 - q2, (vn(px / 6.0 + semente * 3.0) * 0.8 + vn(px / 2.5) * 0.15) * (1.0 - 0.5 * borda) + 0.02);
    } else if (m == 10) {               // nome: colunas que acendem no lugar, sem mudar uma letra de posição
        vec2 b = vec2(floor(px.x / 5.0), floor(px.y / 18.0));
        r = c * step(h21(b), q * 1.02);
    }
    if (m != 8 && flash > 0.0) r.rgb = mix(r.rgb, cor.rgb * r.a, flash);
    if (ab > 0.0) {
        float dx = ab / tam.x, a1 = texture(fonte, uv + vec2(dx, 0)).a, a2 = texture(fonte, uv - vec2(dx, 0)).a;
        r = sobre(r, sobre(luz(cor.rgb, a1 * (1.0 - r.a) * 0.8), luz(cor2.rgb, a2 * (1.0 - r.a) * 0.8)));
    }
    fragColor = clamp(r, 0.0, 1.0) * qt_Opacity;
}
