import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: Qt.locale().name.toLowerCase().startsWith("pt") ? "Geral" : "General"
        icon: "view-financial-account-investment"
        source: "configGeral.qml"
    }
}
