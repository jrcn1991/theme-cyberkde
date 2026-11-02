import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: Qt.locale().name.startsWith("pt") ? "Local" : "Location"
        icon: "weather-few-clouds"
        source: "configGeral.qml"
    }
}
