import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

// Papel de parede em vídeo (CyberKDE): um vídeo da pasta da pessoa ("cyberkde efeito papel-pasta"). O
// vídeo está em Tocador.qml; aqui entram a configuração e as regras de pausa, as mesmas do FUI e mais o
// bloqueio:
//  - janela maximizada ou em tela cheia nesta tela, na área de trabalho e atividade atuais
//    (TaskManager.TasksModel, o mesmo modelo da barra de tarefas);
//  - tela bloqueada (org.freedesktop.ScreenSaver.GetActive, consultado a cada 2 s: no Wayland o
//    compositor para de pedir quadros, mas o vídeo continuaria decodificando);
//  - movimento mínimo do tema (AnimationDurationFactor 0) ou Movimento=minimo: quadro parado.
// Trocar de papel destrói este item, e o vídeo para junto.
WallpaperItem {
    id: raiz
    readonly property var cfg: raiz.configuration

    readonly property bool movimento: {
        const forcado = cfg.Movimento || "auto"
        if (forcado !== "auto") return forcado !== "minimo"
        return Kirigami.Units.longDuration > 1
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

    // ---- tela bloqueada
    property bool bloqueada: false
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: raiz.cfg.PausarBloqueio ?? true
        onRunningChanged: if (!running) raiz.bloqueada = false
        onTriggered: DBus.SessionBus.asyncCall({
            service: "org.freedesktop.ScreenSaver", path: "/ScreenSaver",
            iface: "org.freedesktop.ScreenSaver", member: "GetActive"
        }, r => raiz.bloqueada = !!(r && r.value), () => raiz.bloqueada = false)
    }

    Tocador {
        anchors.fill: parent
        fonte: raiz.cfg.Video || ""
        reserva: raiz.cfg.Reserva || ""
        preenchimento: raiz.cfg.Preenchimento || "cortar"
        ativo: raiz.movimento && raiz.cobrindo <= 0 && !raiz.bloqueada
    }
}
