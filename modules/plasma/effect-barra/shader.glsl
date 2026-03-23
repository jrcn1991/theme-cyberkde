// CyberKDE Barra — corpo do shader da barra superior ("filete neon").
// O cabeçalho (versão GLSL, entrada/saída) é acrescentado pelo gen_plasma.py, que gera
// barra_core.frag (GLSL 1.40) e barra.frag (legado), como o KWin espera.
//
// A textura inclui a sombra da barra: uFrameUV diz onde a barra fica dentro dela. Tudo é medido
// em pixels da barra (uFrameSize). As medidas são para a barra de 33 px e escalam com a altura:
// o ícone do menu iniciar tem 16 px e fica em x = 10, y = 9, ou seja, centro em (18, 17).

uniform sampler2D sampler;
uniform int textureWidth;
uniform int textureHeight;

uniform float uOn;        // 1 enquanto o efeito estiver aplicado
uniform vec3 uAccent;     // cor de destaque do tema (segue o "cyberkde cor")
uniform vec4 uFrameUV;    // barra dentro da textura: x, y, largura, altura (0..1)
uniform vec2 uFrameSize;  // tamanho da barra em pixels

// Cor da janela com alfa não pré-multiplicado; uv com y = 0 no topo.
vec4 texel(vec2 uv) {
  vec4 c = TEX(sampler, vec2(uv.x, 1.0 - uv.y));
  if (c.a > 0.0) {
    c.rgb /= c.a;
  }
  return c;
}

vec4 finish(vec4 c) {
  vec4 o = vec4(c.rgb * c.a, c.a);
  o = sourceEncodingToNitsInDestinationColorspace(o);
  return nitsToDestinationEncoding(o);
}

// Camada de cor `color` com opacidade `a` por cima de `dst` (alfa não pré-multiplicado).
vec4 over(vec4 dst, vec3 color, float a) {
  float outA = a + dst.a * (1.0 - a);
  if (outA <= 0.0) {
    return vec4(0.0);
  }
  return vec4((color * a + dst.rgb * dst.a * (1.0 - a)) / outA, outA);
}

// Distância a um retângulo com os quatro cantos chanfrados (negativa dentro).
float chamferBox(vec2 p, vec2 center, vec2 halfSize, float cut) {
  vec2 q = abs(p - center) - halfSize;
  return max(max(q.x, q.y), (q.x + q.y + cut) * 0.70710678);
}

void main() {
  vec2 uv = vec2(texcoord0.x, 1.0 - texcoord0.y);
  vec4 base = texel(uv);
  vec2 local = (uv - uFrameUV.xy) / uFrameUV.zw;  // 0..1 dentro da barra
  if (uOn < 0.5 || local.x < 0.0 || local.y < 0.0 || local.x > 1.0 || local.y > 1.0) {
    fragColor = finish(base);  // sombra e fora da barra: intocadas
    return;
  }
  vec2 pos = local * uFrameSize;
  float s = uFrameSize.y / 33.0;
  vec4 col = base;
  float fromBottom = uFrameSize.y - pos.y;  // ~0,5 no centro da última linha
  vec2 icon = vec2(18.0, 17.0) * s;
  float dx = pos.x - icon.x;
  float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
  float protect = 1.0 - smoothstep(0.35, 0.65, luma) * base.a;  // não tinge o ícone nem o texto

  // 1) Brilho que sobe da borda de baixo, centrado no menu iniciar.
  float glow = exp(-(dx * dx) / (2.0 * (26.0 * s) * (26.0 * s))) * exp(-fromBottom / (7.0 * s));
  col = over(col, uAccent, 0.5 * glow * protect);

  // 2) Quadro chanfrado em volta do ícone: fundo levemente tingido e contorno de 1 px.
  float d = chamferBox(pos, icon, vec2(13.0, 12.0) * s, 5.0 * s);
  float inside = 1.0 - smoothstep(-0.5, 0.5, d);
  col = over(col, uAccent, 0.08 * inside * protect);
  float ring = 1.0 - smoothstep(0.35, 1.0, abs(d + 0.5));
  col = over(col, uAccent, 0.9 * ring);

  // 3) Filete na borda de baixo: 1 px na barra toda, 2 px e mais forte perto do menu iniciar.
  float near = exp(-(dx * dx) / (2.0 * (40.0 * s) * (40.0 * s)));
  float line1 = 1.0 - smoothstep(1.0 * s - 0.5, 1.0 * s + 0.5, fromBottom);
  float line2 = (1.0 - smoothstep(2.0 * s - 0.5, 2.0 * s + 0.5, fromBottom)) * near;
  col = over(col, uAccent, max(0.75 * line1, line2));

  fragColor = finish(col);
}
