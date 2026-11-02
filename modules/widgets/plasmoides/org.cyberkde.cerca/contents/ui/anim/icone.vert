#version 440
// Só para o sandevistan poder desenhar fora do ícone: estica o quad do efeito "margem" px para cada lado.
// A camada do Qt amplia a textura com sourceRect, mas não o efeito. Com margem 0 é o vertex padrão.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
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

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    vec4 p = qt_Vertex;
    if (margem > 0.0) p.x = qt_MultiTexCoord0.x * tam.x - margem;
    gl_Position = qt_Matrix * p;
}
