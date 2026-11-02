import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: Qt.locale().name.toLowerCase().startsWith("pt") ? "Quadro" : "Board"
        icon: "knotes"
        source: "configGeral.qml"
    }
}
