// Os módulos avulsos do Painel FUI (pacotes org.cyberkde.fui-<id>): componente, largura-base (em unidades
// da referência; a altura é sempre 172) e as partes de dados que cada um precisa (Dados.qml).
.pragma library
var modulos = {
    "cpu":       { arquivo: "MCpu.qml",       largura: 116, partes: ["cpu"] },
    "nucleos":   { arquivo: "MNucleos.qml",   largura: 349, partes: ["nucleos"] },
    "sensores":  { arquivo: "MSensores.qml",  largura: 270, partes: ["temp", "gpu", "memoria", "rede", "discos"] },
    "memoria":   { arquivo: "MMemoria.qml",   largura: 273, partes: ["memoria"] },
    "gpu":       { arquivo: "MGpu.qml",       largura: 116, partes: ["gpu", "memoria"] },
    "discos":    { arquivo: "MDiscos.qml",    largura: 239, partes: ["discos"] },
    "es":        { arquivo: "MES.qml",        largura: 240, partes: ["es", "discos"] },
    "rede":      { arquivo: "MRede.qml",      largura: 358, partes: ["estado", "ping"] },
    "trafego":   { arquivo: "MTrafego.qml",   largura: 140, partes: ["rede"] },
    "processos": { arquivo: "MProcessos.qml", largura: 239, partes: ["processos"] },
    "log":       { arquivo: "MLog.qml",       largura: 240, partes: ["log"] },
    "sistema":   { arquivo: "MSistema.qml",   largura: 200, partes: ["sistema", "atualizacoes"] },
    "hora":      { arquivo: "MHora.qml",      largura: 349, partes: ["hora"] },
    "clima":     { arquivo: "MClima.qml",     largura: 181, partes: ["clima"] },
    "estados":   { arquivo: "MEstados.qml",   largura: 132, partes: ["estado", "ping", "gpu"] }
}
