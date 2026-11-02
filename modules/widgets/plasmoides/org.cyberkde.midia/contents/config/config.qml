import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: Qt.locale().name.toLowerCase().startsWith("pt") ? "Geral" : "General"
        icon: "media-playback-start"
        source: "configGeral.qml"
    }
}
