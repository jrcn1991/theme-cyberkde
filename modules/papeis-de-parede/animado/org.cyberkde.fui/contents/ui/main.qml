import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import "corps.js" as Corps

// Papel de parede animado FUI (CyberKDE). A cena está em Cena.qml; aqui entram a configuração, a
// corporação (cores, logo e emblema de corps.js, gerado de tokens/corporacoes.json) e as regras de pausa:
//  - movimento mínimo do tema (AnimationDurationFactor 0 → Kirigami.Units.longDuration 0) ou a chave
//    Movimento forçada pelo CLI: quadro fixo, sem nenhum redesenho;
//  - janela maximizada ou em tela cheia nesta tela (na área de trabalho e atividade atuais): congela até
//    ela sair (TaskManager.TasksModel, o mesmo modelo da barra de tarefas).
WallpaperItem {
    id: raiz
    readonly property var cfg: raiz.configuration
    readonly property var corp: Corps.de(cfg.Corporacao || "arasaka")

    readonly property string nivel: {
        const forcado = cfg.Movimento || "auto"
        if (forcado !== "auto") return forcado
        const d = Kirigami.Units.longDuration
        return d <= 1 ? "minimo" : d < 150 ? "reduzido" : "completo"
    }

    // ---- janelas que cobrem a tela
    TaskManager.VirtualDesktopInfo { id: areas }
    TaskManager.ActivityInfo { id: atividades }
    TaskManager.TasksModel {
        id: tarefas
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        screenGeometry: raiz.parent && raiz.parent.screenGeometry ? raiz.parent.screenGeometry
                      : (Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0))
        virtualDesktop: areas.currentDesktop
        activity: atividades.currentActivity
    }
    // quantas janelas maximizadas/em tela cheia (e não minimizadas) há nesta tela; recontado a cada mudança
    property int _rev: 0
    readonly property int cobrindo: {
        _rev
        let n = 0
        for (let i = 0; i < cobertura.count; i++) { const o = cobertura.objectAt(i); if (o && o.cobre) n++ }
        return n
    }
    Instantiator {
        id: cobertura
        model: (raiz.cfg.PausarCoberto ?? true) ? tarefas : null
        delegate: QtObject {
            required property var model
            readonly property bool cobre: (!!model.IsMaximized || !!model.IsFullScreen) && !model.IsMinimized
            onCobreChanged: raiz._rev++
        }
        onObjectAdded: raiz._rev++
        onObjectRemoved: raiz._rev++
    }

    Cena {
        anchors.fill: parent
        corLuz: raiz.corp.luz; corNevoa: raiz.corp.nevoa; corBase: raiz.corp.base; corTexto: raiz.corp.texto
        logo: raiz.corp.logo ? Qt.resolvedUrl("../images/corp/" + raiz.corp.logo) : ""
        emblema: raiz.corp.emblema ? Qt.resolvedUrl("../images/corp/" + raiz.corp.emblema) : ""
        tonsLogo: raiz.corp.tonsLogo || [0, 0]
        tonsEmblema: raiz.corp.tonsEmblema || [0, 0]
        corLogo: raiz.cfg.CorLogo === "original" ? "original" : "tingido"
        nome: raiz.corp.nome; lema: raiz.corp.lema; codigo: raiz.corp.codigo
        intensidade: (raiz.cfg.Intensidade ?? 100) / 100
        velocidade: (raiz.cfg.Velocidade ?? 100) / 100
        mostrarLogo: raiz.cfg.MostrarLogo ?? true
        mostrarTextos: raiz.cfg.MostrarTextos ?? true
        fps: (raiz.cfg.FpsMax ?? 30) >= 60 ? 60 : 30
        nivel: raiz.nivel
        ativo: raiz.cobrindo <= 0
    }
}
