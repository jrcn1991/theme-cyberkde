#version 440
// Logo/emblema da corporação numa cor só, em dois tons: a parte mais clara do desenho na cor cheia, a mais escura
// a 38%, para o recorte interno (as folhas da Biotechnica, o olho da NetWatch) não virar uma mancha. "lo" e "hi" são
// as luminâncias das cores do SVG; com hi <= lo (uma cor só), tudo na cor cheia.
// "orig" = 1 (CorLogo original): as cores do próprio arquivo; onde o desenho é escuro (sumiria no fundo), um contorno de ~1,5 px e um
// leve clarão na "cor", para nenhum logo desaparecer. "cor.a" segue valendo como opacidade.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 cor;
    float lo;
    float hi;
    float orig;
    vec2 tam;
};
layout(binding = 1) uniform sampler2D fonte;
float lum(vec4 s) { return s.a > 0.0 ? dot(s.rgb / s.a, vec3(0.3, 0.59, 0.11)) : 1.0; }
void main() {
    vec4 s = texture(fonte, qt_TexCoord0);
    if (orig > 0.5) {
        vec2 o = 1.5 / max(tam, vec2(1.0)), uv = qt_TexCoord0;
        vec4 n1 = texture(fonte, uv + vec2(o.x, 0)), n2 = texture(fonte, uv - vec2(o.x, 0));
        vec4 n3 = texture(fonte, uv + vec2(0, o.y)), n4 = texture(fonte, uv - vec2(0, o.y));
        float viz = max(max(n1.a, n2.a), max(n3.a, n4.a));
        // quão escuro é o desenho em volta: claro (o vermelho da Arasaka, o amarelo da Militech) não ganha contorno
        float lv = (lum(n1) * n1.a + lum(n2) * n2.a + lum(n3) * n3.a + lum(n4) * n4.a) / max(n1.a + n2.a + n3.a + n4.a, 0.001);
        float escuro = 1.0 - smoothstep(0.12, 0.4, lv);
        float borda = clamp(viz - s.a, 0.0, 1.0) * escuro * 0.75;
        vec4 r = s;
        r.rgb += cor.rgb * s.a * 0.14 * (1.0 - smoothstep(0.12, 0.4, lum(s)));
        r += vec4(cor.rgb, 1.0) * borda * (1.0 - r.a);
        fragColor = r * cor.a * qt_Opacity;
        return;
    }
    float a = s.a, tom = 1.0;
    if (hi > lo && a > 0.0) {
        vec3 c = s.rgb / a;
        tom = mix(0.38, 1.0, clamp((dot(c, vec3(0.3, 0.59, 0.11)) - lo) / (hi - lo), 0.0, 1.0));
    }
    fragColor = vec4(cor.rgb, 1.0) * cor.a * a * tom * qt_Opacity;
}
