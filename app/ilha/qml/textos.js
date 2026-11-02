// A interface da ilha: chave = o texto em português.
.pragma library
var EN = {
"Início":"Home","Painéis":"Panels","Gaveta":"Shelf","Janelas":"Windows","Avisos":"Notices","Cópias":"Copies","Nota":"Note","Claude":"Claude",
"{n} downloads":"{n} downloads","Microfone":"Microphone","Segurar aberta":"Keep open","Soltar (fecha quando o mouse sai)":"Release (closes when the mouse leaves)",
"Não perturbe":"Do not disturb","Cafeína: manter a tela acordada":"Caffeine: keep the screen awake","Nada tocando":"Nothing playing","abra um player e ele aparece aqui":"open a player and it shows up here",
"Silêncio":"Silence","não perturbe":"do not disturb","notificações":"notifications","desligado":"off","ligado":"on","Som: mudo":"Sound: muted","Silenciar o som":"Mute sound",
"Microfone: mudo":"Mic: muted","Silenciar o microfone":"Mute mic","Mostrar a área de trabalho":"Show desktop","Capturar a tela (Spectacle)":"Screenshot (Spectacle)","Bloquear a tela agora":"Lock screen now",
"Temporizador":"Timer","Cronômetro":"Stopwatch","contando":"counting","{n} min":"{n} min","25 · foco":"25 · focus","Parar":"Stop","Voltar":"Back","sem dado":"no data",
"Cafeína por":"Caffeine for","{n} h":"{n} h","Abrir":"Open","Tirar da gaveta":"Remove from shelf","Enviar para {celular} (KDE Connect)":"Send to {celular} (KDE Connect)","Ler o texto da imagem (OCR) e copiar":"Read image text (OCR) and copy",
"Arraste arquivos, texto ou endereços para a pílula e eles ficam aqui":"Drag files, text or addresses onto the pill and they stay here",
"As notificações que os aplicativos mandarem ficam aqui":"Notifications from apps stay here","Recentes":"Recent","Limpar":"Clear","sistema":"system","Dispensar":"Dismiss",
"O que você copiar aparece aqui, para pegar de volta depois":"What you copy shows up here, to grab again later","Buscar nas cópias…":"Search copies…","Nada com esse texto":"Nothing with that text",
"Copiar de novo":"Copy again","Soltar":"Unpin","Fixar":"Pin","Tirar do histórico":"Remove from history","Limpar · fixados ficam":"Clear · pinned stay",
"Anote algo — fica guardado na ilha.":"Jot something down: it stays on the island.","guardada":"saved","guardando…":"saving…","Guardar na gaveta":"Keep on the shelf","fica na ilha, para arrastar de volta depois":"stays on the island, to drag back later",
"Guarde janelas aqui":"Keep windows here","Guardar a janela ativa":"Keep the active window","Trazer de volta":"Bring back","Nenhuma janela guardada":"No windows kept",
"montado · clique ejeta":"mounted · click ejects","clique ejeta":"click ejects","App ou comando":"App or command","Conta-gotas":"Eyedropper","Ler o texto da tela (OCR)":"Read screen text (OCR)",
"não montado":"not mounted","Guardadas: clique para devolver":"Kept: click to bring back","Listando janelas…":"Listing windows…","Abertas":"Open","Nenhuma janela aberta":"No open windows",
"{valor} hoje":"{valor} today"," · {valor} seguidos":" · {valor} in a row","tocando":"playing","Cafeína":"Caffeine","ligada":"on","desligada":"off","Mais":"More","Bloquear":"Lock","Capturar":"Screenshot","Mudo":"Mute","ejetar":"eject","Temp.":"Temp.","A ilha do Halo está ativa":"The Halo island is active","minimizada":"minimized","ativa":"active"
};
function t(idioma, pt, args) {
    var s = (String(idioma || "").indexOf("en") === 0 && EN[pt]) ? EN[pt] : pt;
    if (args) for (var k in args) s = s.split("{" + k + "}").join(args[k]);
    return s;
}
