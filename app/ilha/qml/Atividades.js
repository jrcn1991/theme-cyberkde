// O que a pílula mostra: uma atividade, por prioridade fixa (useAtividades do Halo). A segunda vira bolha.
.pragma library
function leitura(mod, id) { return mod ? (mod.readings || []).find(function (r) { return r.id === id }) : undefined }
function modulo(s, id) { return s ? (s.modules || []).find(function (m) { return m.id === id }) : undefined }
var ATIVIDADE_MIN_MS = 8000;
// o back-end traduz os valores
function nada(v) { return v === "nada" || v === "nothing" }
function tocandoV(v) { return v === "tocando" || v === "playing" }
function lista(s, midiaEsquecida, horaLocal) {
    var r = [];
    if (!s) return r;
    var mic = leitura(modulo(s, "audio"), "mic-em-uso");
    if (mic && mic.value !== "0") r.push({ tipo: "mic", quem: mic.detail });
    if (s.timer) r.push({ tipo: "timer", timer: s.timer });
    var vivas = (s.activities || []).filter(function (a) { return a.state === "andamento" && s.at - a.startedAt >= ATIVIDADE_MIN_MS });
    if (vivas[0]) r.push({ tipo: "atividade", atividade: vivas[0], n: vivas.length });
    var baixando = (s.downloads || []).filter(function (d) { return !d.parado });
    if (baixando.length) r.push({ tipo: "download", n: baixando.length, nome: baixando[0].nome });
    var m = modulo(s, "midia"), t = leitura(m, "midia-tocando"), e = leitura(m, "midia-estado");
    if (t && !nada(t.value) && !midiaEsquecida) r.push({ tipo: "midia", nome: t.value, art: t.art, tocando: !!e && tocandoV(e.value) });
    var h = leitura(modulo(s, "tempo"), "relogio-hora");
    // fechada, o back-end não calcula o relógio: a hora é daqui
    r.push({ tipo: "relogio", hora: h ? h.value : (horaLocal || "—") });
    return r;
}
function glifoDaOrigem(o) { return /shell|zsh|bash|fish/i.test(o) ? "Terminal" : /claude|agente|agent/i.test(o) ? "Sparkle" : "Lightning" }
function mmss(s) { s = Math.max(0, s); var m = Math.floor(s / 60), x = Math.floor(s % 60); return m + ":" + (x < 10 ? "0" : "") + x }
function contagem(timer, agora) {
    if (!timer) return "";
    return mmss(timer.end === null ? (agora - timer.start) / 1000 : (timer.end - agora) / 1000);
}
