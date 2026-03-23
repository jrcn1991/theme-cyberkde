// CyberKDE Popups — corpo do shader. O cabeçalho (versão GLSL, entrada/saída) é acrescentado
// pelo gerador do módulo plasma, que grava popup_core.frag (GLSL 1.40) e popup.frag (legado),
// como o `cyberkde install` faz com o cyberkde_scan.
//
// uProgress = código * 2 + t (ver main.js): código = fechando * 16 + tipo * 4 + lado.
//   tipo 0 popup do Plasma: a superfície se revela a partir do acionador (A07), com filete de
//          varredura ciano na frente e brilho vermelho curto logo atrás;
//   tipo 1 notificação: cartão e texto surgem juntos (A12) e um filete atravessa a partir da borda;
//   tipo 2 menu: como o popup, com acentos mais discretos;
//   tipo 3 opacidade simples (dicas, contornos, splash).
// Fechamento: só perda de opacidade (o deslocamento vem do main.js). Todo acento some antes do
// fim, então o último quadro é idêntico à janela sem efeito.

uniform sampler2D sampler;
uniform int textureWidth;
uniform int textureHeight;

uniform float uProgress;
uniform vec3 uRed;       // vermelho de identidade
uniform vec3 uCyan;      // ciano da varredura

// Cor da janela com alfa não pré-multiplicado; uv com y = 0 no topo.
vec4 texel(vec2 uv) {
  vec4 c = TEX(sampler, vec2(uv.x, 1.0 - uv.y));
  if (c.a > 0.0) {
    c.rgb /= c.a;
  }
  return c;
}

void finish(vec3 rgb, float a) {
  fragColor = vec4(rgb * a, a);
  fragColor = sourceEncodingToNitsInDestinationColorspace(fragColor);
  fragColor = nitsToDestinationEncoding(fragColor);
}

void main() {
  vec2 size = vec2(float(textureWidth), float(textureHeight));
  vec2 uv = vec2(texcoord0.x, 1.0 - texcoord0.y);
  vec2 pos = uv * size;

  float code = floor(uProgress * 0.5 + 0.0001);
  float t = clamp(uProgress - 2.0 * code, 0.0, 1.0);
  float side = mod(code, 4.0);
  float kind = mod(floor(code / 4.0), 4.0);
  bool closing = code > 15.5;

  vec4 content = texel(uv);

  if (closing) {
    float p = 1.0 - t;
    finish(content.rgb, content.a * p * p * (3.0 - 2.0 * p));
    return;
  }

  float p = t;
  float e = 1.0 - pow(1.0 - p, 3.0);          // entrada: rápida no início, parada firme
  if (kind > 2.5) {
    finish(content.rgb, content.a * e);
    return;
  }

  // s = distância (px) a partir do lado do acionador; len = extensão nesse eixo.
  float s = pos.y;
  float len = size.y;
  if (side > 2.5) {
    s = size.x - pos.x;
    len = size.x;
  } else if (side > 1.5) {
    s = pos.x;
    len = size.x;
  } else if (side > 0.5) {
    s = size.y - pos.y;
  }
  bool alongX = side > 1.5;

  float settle = 1.0 - smoothstep(0.7, 1.0, p);  // acentos somem antes do fim
  bool notification = kind > 0.5 && kind < 1.5;
  float strength = kind > 1.5 ? 0.55 : 1.0;      // menus: acento mais discreto

  // Frente: revelação (popup/menu) ou filete que atravessa o cartão (notificação).
  float front = notification ? mix(-2.0, len + 2.0, smoothstep(0.08, 0.9, p))
                             : mix(-6.0, len + 6.0, e);
  float d = s - front;                           // < 0: atrás da frente (já revelado)

  // Separação de canais de no máximo 1 px junto da frente (acento curto, documento 13.6).
  float near = (1.0 - smoothstep(0.0, 10.0, abs(d))) * settle * strength;
  vec2 shift = alongX ? vec2(0.0, near / size.y) : vec2(near / size.x, 0.0);
  content.r = texel(uv + shift).r;
  content.b = texel(uv - shift).b;

  float a;
  if (notification) {
    a = content.a * smoothstep(0.0, 0.55, p);
  } else {
    float reveal = 1.0 - smoothstep(-3.0, 3.0, d);
    a = content.a * reveal * smoothstep(0.0, 0.3, p);
  }

  float line = (1.0 - smoothstep(0.0, 1.5, abs(d))) * settle * strength;
  float glow = (1.0 - smoothstep(0.0, 16.0, -d)) * step(d, 0.0) * settle * strength;
  vec3 col = mix(content.rgb, uRed, 0.14 * glow);
  col = mix(col, uCyan, 0.85 * line);
  a = max(a, line * content.a * smoothstep(0.0, 0.3, p));

  if (notification) {
    // Marcador de entrada: filete vermelho de 2 px na borda por onde o cartão chega.
    float mark = (1.0 - smoothstep(1.5, 2.5, s)) * settle;
    col = mix(col, uRed, mark * content.a);
  }

  finish(col, a);
}
