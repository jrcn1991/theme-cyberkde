// CyberKDE Scan — corpo do shader de abertura/fechamento de janelas, com o catálogo de variantes.
// O cabeçalho (versão GLSL, entrada/saída) é acrescentado pelo `cyberkde install`,
// gerando scan_core.frag (GLSL 1.40) e scan.frag (legado, GLSL 1.10), como o KWin espera.
// Por isso: só literais float (1.0, nunca 1), sem operações de bits, sem %, sem switch.
//
// Cada variante recebe p = quanto da janela já existe (abrir: 0 → 1; fechar: 1 → 0), então o
// fechamento é a abertura ao contrário. Regras de todas: com p = 1 o resultado é exatamente a
// janela (sem salto no fim da abertura) e com p = 0 nada aparece. A lista (id, nome, tempos,
// referência) está em variantes.json; o número de cada uma é a posição nessa lista.

uniform sampler2D sampler;
uniform int textureWidth;
uniform int textureHeight;

uniform float uProgress;     // 0 → 1 ao longo da animação
uniform float uAbrir;        // 1 na abertura, 0 no fechamento (por janela)
uniform float uVariante;     // número da variante (por janela; o KWin só passa float)
uniform float uDuracao;      // duração em ms (por janela): o flicker anda em degraus de ~33 ms
uniform float uIntensidade;  // 0..1 (Intensidade/100); 0.6 é o padrão
uniform vec3 uFrameColor;    // destaque
uniform vec3 uScanColor;     // secundária
uniform vec3 uSurface;       // fundo / superfície escura

vec2 S = vec2(1.0);    // tamanho da janela em px
vec2 P = vec2(0.0);    // posição do pixel em px, y = 0 no topo
vec2 UV = vec2(0.0);   // 0..1, y = 0 no topo
float K = 1.0;   // multiplicador dos acentos: 1 no padrão, 0 sem acentos, 1,67 no máximo
float FR = 0.0;  // quadro de ~33 ms desde o começo da animação (glitch e flicker em degraus)

// Cor da janela com alfa não pré-multiplicado.
vec4 texel(vec2 uv) {
  vec4 c = TEX(sampler, vec2(uv.x, 1.0 - uv.y));
  if (c.a > 0.0) {
    c.rgb /= c.a;
  }
  return c;
}

// Igual, mas transparente fora da janela (para amostras deslocadas não esticarem a borda).
vec4 texelIn(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
    return vec4(0.0);
  }
  return texel(uv);
}

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float win(float a, float b, float x) {
  return clamp((x - a) / (b - a), 0.0, 1.0);
}

float eout(float t) {
  float u = 1.0 - t;
  return 1.0 - u * u * u;
}

// Flicker de liga/desliga das referências: 75 → 10 → 90 → 35 → 100 %, um degrau por quadro.
float flick(float f) {
  float m = mod(f, 5.0);
  if (m < 0.5) return 0.75;
  if (m < 1.5) return 0.1;
  if (m < 2.5) return 0.9;
  if (m < 3.5) return 0.35;
  return 1.0;
}

float edgeDist() {
  return min(min(P.x, S.x - P.x), min(P.y, S.y - P.y));
}

// ---------------------------------------------------------------------------------------------
// 0 scan — região de destino, moldura e varredura (a original, seção 12.2 do UI kit).
vec4 vScan(float p) {
  float settle = 1.0 - smoothstep(0.88, 1.0, p);
  float region = smoothstep(0.0, 0.22, p);
  float scanY = mix(-0.04, 1.04, smoothstep(0.12, 0.92, p)) * S.y;
  float d = P.y - scanY;
  float revealed = 1.0 - smoothstep(-1.0, 1.0, d);
  float near = (1.0 - smoothstep(0.0, 14.0, abs(d))) * settle;
  vec2 shift = vec2(2.0 * min(K, 1.0) * near / S.x, 0.0);
  vec4 content = texel(UV);
  content.r = texel(UV + shift).r;
  content.b = texel(UV - shift).b;
  float trama = step(mod(P.y, 3.0), 1.0) * 0.035;
  vec4 ghost = vec4(uSurface + trama, 0.92 * region * content.a);
  vec4 col = mix(ghost, content, revealed);
  float line = (1.0 - smoothstep(0.0, 1.5, abs(d))) * settle * region;
  float glow = (1.0 - smoothstep(0.0, 18.0, -d)) * step(d, 0.0) * settle * region;
  col.rgb = mix(col.rgb, uFrameColor, 0.16 * glow * K);
  col.rgb = mix(col.rgb, uScanColor, 0.9 * line);
  col.a = max(col.a, line * content.a);
  float dx = min(P.x, S.x - P.x);
  float dy = min(P.y, S.y - P.y);
  float outline = 1.0 - smoothstep(0.5, 1.5, min(dx, dy));
  float bracket = step(dx, 18.0) * step(dy, 18.0) * (1.0 - smoothstep(1.5, 2.5, min(dx, dy)));
  float frameA = max(0.7 * outline, bracket) * region * (1.0 - smoothstep(0.72, 1.0, p));
  col.rgb = mix(col.rgb, uFrameColor, frameA);
  col.a = max(col.a, frameA);
  return col;
}

// 1 moldura — a moldura é traçada linha a linha a partir de dois cantos, depois blocos acendem
// em degraus e cada bloco vira conteúdo ("Aniamção de janelas", 0,3–1,6 s).
vec4 vMoldura(float p) {
  vec4 content = texel(UV);
  float e = edgeDist();
  float t;  // posição ao longo do perímetro, sentido horário a partir do canto superior esquerdo
  if (e == P.y) {
    t = P.x;
  } else if (e == S.x - P.x) {
    t = S.x + P.y;
  } else if (e == S.y - P.y) {
    t = S.x + S.y + (S.x - P.x);
  } else {
    t = 2.0 * S.x + S.y + (S.y - P.y);
  }
  float halfL = S.x + S.y;
  float tt = mod(t, halfL);  // dois traçadores, um em cada canto oposto
  float head = halfL * eout(win(0.0, 0.38, p));
  float lit = step(tt, head);
  float line = 1.0 - smoothstep(1.0, 2.0, e);
  float frameA = line * lit * (1.0 - smoothstep(0.75, 1.0, p));
  float tip = line * lit * (1.0 - smoothstep(0.0, 28.0, head - tt)) * (1.0 - win(0.3, 0.45, p));

  float c = 40.0;
  vec2 cell = floor(P / c);
  vec2 cells = max(floor(S / c), vec2(1.0));
  float order = 0.6 * hash(cell) + 0.4 * 0.5 * (cell.x / cells.x + cell.y / cells.y);
  float tc = 0.22 + 0.48 * order;
  float s = win(tc, tc + 0.14, p);
  vec2 lp = P - cell * c;
  float inset = step(2.0, min(min(lp.x, c - lp.x), min(lp.y, c - lp.y)));
  vec4 col = vec4(uSurface, 0.5 * win(0.1, 0.3, p) * content.a);
  if (s > 0.0) {
    if (s < 0.35) {
      col = vec4(mix(uFrameColor, uScanColor, step(0.8, hash(cell + 3.1))), max(col.a, 0.85 * inset * content.a));
    } else {
      float u = win(0.35, 1.0, s);
      vec4 block = vec4(mix(uSurface, uFrameColor, 0.18 * K), content.a);
      col = mix(block, content, u);
    }
  }
  col.rgb = mix(col.rgb, uFrameColor, frameA);
  col.a = max(col.a, frameA);
  col.rgb = mix(col.rgb, uScanColor + 0.2, tip);
  col.a = max(col.a, tip);
  return col;
}

// 2 glitch — fatias horizontais deslocadas e canais RGB separados, novos a cada quadro
// ("Efeito de logo", 670–1030 ms), que assentam em degraus.
vec4 vGlitch(float p) {
  float g = pow(1.0 - p, 1.5) * K;
  float sh = 10.0 + 38.0 * hash(vec2(floor(P.y / 48.0), FR + 0.5));
  float slice = floor(P.y / sh);
  float move = step(0.5, hash(vec2(slice, FR + 7.0)));
  float off = (hash(vec2(slice, FR)) - 0.5) * 2.0 * 70.0 * g * move;
  float split = 10.0 * g;
  vec4 cg = texelIn(vec2((P.x - off) / S.x, UV.y));
  vec4 cr = texelIn(vec2((P.x - off - split) / S.x, UV.y));
  vec4 cb = texelIn(vec2((P.x - off + split) / S.x, UV.y));
  vec4 col = vec4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a) * 0.8));
  float bar = step(0.9, hash(vec2(slice, FR + 3.0))) * step(0.04, g);
  vec3 barColor = hash(vec2(slice, FR + 11.0)) > 0.5 ? uFrameColor : uScanColor;
  col.rgb = mix(col.rgb, barColor, bar * min(0.65, g));
  float drop = step(hash(vec2(FR, 1.7)), 0.25 * (1.0 - p));
  col.a *= smoothstep(0.0, 0.3, p) * mix(1.0, 0.35, drop);
  return col;
}

// 3 dados — a janela se desmonta em células de dados que sobem por colunas, ganhando as cores da
// cascata do Konsole (destaque → secundária → branco) e se apagando; abrir é o inverso.
vec4 vDados(float p) {
  float D = 1.0 - p;
  float c = 8.0;
  float cx = floor(P.x / c);
  float q = clamp(D * 1.7 - hash(vec2(cx, 9.1)) * 0.7, 0.0, 1.0);
  if (q <= 0.0) {
    return texel(UV);
  }
  float rise = q * q * (S.y * 0.6 + 120.0);
  vec2 src = vec2(P.x, P.y + rise);
  if (src.y >= S.y) {
    return vec4(0.0);
  }
  vec2 cell = floor(src / c);
  float th = 0.45 + 0.55 * hash(cell);
  float alive = 1.0 - smoothstep(th - 0.15, th, q * 1.15);
  vec4 crisp = texelIn(src / S);
  vec4 blocky = texelIn((cell + 0.5) * c / S);
  vec4 col = mix(crisp, blocky, smoothstep(0.0, 0.25, q));
  vec3 tint = q < 0.5 ? mix(uFrameColor, uScanColor, q * 2.0) : mix(uScanColor, vec3(1.0), (q - 0.5) * 2.0);
  col.rgb = mix(col.rgb, tint, smoothstep(0.05, 0.6, q) * 0.8 * min(K, 1.0));
  vec2 lp = src - cell * c;
  float gap = step(1.0, lp.y) * step(1.0, lp.x);
  col.a *= alive * mix(1.0, gap, smoothstep(0.05, 0.2, q));
  return col;
}

// 4 holograma — projeção que se abre a partir da linha do meio, tingida na secundária, com
// linhas de varredura, linhas que escorregam e o flicker de liga/desliga.
vec4 vHolograma(float p) {
  float e = eout(win(0.0, 0.8, p));
  float sy = mix(0.04, 1.0, e);
  float holo = 1.0 - smoothstep(0.7, 1.0, p);
  float top = (0.5 - 0.5 * sy) * S.y;
  float bot = (0.5 + 0.5 * sy) * S.y;
  float edge = max(1.0 - smoothstep(0.0, 2.0, abs(P.y - top)), 1.0 - smoothstep(0.0, 2.0, abs(P.y - bot))) * holo;
  float y = (UV.y - 0.5) / sy + 0.5;
  vec4 col = vec4(0.0);
  if (y >= 0.0 && y <= 1.0) {
    float jitter = step(0.965, hash(vec2(floor(P.y / 6.0), FR))) * 8.0 * K * holo;
    col = texelIn(vec2(UV.x + jitter / S.x, y));
    float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    col.rgb = mix(col.rgb, uScanColor * (0.35 + 1.1 * lum), 0.75 * holo * min(K, 1.0));
    float scan = 0.72 + 0.28 * step(1.0, mod(P.y, 3.0));
    col.rgb *= mix(1.0, scan, holo);
    float fl = p < 0.92 ? flick(FR) : 1.0;
    col.a *= mix(1.0, fl, holo) * smoothstep(0.0, 0.15, p);
  }
  col.rgb = mix(col.rgb, uScanColor * 1.2, edge);
  col.a = max(col.a, edge * 0.9 * smoothstep(0.0, 0.1, p));
  return col;
}

// 5 crt — boot de monitor: uma linha horizontal cresce do centro, abre na vertical
// superexposta e assenta; fechar é o "desligar a TV" (linha, depois ponto).
vec4 vCrt(float p) {
  float a1 = eout(win(0.0, 0.3, p));
  float a2 = eout(win(0.25, 0.85, p));
  float halfW = 0.5 * S.x * a1;
  float h = max(2.0, S.y * a2);
  float cy = 0.5 * S.y;
  float dy = abs(P.y - cy);
  float dx = abs(P.x - 0.5 * S.x);
  vec4 col = vec4(0.0);
  if (dx <= halfW && dy <= 0.5 * h) {
    col = texelIn(vec2(UV.x, (P.y - cy) / h + 0.5));
    float over = 1.0 - win(0.3, 0.9, p);
    col.rgb += (vec3(0.6) + uScanColor * 0.4) * over * over * 0.6 * min(K, 1.0);
    col.rgb *= mix(1.0, 0.8 + 0.2 * step(1.0, mod(P.y, 3.0)), over);
  }
  float line = (1.0 - smoothstep(1.0, 3.0, dy)) * step(dx, halfW) * (1.0 - a2);
  float bright = 1.0 - 0.6 * smoothstep(0.0, 0.5 * S.x, dx);
  col.rgb = mix(col.rgb, mix(uScanColor, vec3(1.0), 0.6) * bright, line);
  col.a = max(col.a, line * smoothstep(0.0, 0.05, p));
  return col;
}

// 6 decodificar — grade de células que acendem em ordem aleatória: cada uma mostra "código"
// piscando na secundária e então decodifica no conteúdo ("Animação de janelas 2", células da grade).
vec4 vDecodificar(float p) {
  vec4 content = texel(UV);
  float c = 24.0;
  vec2 cell = floor(P / c);
  float tc = 0.08 + 0.62 * hash(cell + 0.37);
  float s = win(tc, tc + 0.16, p);
  vec2 lp = P - cell * c;
  float grid = 1.0 - step(1.0, min(lp.x, lp.y));
  float region = win(0.0, 0.15, p) * (1.0 - smoothstep(0.8, 1.0, p));
  vec4 col = vec4(uSurface, 0.55 * region * content.a);
  col.rgb = mix(col.rgb, uFrameColor, grid * 0.6 * min(K, 1.0));
  col.a = max(col.a, grid * 0.5 * region * content.a);
  if (s > 0.0) {
    if (s < 0.5) {
      vec2 g = floor(lp / vec2(4.0, 6.0));
      float on = step(0.45, hash(g + cell * 7.0 + FR * 1.3));
      col = vec4(mix(uSurface, uScanColor, on * 0.9), max(col.a, 0.9 * content.a));
    } else {
      col = mix(col, content, win(0.5, 1.0, s));
    }
  }
  return col;
}

// 7 chanfro — cortina diagonal a 45°: uma faixa listrada no destaque, com fio brilhante na
// frente, varre do canto superior esquerdo ao inferior direito.
vec4 vChanfro(float p) {
  float L = S.x + S.y;
  float diag = (P.x + P.y) / L;
  float band = 36.0 / L;
  float f = mix(-band, 1.0 + band, eout(p));
  if (diag > f) {
    return vec4(0.0);
  }
  vec4 col = texel(UV);
  if (diag > f - band) {
    float stripes = step(0.5, fract((P.x - P.y) / 10.0));
    vec3 b = mix(uFrameColor, uSurface, stripes * 0.6);
    float front = 1.0 - smoothstep(0.0, 2.0 / L, f - diag);
    b = mix(b, uScanColor + 0.2, front);
    col = vec4(b, 0.95 * col.a);
  }
  return col;
}

// 8 braindance — distorção em onda e aberração cromática do editor de braindance, com a camada
// vermelha deslocada e uma faixa de rolagem; assenta na janela limpa.
vec4 vBraindance(float p) {
  float s = pow(1.0 - p, 1.3) * K;
  float wave = sin(P.y * 0.045 + FR * 0.9) * 14.0 * s + sin(P.y * 0.13 - FR * 1.7) * 4.0 * s;
  vec2 o = vec2(wave / S.x, 0.0);
  vec2 ab = (UV - 0.5) * 0.05 * s;
  vec4 cg = texelIn(UV + o);
  vec4 col = vec4(texelIn(UV + o + ab).r, cg.g, texelIn(UV + o - ab).b, cg.a);
  vec4 ghost = texelIn(UV + o + vec2(0.025 * s, 0.0));
  float gl = dot(ghost.rgb, vec3(0.333));
  col.rgb += uFrameColor * ghost.a * gl * 0.8 * s;
  col.a = max(col.a, ghost.a * 0.4 * s);
  float roll = 1.0 - smoothstep(0.0, 30.0, abs(P.y - fract(FR * 0.07) * S.y));
  col.rgb += uScanColor * roll * 0.25 * s;
  col.a *= smoothstep(0.0, 0.35, p);
  return col;
}

// 9 cacos — a janela se monta em losangos que crescem e giram até o lugar, do centro para fora;
// fechar é a quebra em cacos que encolhem girando.
vec4 vCacos(float p) {
  float D = 64.0;
  vec2 q = vec2(P.x + P.y, P.y - P.x) * 0.70710678;
  vec2 id = floor(q / D);
  vec2 lc = q / D - id - 0.5;
  vec2 cq = (id + 0.5) * D;
  vec2 cP = vec2(cq.x - cq.y, cq.x + cq.y) * 0.70710678;
  float dist = length(cP / S - 0.5);
  float tt = 0.05 + 0.4 * hash(id) + 0.3 * dist;
  float a = eout(win(tt, tt + 0.3, p));
  if (a <= 0.001) {
    return vec4(0.0);
  }
  float ang = (1.0 - a) * 1.2 * (hash(id + 5.0) - 0.5) * min(K, 1.5);
  float cs = cos(ang);
  float sn = sin(ang);
  vec2 ls = vec2(cs * lc.x - sn * lc.y, sn * lc.x + cs * lc.y) / a;
  if (abs(ls.x) > 0.5 || abs(ls.y) > 0.5) {
    return vec4(0.0);
  }
  vec2 sq = cq + ls * D;
  vec4 col = texelIn(vec2(sq.x - sq.y, sq.x + sq.y) * 0.70710678 / S);
  float edge = step(0.44, max(abs(ls.x), abs(ls.y)));
  col.rgb = mix(col.rgb, uScanColor, (1.0 - a) * 0.5 * min(K, 1.0));
  col.rgb = mix(col.rgb, uFrameColor, edge * (1.0 - a) * 0.9);
  col.a *= smoothstep(0.0, 0.3, a);
  return col;
}

// 10 convergir — feixes de dados horizontais correm das laterais e o conteúdo chega em fatias
// alternadas com franja ciano ("Efeito de logo": feixes → fatias com aberração → assenta).
vec4 vConvergir(float p) {
  float sl = floor(P.y / 14.0);
  float ts = 0.28 + 0.3 * hash(vec2(sl, 2.0));
  float e = eout(win(ts, ts + 0.4, p));
  float side = mod(sl, 2.0) < 1.0 ? -1.0 : 1.0;
  float off = (1.0 - e) * S.x * 0.7 * side;
  float fr = (1.0 - e) * 6.0 * K;
  vec2 u = vec2((P.x - off) / S.x, UV.y);
  vec4 col = texelIn(u);
  col.r = texelIn(u + vec2(fr / S.x, 0.0)).r;
  col.b = texelIn(u - vec2(fr / S.x, 0.0)).b;
  col.rgb = mix(col.rgb, uScanColor, (1.0 - e) * 0.35);
  col.a *= smoothstep(0.0, 0.15, e);
  float row = floor(P.y / 3.0);
  if (hash(vec2(row, 4.2)) > 0.82 && mod(P.y, 3.0) < 1.0) {
    float t0 = 0.3 * hash(vec2(row, 8.0));
    float l = eout(win(t0, t0 + 0.35, p));
    float x = hash(vec2(row, 1.3)) > 0.5 ? P.x : S.x - P.x;
    float head = l * S.x * 0.75;
    float on = step(x, head) * (1.0 - smoothstep(0.55, 0.8, p));
    float tail = smoothstep(head - S.x * 0.3, head, x);
    vec3 lc = hash(vec2(row, 6.0)) > 0.75 ? uFrameColor : uScanColor;
    float la = on * tail * 0.9 * min(K, 1.0);
    col.rgb = mix(col.rgb, lc + 0.3, la);
    col.a = max(col.a, la);
  }
  return col;
}

// 11 desintegrar — a janela se desfaz por um ruído com borda incandescente (branco → secundária →
// destaque) e faíscas soltas além da borda; abrir é a materialização.
vec4 vDesintegrar(float p) {
  float n = 0.62 * vnoise(P / 54.0) + 0.3 * vnoise(P / 14.0) + 0.08 * hash(floor(P / 2.0));
  float thr = mix(-0.12, 1.12, p);
  vec4 c = texel(UV);
  float w = 0.06;
  if (n < thr - w) {
    return c;
  }
  if (n < thr) {
    float t = (thr - n) / w;
    vec3 ec = mix(vec3(1.0), uScanColor, smoothstep(0.0, 0.5, t));
    ec = mix(ec, uFrameColor, smoothstep(0.5, 1.0, t));
    return vec4(mix(c.rgb, ec, (1.0 - t * t) * min(K, 1.0)), c.a);
  }
  float d = n - thr;
  if (d < 0.14) {
    vec2 g = floor(P / 2.0);
    float sp = step(0.94, hash(g + FR * 0.71)) * (1.0 - d / 0.14);
    return vec4(mix(uScanColor, uFrameColor, hash(g)), sp * c.a * min(K, 1.0));
  }
  return vec4(0.0);
}

// 12 terminal — de cima para baixo, linha a linha: um cursor de bloco digita cada linha
// ("Lista de Projetos", texto entrando linha a linha); fechar apaga de baixo para cima.
vec4 vTerminal(float p) {
  float rh = 18.0;
  float n = max(ceil(S.y / rh), 1.0);
  float i = floor(P.y / rh);
  float tr = 0.04 + 0.72 * (i / n);
  float s = win(tr, tr + 0.14, p);
  float sweep = s * (S.x + 12.0);
  vec4 c = texel(UV);
  float region = win(0.0, 0.08, p) * (1.0 - smoothstep(0.85, 1.0, p));
  vec4 col = vec4(uSurface, 0.6 * region * c.a);
  if (P.x < sweep - 12.0) {
    col = c;
  } else if (P.x < sweep && s < 1.0) {
    col = vec4(uScanColor, 0.9 * c.a);
  }
  float mark = step(P.x, 3.0) * step(0.001, s) * (1.0 - s) * min(K, 1.0);
  col.rgb = mix(col.rgb, uFrameColor, mark);
  col.a = max(col.a, mark * c.a);
  return col;
}

// 13 neon — a moldura acende como tubo de neon, falhando até firmar, com halo interno no destaque;
// o conteúdo entra com o flicker de liga/desliga.
vec4 vNeon(float p) {
  vec4 c = texel(UV);
  float e = edgeDist();
  float ign = win(0.0, 0.45, p);
  float on = ign >= 1.0 ? 1.0 : step(hash(vec2(FR, 3.3)), ign * 1.25);
  float fade = 1.0 - smoothstep(0.8, 1.0, p);
  float tube = (1.0 - smoothstep(2.0, 3.5, e)) * on * fade * smoothstep(0.0, 0.05, p);
  float glow = exp(-e / 10.0) * on * fade * 0.55 * min(K, 1.5) * smoothstep(0.0, 0.05, p);
  float cv = win(0.2, 0.85, p);
  float ca = cv >= 1.0 ? 1.0 : mix(flick(FR), 1.0, cv * cv) * win(0.15, 0.3, p);
  vec4 col = vec4(c.rgb, c.a * ca);
  col.rgb = mix(col.rgb, uFrameColor, glow);
  col.a = max(col.a, glow * c.a);
  col.rgb = mix(col.rgb, uFrameColor + 0.25, tube);
  col.a = max(col.a, tube * c.a);
  return col;
}

// 14 modal — a aba do título acende piscando, o corpo desce a partir dela com as laterais e a borda
// inferior em movimento, e o conteúdo surge em ruído ("Modal do Projeto", alt1 e alt2).
vec4 vModal(float p) {
  vec4 c = texel(UV);
  float th = 30.0;
  float a1 = win(0.0, 0.25, p);
  float tabFl = a1 >= 1.0 ? 1.0 : a1 * flick(FR);
  float drop = eout(win(0.2, 0.7, p));
  float accents = 1.0 - smoothstep(0.8, 1.0, p);
  float tabW = mix(S.x * 0.42, S.x, drop);
  float hv = th + (S.y - th) * drop;
  vec4 col = vec4(0.0);
  if (P.y < th) {
    if (P.x + max(0.0, P.y - th * 0.4) * accents < tabW) {
      col = vec4(mix(c.rgb, uFrameColor, (1.0 - drop) * 0.3 * min(K, 1.0)), c.a * tabFl);
    }
  } else if (P.y < hv) {
    float vis = step(hash(floor(P / 2.0)), win(0.45, 0.95, p) * 1.05);
    col = mix(vec4(uSurface, 0.85 * c.a), c, vis);
    float side = 1.0 - smoothstep(1.0, 2.0, min(P.x, S.x - P.x));
    float bottom = 1.0 - smoothstep(0.0, 2.0, abs(P.y - hv + 1.0));
    float ln = max(side * 0.8, bottom) * accents;
    col.rgb = mix(col.rgb, mix(uFrameColor, uScanColor, bottom), ln);
    col.a = max(col.a, ln * c.a);
  }
  return col;
}

// 15 pulso — a janela entra em faixas, de cima para baixo, cada uma num clarão da secundária que
// esfria até a cor real ("Modal do Projeto Alt2": o brilho percorre as fileiras).
vec4 vPulso(float p) {
  vec4 c = texel(UV);
  float nb = 6.0;
  float band = min(floor(P.y / (S.y / nb)), nb - 1.0);
  float tb = 0.04 + 0.55 * (band / nb);
  float s = win(tb, tb + 0.32, p);
  if (s <= 0.0) {
    return vec4(0.0);
  }
  float flash = (1.0 - s) * (1.0 - s);
  vec3 hot = c.rgb + uScanColor * 0.9 + 0.25;
  vec4 col = vec4(mix(c.rgb, hot, flash * 0.85 * min(K, 1.0)), c.a * smoothstep(0.0, 0.12, s));
  col.rgb *= mix(1.0, 0.8 + 0.2 * step(1.0, mod(P.y, 3.0)), flash);
  float mark = step(P.x, 4.0) * (1.0 - s);
  col.rgb = mix(col.rgb, uFrameColor, mark);
  col.a = max(col.a, mark * c.a);
  return col;
}

// 16 pixel — mosaico: blocos grandes tingidos no destaque aparecem e a resolução dobra em degraus
// (32 → 16 → 8 → 4 → 2 px) até a janela nítida.
vec4 vPixel(float p) {
  float e = win(0.1, 0.92, p);
  float lv = ceil(5.0 * (1.0 - e));
  float vis = step(hash(floor(P / 32.0) + 0.5), win(0.0, 0.35, p) * 1.05);
  if (lv < 0.5) {
    return texel(UV);
  }
  float bs = exp2(lv);
  vec2 b = floor(P / bs);
  vec4 col = texelIn((b + 0.5) * bs / S);
  col.rgb = mix(col.rgb, uFrameColor, (1.0 - e) * 0.25 * K);
  vec2 lp = P - b * bs;
  if (bs >= 4.0 && min(lp.x, lp.y) < 1.0) {
    col.rgb *= 0.6;
  }
  col.a *= vis;
  return col;
}

// 17 persiana — lâminas horizontais que se abrem do centro de cada uma, em cascata de cima para
// baixo, com a borda de cada lâmina no destaque.
vec4 vPersiana(float p) {
  float hs = 16.0;
  float n = max(ceil(S.y / hs), 1.0);
  float i = floor(P.y / hs);
  float ts = 0.45 * (i / n);
  float o = eout(win(ts, ts + 0.45, p));
  float ly = abs(P.y - i * hs - hs * 0.5);
  float open = o * hs * 0.5;
  if (o <= 0.0 || ly > open + 0.01) {
    return vec4(0.0);
  }
  vec4 col = texel(UV);
  float edge = 1.0 - smoothstep(0.0, 1.5, open - ly);
  col.rgb = mix(col.rgb, uFrameColor, edge * (1.0 - o) * min(K, 1.0));
  return col;
}

// 18 portas — duas metades entram pelas laterais e se encontram no meio, como portas blindadas,
// com a costura acesa na secundária.
vec4 vPortas(float p) {
  float e = eout(win(0.0, 0.85, p));
  float halfX = S.x * 0.5;
  bool left = P.x < halfX;
  float off = (1.0 - e) * halfX * (left ? -1.0 : 1.0);
  vec2 src = vec2(P.x - off, P.y);
  if ((left && src.x > halfX) || (!left && src.x < halfX)) {
    return vec4(0.0);
  }
  vec4 col = texelIn(src / S);
  float seam = (1.0 - smoothstep(0.0, 3.0, abs(src.x - halfX))) * (1.0 - smoothstep(0.85, 1.0, p));
  col.rgb = mix(col.rgb, uScanColor + 0.2, seam);
  float inner = (1.0 - smoothstep(0.0, 1.5, abs(src.x - halfX) - 0.5)) * (1.0 - e);
  col.rgb = mix(col.rgb, uFrameColor, inner * min(K, 1.0));
  col.a *= smoothstep(0.0, 0.1, p);
  return col;
}

// 19 radar — um ponteiro gira a partir do topo, revelando a janela como uma varredura de radar,
// com rastro na secundária.
vec4 vRadar(float p) {
  vec2 d = P - 0.5 * S;
  float a01 = fract(atan(d.x, -d.y) / 6.2831853 + 1.0);
  float sweep = smoothstep(0.0, 0.9, p);
  if (a01 > sweep) {
    return vec4(0.0);
  }
  vec4 col = texel(UV);
  float accents = 1.0 - smoothstep(0.85, 1.0, p);
  float trail = exp(-(sweep - a01) * 25.0) * accents;
  col.rgb = mix(col.rgb, uScanColor, trail * 0.6 * min(K, 1.0));
  float ang = sweep * 6.2831853;
  vec2 dir = vec2(sin(ang), -cos(ang));
  float perp = abs(d.x * dir.y - d.y * dir.x);
  float line = (1.0 - smoothstep(0.0, 2.0, perp)) * step(0.0, dot(d, dir)) * accents;
  col.rgb = mix(col.rgb, uFrameColor + 0.2, line);
  return col;
}

// 20 fade — só opacidade (movimento reduzido: sem deslocamento, varredura nem glitch).
vec4 vFade(float p) {
  vec4 col = texel(UV);
  col.a *= p;
  return col;
}

void main() {
  S = vec2(float(textureWidth), float(textureHeight));
  UV = vec2(texcoord0.x, 1.0 - texcoord0.y);
  P = UV * S;
  K = clamp(uIntensidade, 0.0, 1.0) / 0.6;
  FR = floor(uProgress * max(uDuracao, 1.0) / 33.0);
  float p = uAbrir > 0.5 ? uProgress : 1.0 - uProgress;
  float v = floor(uVariante + 0.5);

  vec4 col;
  if (v < 0.5) col = vScan(p);
  else if (v < 1.5) col = vMoldura(p);
  else if (v < 2.5) col = vGlitch(p);
  else if (v < 3.5) col = vDados(p);
  else if (v < 4.5) col = vHolograma(p);
  else if (v < 5.5) col = vCrt(p);
  else if (v < 6.5) col = vDecodificar(p);
  else if (v < 7.5) col = vChanfro(p);
  else if (v < 8.5) col = vBraindance(p);
  else if (v < 9.5) col = vCacos(p);
  else if (v < 10.5) col = vConvergir(p);
  else if (v < 11.5) col = vDesintegrar(p);
  else if (v < 12.5) col = vTerminal(p);
  else if (v < 13.5) col = vNeon(p);
  else if (v < 14.5) col = vModal(p);
  else if (v < 15.5) col = vPulso(p);
  else if (v < 16.5) col = vPixel(p);
  else if (v < 17.5) col = vPersiana(p);
  else if (v < 18.5) col = vPortas(p);
  else if (v < 19.5) col = vRadar(p);
  else col = vFade(p);

  col = clamp(col, 0.0, 1.0);
  fragColor = vec4(col.rgb * col.a, col.a);
  fragColor = sourceEncodingToNitsInDestinationColorspace(fragColor);
  fragColor = nitsToDestinationEncoding(fragColor);
}
