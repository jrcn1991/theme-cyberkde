import QtQuick

// Sensor FALSO, só para as prévias (previas-demo.sh põe esta pasta no QML_IMPORT_PATH, na frente do módulo
// real): nada da máquina aparece. Mesma interface que os widgets usam: sensorId, updateRateLimit e value.
QtObject {
    id: s
    property string sensorId: ""
    property int updateRateLimit: 0
    property var value: ler()
    property real fase: Math.random() * 6
    function onda(base, amp, vel) { return base + amp * Math.sin(fase * vel) }
    function ler() {
        const i = sensorId
        if (!i) return 0
        let m
        if (i === "cpu/all/coreCount") return 16
        if (i === "cpu/all/usage") return onda(38, 9, 1)
        if (i === "cpu/all/maximumTemperature") return onda(61, 3, 0.5)
        if ((m = i.match(/^cpu\/cpu(\d+)\/usage$/))) return onda(24 + (m[1] * 7) % 46, 8, 1.3)
        if (i === "memory/physical/total") return 68719476736
        if (i === "memory/physical/used") return onda(25.2e9, 3e8, 0.4)
        if (i === "memory/physical/cache") return 18.4e9
        if (i === "memory/physical/buffer") return 0.9e9
        if (i === "memory/swap/total") return 17179869184
        if (i === "memory/swap/used") return 2.1e9
        if (i === "network/all/download") return Math.max(0, onda(2.4e6, 2e6, 1.1))
        if (i === "network/all/upload") return Math.max(0, onda(3.2e5, 2.4e5, 0.8))
        if (i === "os/system/uptime") return 266400
        if (i === "disk/all/free") return 512e9
        if (i === "disk/all/usedPercent") return 58
        if (i === "disk/all/read") return Math.max(0, onda(5.2e7, 4.8e7, 0.9))
        if (i === "disk/all/write") return Math.max(0, onda(1.4e7, 1.2e7, 1.4))
        if ((m = i.match(/^disk\/sd([a-z])\/(read|write)$/))) {
            const b = { a: 3.8e7, b: 9.4e7, c: 1.2e7, d: 4e6 }[m[1]] || 1e6
            return Math.max(0, onda(m[2] === "read" ? b : b * 0.4, b * 0.3, 1.2))
        }
        if ((m = i.match(/^gpu\/gpu(\d)\/(.*)$/))) {
            if (m[1] !== "0") return m[2] === "name" ? "" : 0
            return { name: "Militech Apogee GX", usage: onda(32, 6, 1), temperature: onda(54, 2, 0.5), power: onda(62, 8, 1),
                     usedVram: 4.2e9, totalVram: 17179869184 }[m[2]] || 0
        }
        return 0
    }
    property Timer relogio: Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { s.fase += 0.7; s.value = s.ler() }
    }
    onSensorIdChanged: value = ler()
}
