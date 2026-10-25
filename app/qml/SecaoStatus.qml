import QtQuick

Secao {
    id: s
    readonly property var st: painel.status
    readonly property var fasesLigadas: painel.fases.filter(f => f.ligada === true).length
    readonly property var corpInfo: painel.corps.find(x => x.id === painel.corpAtual)

    // alertas: o que a usuária precisa saber agora
    readonly property var alertas: {
        let a = []
        if (!painel.statusOk) a.push({ nivel: "erro", texto: Txt.t("status.aviso.semCli") })
        if (st.reversaoPendente) a.push({ nivel: "aviso", texto: Txt.t("status.aviso.reversao") })
        if (st.completa === false) a.push({ nivel: "aviso", texto: Txt.t("status.aviso.incompleta") })
        if (st.kvantum === false) a.push({ nivel: "aviso", texto: Txt.t("status.aviso.kvantum") })
        if (painel.suporteFases && !painel.registroPorFase) a.push({ nivel: "aviso", texto: Txt.t("status.aviso.registroAntigo") })
        if (!painel.suporteFases) a.push({ nivel: "info", texto: Txt.t("status.aviso.semFases") })
        if (!painel.suporteCorp) a.push({ nivel: "info", texto: Txt.t("status.aviso.semCorp") })
        return a
    }

    Row {
        width: parent.width
        spacing: 20

        // energia
        Bloco {
            id: energia
            width: 340
            height: Math.max(implicitHeight, info.height)
            titulo: Txt.t("status.energia")
            codigo: "PWR-01"
            destaque: true
            Cascata { ativo: s.entrando; ordem: 0; vertical: true; alvo: energia }
            Item {
                width: parent.width; height: 250
                AnelEnergia {
                    anchors.centerIn: parent
                    ligado: painel.temaLigado
                    ocupado: painel.ocupado && painel.alvo === "tema"
                    onAcionado: painel.temaLigado ? s.app.pedirDesligar() : painel.ligarTema()
                }
            }
            Leitura {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Tema.texto
                tamanho: 14
                text: painel.temaLigado ? Txt.t("status.ligadoTexto") : Txt.t("status.desligadoTexto")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Botao {
                    text: Txt.t("comum.ligar"); icone: "⏻"; tipo: painel.temaLigado ? "secundario" : "primario"
                    habilitado: !painel.ocupado
                    onClicado: painel.ligarTema()
                }
                Botao {
                    text: Txt.t("comum.desligar"); tipo: "secundario"; cor: Tema.alerta
                    habilitado: !painel.ocupado && painel.temaLigado
                    onClicado: s.app.pedirDesligar()
                }
            }
        }

        // leituras
        Column {
            id: info
            width: parent.width - energia.width - 20
            spacing: 20

            Bloco {
                id: tele
                width: parent.width
                titulo: Txt.t("status.telemetria")
                codigo: "SYS-STAT"
                Cascata { ativo: s.entrando; ordem: 1; vertical: true; alvo: tele }
                Grid {
                    width: parent.width
                    columns: width > 640 ? 4 : 2
                    rowSpacing: 18
                    columnSpacing: 12
                    readonly property real col: (width - (columns - 1) * columnSpacing) / columns
                    Dado {
                        width: parent.col
                        id: d1
                        rotulo: Txt.t("comum.tema")
                        valor: painel.temaLigado ? Txt.t("status.ligado") : Txt.t("status.desligado")
                        cor: painel.temaLigado ? Tema.destaque : Tema.texto2
                        Cascata { ativo: s.entrando; ordem: 2; alvo: d1 }
                    }
                    Dado {
                        width: parent.col
                        id: d2
                        rotulo: Txt.t("status.corporacao")
                        valor: s.corpInfo ? s.corpInfo.nome : (painel.corpAtual === "personalizada" ? Txt.t("nome.personalizada") : Txt.t("status.nenhuma"))
                        Cascata { ativo: s.entrando; ordem: 3; alvo: d2 }
                    }
                    Dado {
                        width: parent.col
                        id: d3
                        rotulo: Txt.t("status.corDestaque")
                        valor: (s.st.cor || "—").toUpperCase()
                        nota: s.st.corAplicada && s.st.corAplicada !== s.st.cor ? Txt.t("status.aplicadaComo", { cor: s.st.corAplicada }) : (s.st.padrao ? Txt.t("status.padraoTema") : "")
                        Cascata { ativo: s.entrando; ordem: 4; alvo: d3 }
                        Rectangle { width: 14; height: 14; color: Tema.paletaSistema.destaque; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Dado {
                        width: parent.col
                        id: d4
                        rotulo: Txt.t("status.fasesLigadas")
                        valor: painel.suporteFases && painel.registroPorFase ? s.fasesLigadas + "/" + painel.fases.length : "—/" + painel.fases.length
                        nota: !painel.suporteFases ? Txt.t("mod.semSuporte") : (!painel.registroPorFase ? Txt.t("status.registroAntigoNota") : "")
                        Cascata { ativo: s.entrando; ordem: 5; alvo: d4 }
                    }
                    Dado {
                        width: parent.col
                        id: d5
                        rotulo: Txt.t("status.chaves")
                        valor: s.st.chaves !== undefined ? String(s.st.chaves) : "—"
                        nota: Txt.t("status.chavesNota")
                        Cascata { ativo: s.entrando; ordem: 6; alvo: d5 }
                    }
                    Dado {
                        width: parent.col
                        id: d6
                        rotulo: Txt.t("status.kvantum")
                        valor: s.st.kvantum === undefined ? "—" : (s.st.kvantum ? Txt.t("comum.ok") : Txt.t("status.ausente"))
                        cor: s.st.kvantum === false ? Tema.alerta : Tema.texto
                        Cascata { ativo: s.entrando; ordem: 7; alvo: d6 }
                    }
                    Dado {
                        width: parent.col
                        id: d7
                        rotulo: Txt.t("status.aplicacao")
                        valor: s.st.completa === false ? Txt.t("status.incompleta") : Txt.t("status.completa")
                        cor: s.st.completa === false ? Tema.alerta : Tema.texto
                        Cascata { ativo: s.entrando; ordem: 8; alvo: d7 }
                    }
                    Dado {
                        width: parent.col
                        id: d8
                        rotulo: Txt.t("status.reversao")
                        valor: s.st.reversaoPendente ? Txt.t("status.pendente") : Txt.t("status.limpa")
                        cor: s.st.reversaoPendente ? Tema.alerta : Tema.texto
                        Cascata { ativo: s.entrando; ordem: 9; alvo: d8 }
                    }
                }
            }

            Bloco {
                id: blAvisos
                width: parent.width
                titulo: Txt.t("status.avisos")
                codigo: s.alertas.length ? Txt.t("status.itens", { n: ("0" + s.alertas.length).slice(-2) }) : Txt.t("status.nenhum")
                cor: s.alertas.some(a => a.nivel !== "info") ? Tema.alerta : Tema.destaque
                Cascata { ativo: s.entrando; ordem: 10; vertical: true; alvo: blAvisos }
                Leitura {
                    visible: s.alertas.length === 0
                    text: Txt.t("status.nada")
                    color: Tema.texto
                }
                Repeater {
                    model: s.alertas
                    Row {
                        id: al
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 12
                        Cascata { ativo: s.entrando; ordem: 11 + al.index }
                        Rectangle {
                            width: 7; height: 7; rotation: 45; y: 6
                            color: al.modelData.nivel === "erro" ? Tema.erro : al.modelData.nivel === "aviso" ? Tema.alerta : Tema.secundaria
                        }
                        Leitura { width: parent.width - 20; text: al.modelData.texto; color: Tema.texto }
                    }
                }
            }

            Row {
                spacing: 10
                Cascata { ativo: s.entrando; ordem: 14 }
                Botao { text: Txt.t("comum.atualizar"); icone: "↻"; onClicado: painel.atualizar() }
                Botao { text: Txt.t("secao.corporacao"); icone: "◆"; onClicado: s.app.irPara("corporacao") }
                Botao { text: Txt.t("secao.diagnostico"); icone: "⌁"; onClicado: { s.app.irPara("diagnostico"); painel.checar() } }
            }
        }
    }
}
