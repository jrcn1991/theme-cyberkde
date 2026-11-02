// As molas do Halo (tokens.css): amostras de linear(), aqui como [x, y].
.pragma library
// Tabelas curtas: até 5 trechos, escolhidos à mão. Spline longa corrompe a memória no Qt 6.10, e "assentar"
// nunca passa do alvo (fechar não quica): por isso ela é uma cúbica só, monótona.
var T = {
    assentar: "0.22,0.61,0.2,1",
    gota: [[.167,.515],[.333,.935],[.5,1.029],[.75,1.009],[1,1]],
    viva: [[.125,.703],[.25,1.123],[.417,1.023],[.625,.99],[1,1]],
    gelatina: [[.083,.78],[.167,1.318],[.333,.899],[.5,1.032],[1,1]],
    entrar: "0.2,0,0,1", sair: "0.4,0,1,1", sugar: "0.6,0,0.2,1"
};
var MAX_NOS = 6;
// tabela própria de um tema: reduzida a poucos nós, sempre com o ponto mais alto
function nos(t) {
    if (t.length <= MAX_NOS - 1) return [[0, 0]].concat(t);
    var n = t.length, r = [[0, 0]], picoI = 0;
    for (var i = 1; i < n; i++) if (t[i][1] > t[picoI][1]) picoI = i;
    var cand = [Math.floor(picoI * 0.5), picoI, Math.floor(picoI + (n - picoI) * 0.35), Math.floor(picoI + (n - picoI) * 0.7)], vistos = {};
    for (var c = 0; c < cand.length && r.length < MAX_NOS - 1; c++) {
        var k = cand[c];
        if (k > 0 && k < n - 1 && !vistos[k]) { vistos[k] = true; r.push(t[k]); }
    }
    r.push([1, 1]);
    return r;
}
function curva(c) {
    var t = typeof c === "string" ? T[c] : c;
    if (!t) t = T.gota;
    if (typeof t === "string") {
        var p = t.split(",").map(Number);
        return [p[0], p[1], p[2], p[3], 1, 1];
    }
    var q = nos(t), r = [];
    for (var i = 0; i < q.length - 1; i++) {
        var a = q[Math.max(0, i - 1)], b = q[i], d = q[i + 1], e = q[Math.min(q.length - 1, i + 2)];
        var cx1 = Math.min(d[0], Math.max(b[0], b[0] + (d[0] - a[0]) / 6)), cy1 = b[1] + (d[1] - a[1]) / 6;
        var cx2 = Math.max(b[0], Math.min(d[0], d[0] - (e[0] - b[0]) / 6)), cy2 = d[1] - (e[1] - b[1]) / 6;
        r.push(cx1, cy1, cx2, cy2, d[0], d[1]);
    }
    return r;
}
