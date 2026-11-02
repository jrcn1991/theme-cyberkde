import QtQuick

// Uma página da SYS.CONFIG: "geral" (presets em destaque + os grupos com contagens), um grupo
// (os efeitos dele, cada um no cartão do seu tipo) ou "busca" (efeitos de todos os grupos que
// casam com a consulta).
Secao {
    id: s
    property string grupo: "geral"
    property string consulta: ""
    signal escolherGrupo(string id)

    readonly property var efeitos: painel.fxLista || []
    readonly property var grupos: painel.fxGrupos || []
    readonly property string q: consulta.trim() === "" ? "" : painel.normalizar(consulta.trim())
    readonly property var itens: {
        // os widgets da área de trabalho têm seção própria (WIDGETS)
        if (q !== "") return efeitos.filter(e => e.id !== "movimento" && !e.widget && e.busca.indexOf(q) >= 0)
        if (grupo === "geral") return []
        return efeitos.filter(e => e.grupo === grupo && e.id !== "movimento" && !e.widget)
    }
    readonly property var infoGrupo: grupos.find(g => g.id === grupo) || null
    readonly property var preset: efeitos.find(e => e.id === "estilo-preset") || null

    onGrupoChanged: if (ativa) reentrar()
    onQChanged: if (ativa) reentrar()

    // ---- cabeçalho da página
    Item {
        id: cab
        width: parent.width; height: 46
        Cascata { ativo: s.entrando; ordem: 0; alvo: cab }
        Column {
            spacing: 2
            Codigo {
                text: s.q !== "" ? "SYS.CONFIG // SEARCH" : "SYS.CONFIG // " + (s.grupo === "geral" ? "OVERVIEW" : s.grupo.toUpperCase())
                color: Tema.destaque
            }
            Row {
                spacing: 10
                Rotulo {
                    text: s.q !== "" ? Txt.t("cfg.resultados", { q: s.consulta.trim() })
                        : s.grupo === "geral" ? Txt.t("cfg.geral") : (s.infoGrupo ? s.infoGrupo.nome : s.grupo)
                    tamanho: 22
                }
                NumeroCintilante {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: s.grupo !== "geral" || s.q !== ""
                    valor: ("0" + s.itens.length).slice(-2) + " " + Txt.t("cfg.opcoes")
                    font.pixelSize: 11
                    color: Tema.texto3
                }
            }
        }
    }

    Leitura {
        visible: s.q === "" && s.grupo !== "geral" && Txt.t("cfg.grupoAjuda." + s.grupo) !== "cfg.grupoAjuda." + s.grupo
        width: Math.min(parent.width, 820)
        tamanho: 12
        text: Txt.t("cfg.grupoAjuda." + s.grupo)
    }

    // ---- visão geral
    PresetsInterface {
        id: presetsGeral
        visible: s.q === "" && s.grupo === "geral" && !!s.preset
        width: parent.width
        dados: s.preset || ({})
        app: s.app
        Cascata { ativo: s.entrando && presetsGeral.visible; ordem: 1; alvo: presetsGeral }
    }
    Grid {
        id: gradeGrupos
        visible: s.q === "" && s.grupo === "geral"
        width: parent.width
        columns: width > 900 ? 4 : 3
        spacing: 12
        Repeater {
            model: s.grupos
            Item {
                id: tg
                required property var modelData
                required property int index
                width: (gradeGrupos.width - (gradeGrupos.columns - 1) * 12) / gradeGrupos.columns
                height: 92
                // montagem
                property real traco: 1
                property real superficie: 1
                property real acender: 1
                property real realce: 0
                Cascata { ativo: s.entrando && gradeGrupos.visible; ordem: 2 + tg.index; alvo: tg }
                Chanfro {
                    anchors.fill: parent
                    traco: tg.traco; superficie: tg.superficie; realce: tg.realce
                    preenchimento: maG.containsMouse ? Tema.elevado : Tema.alfa(Tema.painel, 0.94)
                    borda: maG.containsMouse ? Tema.destaque : Tema.linha
                }
                Column {
                    x: 14; y: 10
                    width: parent.width - 28
                    spacing: 4
                    opacity: tg.acender
                    Codigo { text: ("0" + (tg.index + 1)).slice(-2) + " // " + tg.modelData.id.toUpperCase(); tamanho: 9; color: Tema.destaque }
                    Rotulo { text: tg.modelData.nome; tamanho: 17; width: parent.width; elide: Text.ElideRight }
                    Row {
                        spacing: 10
                        NumeroCintilante { valor: ("0" + tg.modelData.total).slice(-2) + " " + Txt.t("cfg.opcoes"); font.pixelSize: 10; color: Tema.texto2 }
                        NumeroCintilante {
                            visible: tg.modelData.personalizados > 0
                            valor: ("0" + tg.modelData.personalizados).slice(-2) + " " + Txt.t("cfg.personalizadas")
                            font.pixelSize: 10; color: Tema.destaque
                        }
                    }
                }
                MouseArea { id: maG; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.escolherGrupo(tg.modelData.id) }
            }
        }
    }

    // ---- área de trabalho: os widgets (e o modo de edição) têm seção própria; daqui, um atalho
    Bloco {
        id: blocoWidgets
        visible: s.q === "" && s.grupo === "area-de-trabalho"
        width: s.corpo.width
        titulo: Txt.t("secao.widgets").toUpperCase()
        codigo: "DESK.MODULES // " + ("0" + (painel.widgets || []).filter(w => w.ligado).length).slice(-2) + "/" + ("0" + (painel.widgets || []).length).slice(-2)
        Cascata { ativo: s.entrando && blocoWidgets.visible; ordem: 1; alvo: blocoWidgets }
        Item {
            width: parent.width; height: 34
            Leitura {
                width: parent.width - irW.width - 16
                anchors.verticalCenter: parent.verticalCenter
                tamanho: 12; color: Tema.texto2
                text: Txt.t("wg.atalhoConfig")
            }
            Botao {
                id: irW
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: Txt.t("wg.gerenciar"); tipo: "primario"; tamanho: 12
                onClicado: s.app.irPara("widgets")
            }
        }
    }

    // ---- efeitos do grupo (ou da busca), cada um pelo tipo
    Repeater {
        model: s.itens
        Loader {
            id: ld
            required property var modelData
            required property int index
            width: s.corpo.width
            sourceComponent: modelData.especial === "janelas" ? compJanelas
                : modelData.especial === "konsole-cascata" ? compCascata
                : modelData.id === "estilo-preset" ? compPreset
                : modelData.id === "datashard" ? compDatashard
                : modelData.id === "papel" ? compPapel : compOpcao
            Component {
                id: compOpcao
                CartaoOpcao {
                    id: co
                    width: ld.width
                    dados: ld.modelData
                    numero: ld.index + 1
                    Cascata { ativo: s.entrando; ordem: 1 + ld.index; alvo: co }
                }
            }
            // o DATASHARD tem seção própria (GERENCIADOR DE ARQUIVOS): aqui fica só o atalho
            Component {
                id: compDatashard
                Bloco {
                    id: bds
                    width: ld.width
                    titulo: "DATASHARD"
                    codigo: "FILE.MANAGER // " + ((ld.modelData.estado || {}).ligado ? "DEFAULT" : "STANDBY")
                    Cascata { ativo: s.entrando; ordem: 1 + ld.index; alvo: bds }
                    Item {
                        width: parent.width; height: 34
                        Leitura {
                            width: parent.width - irDs.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                            tamanho: 12; color: Tema.texto2
                            text: Txt.t("ds.atalhoConfig")
                        }
                        Botao {
                            id: irDs
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: Txt.t("ds.irSecao"); tipo: "primario"; tamanho: 12
                            onClicado: s.app.irPara("arquivos")
                        }
                    }
                }
            }
            // o papel de parede tem seção própria (animado × estático): aqui fica só o atalho
            Component {
                id: compPapel
                Bloco {
                    id: bpp
                    width: ld.width
                    titulo: Txt.t("secao.papel").toUpperCase()
                    codigo: "WALLPAPER // " + (((ld.modelData.estado || {}).opcao || "") === "fui" ? "ANIMATED" : "STATIC")
                    Cascata { ativo: s.entrando; ordem: 1 + ld.index; alvo: bpp }
                    Item {
                        width: parent.width; height: 34
                        Leitura { width: parent.width - irP.width - 16; anchors.verticalCenter: parent.verticalCenter; tamanho: 12; color: Tema.texto2; text: Txt.t("papel.atalhoConfig") }
                        Botao { id: irP; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Txt.t("papel.irSecao"); tipo: "primario"; tamanho: 12; onClicado: s.app.irPara("papel") }
                    }
                }
            }
            Component {
                id: compPreset
                PresetsInterface {
                    id: pi
                    width: ld.width
                    dados: ld.modelData
                    app: s.app
                    Cascata { ativo: s.entrando; ordem: 1 + ld.index; alvo: pi }
                }
            }
            Component {
                id: compCascata
                CartaoCascata {
                    id: cc
                    width: ld.width
                    Cascata { ativo: s.entrando; ordem: 1 + ld.index; alvo: cc }
                }
            }
            Component {
                id: compJanelas
                GaleriaJanelas {
                    width: ld.width
                    ativa: s.ativa
                    entrando: s.entrando
                    app: s.app
                }
            }
        }
    }

    Leitura {
        visible: s.q !== "" && s.itens.length === 0
        width: parent.width
        tamanho: 13
        text: Txt.t("cfg.nada", { q: s.consulta.trim() })
    }
    Leitura {
        visible: !painel.suporteFxLista
        width: Math.min(parent.width, 820)
        tamanho: 12
        color: Tema.alerta
        text: Txt.t("cfg.semLista")
    }
}
