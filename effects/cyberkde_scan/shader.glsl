// CyberKDE Scan — corpo do shader de abertura/fechamento de janelas.
// O cabeçalho (versão GLSL, entrada/saída) é acrescentado pelo `cyberkde install`,
// gerando scan_core.frag (GLSL 1.40) e scan.frag (legado), como o KWin espera.
//
// Sequência (documento, seção 12.2): região de destino + moldura → varredura que
// revela o conteúdo de cima para baixo → estabilização. No fechamento, o inverso.

uniform sampler2D sampler;
uniform int textureWidth;
uniform int textureHeight;

uniform float uProgress;    // 0 → 1 ao longo da animação
uniform bool uForOpening;   // true na abertura, false no fechamento
uniform vec3 uFrameColor;   // vermelho de identidade
uniform vec3 uScanColor;    // ciano da varredura
uniform vec3 uSurface;      // superfície escura da região de destino

// Cor da janela com alfa não pré-multiplicado; uv com y = 0 no topo.
vec4 texel(vec2 uv) {
  vec4 c = TEX(sampler, vec2(uv.x, 1.0 - uv.y));
  if (c.a > 0.0) {
    c.rgb /= c.a;
  }
  return c;
}

void main() {
  vec2 size = vec2(float(textureWidth), float(textureHeight));
  vec2 uv = vec2(texcoord0.x, 1.0 - texcoord0.y);
  vec2 pos = uv * size;

  // p = quanto da janela já existe: abre 0 → 1, fecha 1 → 0.
  float p = uForOpening ? uProgress : 1.0 - uProgress;
  float settle = 1.0 - smoothstep(0.88, 1.0, p);  // acentos somem antes do fim

  // 1) Região de destino: superfície escura e moldura surgem primeiro.
  float region = smoothstep(0.0, 0.22, p);

  // 2) Faixa de varredura desce e revela o conteúdo acima dela.
  float scanY = mix(-0.04, 1.04, smoothstep(0.12, 0.92, p)) * size.y;
  float d = pos.y - scanY;  // < 0: já revelado
  float revealed = 1.0 - smoothstep(-1.0, 1.0, d);

  // Separação de canais de no máximo 2 px, só perto da faixa (glitch localizado).
  float near = (1.0 - smoothstep(0.0, 14.0, abs(d))) * settle;
  vec2 shift = vec2(2.0 * near / size.x, 0.0);
  vec4 content = texel(uv);
  content.r = texel(uv + shift).r;
  content.b = texel(uv - shift).b;

  // Conteúdo ainda não revelado: superfície escura com trama sutil de linhas.
  float trama = step(mod(pos.y, 3.0), 1.0) * 0.035;
  vec4 ghost = vec4(uSurface + trama, 0.92 * region * content.a);
  vec4 col = mix(ghost, content, revealed);

  // Faixa: linha ciano nítida + brilho vermelho curto acima dela.
  float line = (1.0 - smoothstep(0.0, 1.5, abs(d))) * settle * region;
  float glow = (1.0 - smoothstep(0.0, 18.0, -d)) * step(d, 0.0) * settle * region;
  col.rgb = mix(col.rgb, uFrameColor, 0.16 * glow);
  col.rgb = mix(col.rgb, uScanColor, 0.9 * line);
  col.a = max(col.a, line * content.a);

  // 3) Moldura de 1 px e brackets de 2 px nos cantos, só durante a transição.
  float dx = min(pos.x, size.x - pos.x);
  float dy = min(pos.y, size.y - pos.y);
  float outline = 1.0 - smoothstep(0.5, 1.5, min(dx, dy));
  float bracket = step(dx, 18.0) * step(dy, 18.0) * (1.0 - smoothstep(1.5, 2.5, min(dx, dy)));
  float frameA = max(0.7 * outline, bracket) * region * (1.0 - smoothstep(0.72, 1.0, p));
  col.rgb = mix(col.rgb, uFrameColor, frameA);
  col.a = max(col.a, frameA);

  fragColor = vec4(col.rgb * col.a, col.a);
  fragColor = sourceEncodingToNitsInDestinationColorspace(fragColor);
  fragColor = nitsToDestinationEncoding(fragColor);
}
