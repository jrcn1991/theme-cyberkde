// GERADO por modules/widgets/plasmoides/cerca-anim-gerar.py a partir de contents/animacoes-icones.json: não editar.
.pragma library

var LISTA = [
 {
  "id": "explosao",
  "padrao": true,
  "nome": "Explosão de dados",
  "nome_en": "Data burst",
  "descricao": "Um cartão abre de uma fenda no centro, rasga e estoura: os ícones voam em linha reta para a grade, freando, ligados por fios ao centro, e cada cartão acende em degraus no alerta enquanto o nome aparece por colunas. Ao sair, cada cartão acende e esmaga em fenda no lugar; o central fecha por último.",
  "descricao_en": "A card opens from a slit at the center, tears and bursts: icons fly straight to the grid, braking, wired to the center, and each card flickers into alert in steps while the name appears in columns. On exit each card lights up and collapses into a slit in place; the central card closes last.",
  "modoShader": 5,
  "modoCamada": 0
 },
 {
  "id": "explosao-limpa",
  "nome": "Explosão de dados · sem estouro",
  "nome_en": "Data burst · no blast",
  "descricao": "A mesma coreografia da explosão, sem o estouro: o cartão abre de uma fenda no centro e os ícones saem dele em voo reto, freando, com fios finos que se apagam; o nome aparece por colunas. Sem anel, faíscas nem alerta. Ao sair, cada cartão esmaga em fenda no lugar e o central fecha por último.",
  "descricao_en": "The same choreography as the burst, without the blast: a card opens from a slit at the center and icons fly straight out of it, braking, with thin wires that fade; the name appears in columns. No ring, sparks or alert. On exit each card collapses into a slit in place and the central card closes last.",
  "modoShader": -1,
  "modoCamada": 4
 },
 {
  "id": "explosao-toxica",
  "nome": "Explosão tóxica",
  "nome_en": "Toxic burst",
  "descricao": "O cartão central borbulha e solta um gás que se espalha da cerca, com bolhas e brilho que pulsa irregular. Os ícones voam já contaminados; ao assentar, a corrosão come o cartão de cada um, gotas escorrem e o ícone se limpa de cima para baixo. Ao sair, recontaminam e se desfazem no lugar.",
  "descricao_en": "The central card bubbles and releases a gas that spreads across the fence, with bubbles and an irregular, pulsing glow. Icons fly out already contaminated; as they settle, corrosion eats each card, drops run down and the icon cleans itself from the top down. On exit they get recontaminated and dissolve in place.",
  "modoShader": 11,
  "modoCamada": 5
 },
 {
  "id": "cascata",
  "nome": "Cascata",
  "nome_en": "Cascade",
  "descricao": "Linha a linha, com um leve atraso por coluna, os ícones descem e ligam em degraus, com um clarão na cor. Ao sair, recolhem de baixo para cima.",
  "descricao_en": "Row by row, with a slight delay per column, icons drop and switch on in steps, with a flash of color. On exit they retract from the bottom up.",
  "modoShader": 6
 },
 {
  "id": "decodificar",
  "nome": "Decodificação",
  "nome_en": "Decode",
  "descricao": "Cada ícone surge em blocos de bits que resolvem na imagem, em ordem embaralhada. Ao sair, volta aos blocos.",
  "descricao_en": "Each icon appears as blocks of bits that resolve into the image, in shuffled order. On exit it returns to blocks.",
  "modoShader": 0
 },
 {
  "id": "varredura",
  "nome": "Varredura",
  "nome_en": "Scan",
  "descricao": "Uma linha única atravessa a cerca e revela os ícones exatamente onde passa. Ao sair, ela sobe e os apaga.",
  "descricao_en": "A single line crosses the fence and reveals icons exactly where it passes. On exit it rises and erases them.",
  "modoShader": 1,
  "modoCamada": 1
 },
 {
  "id": "montagem",
  "nome": "Montagem",
  "nome_en": "Assembly",
  "descricao": "Cantos de mira, contorno em wireframe e preenchimento em fileiras. Ao sair, desmonta na ordem inversa.",
  "descricao_en": "Target corners, wireframe outline and row-by-row fill. On exit it comes apart in reverse.",
  "modoShader": 2
 },
 {
  "id": "glitch",
  "nome": "Glitch cromático",
  "nome_en": "Chromatic glitch",
  "descricao": "Os ícones entram com faixas deslocadas e franjas nas cores da paleta, e assentam em poucos degraus secos. Ao sair, desfazem do mesmo jeito.",
  "descricao_en": "Icons come in with displaced bands and fringes in the palette colors, settling in a few hard steps. On exit they break up the same way.",
  "modoShader": 3
 },
 {
  "id": "pixel",
  "nome": "Mosaico",
  "nome_en": "Mosaic",
  "descricao": "Blocos grandes tingidos em que a resolução dobra até o ícone ficar nítido. Ao sair, a resolução cai.",
  "descricao_en": "Large tinted blocks whose resolution doubles until the icon is sharp. On exit the resolution drops.",
  "modoShader": 4
 },
 {
  "id": "quickhack",
  "nome": "Quickhack",
  "nome_en": "Quickhack",
  "descricao": "Cada ícone é hackeado: a retícula trava no alvo em três degraus, a barra de upload sobe enquanto ele acende de baixo para cima, e a invasão termina num clarão. Ao sair, o upload volta e a retícula solta.",
  "descricao_en": "Each icon gets hacked: the reticle locks on in three steps, the upload bar fills as the icon lights up from the bottom, and the breach ends in a flash. On exit the upload rolls back and the reticle lets go.",
  "modoShader": 7
 },
 {
  "id": "braindance",
  "nome": "Braindance",
  "nome_en": "Braindance",
  "descricao": "Duas camadas de gravação atravessam a cerca em sentidos opostos, deixando os ícones como scans separados em duas cores; depois que as duas passam, eles se fundem, do meio para as bordas. Ao sair, as camadas voltam a se separar.",
  "descricao_en": "Two recording layers cross the fence in opposite directions, leaving icons as separate two-color scans; once both have passed, they merge, from the middle out. On exit the layers split apart again.",
  "modoShader": 8,
  "modoCamada": 2
 },
 {
  "id": "sandevistan",
  "nome": "Sandevistan",
  "nome_en": "Sandevistan",
  "descricao": "Os ícones disparam em linhas alternadas e o tempo quase para: o rastro de fantasmas fica no ar, em fatias, até o tempo voltar de uma vez. Ao sair, disparam adiante deixando o rastro.",
  "descricao_en": "Icons dash in alternating rows and time nearly stops: the ghost trail hangs in the air, in slices, until time snaps back. On exit they dash onward, leaving the trail behind.",
  "modoShader": 9,
  "modoCamada": 3
 },
 {
  "id": "nenhuma",
  "nome": "Nenhuma",
  "nome_en": "None",
  "descricao": "Os ícones aparecem direto.",
  "descricao_en": "Icons appear right away.",
  "modoShader": -1
 }
];

// a variante pelo id; desconhecida cai na padrão
function de(id) {
    var padrao = LISTA[0];
    for (var i = 0; i < LISTA.length; i++) {
        if (LISTA[i].id === id) return LISTA[i];
        if (LISTA[i].padrao) padrao = LISTA[i];
    }
    return padrao;
}
function lista() { return LISTA; }
