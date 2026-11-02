import QtQuick
import "comum"

// PROCESSOS: os 6 de maior uso de CPU, com nome, CPU% e MEM%.
Modulo {
    id: m
    titulo: d.t("Processos", "Processes"); codigo: "top cpu"
    rodape: "ps · " + d.t("a cada 3 s · só leitura", "every 3 s · read only")
    dica: d.t("Os 6 processos que mais usam CPU agora (ps). CPU% pode passar de 100 % em processos com várias threads; MEM% é a fatia da memória física.",
              "The 6 processes using the most CPU right now (ps). CPU% can exceed 100 % for multi-threaded processes; MEM% is the share of physical memory.")
    readonly property int cCpu: width - u(60)
    readonly property int cMem: width - u(2)
    Rot { k: m.k; x: 0; y: 0; text: m.d.t("PROCESSO", "PROCESS") }
    Rot { k: m.k; x: m.cCpu - width; y: 0; text: "CPU%" }
    Rot { k: m.k; x: m.cMem - width; y: 0; text: "MEM%" }
    Rectangle { y: m.u(15); width: m.width; height: 1; color: Cores.alfa(Cores.texto, 0.25) }
    Repeater {
        model: 6
        Item {
            required property int index
            readonly property var pr: m.d.procs[index] || null
            y: m.u(19) + index * m.u(17); width: m.width; height: m.u(17)
            Val { k: m.k; width: m.cCpu - m.u(52); font.weight: Font.Normal
                  text: parent.pr ? m.digita(parent.pr.nome) : "—"; color: parent.pr ? Cores.texto : Cores.texto3 }
            Val { k: m.k; x: m.cCpu - width; text: parent.pr ? m.d.dec(parent.pr.cpu, 1) : ""
                  color: parent.pr && parent.pr.cpu >= m.d.limiar * 100 ? Cores.alerta : Cores.texto }
            Val { k: m.k; x: m.cMem - width; text: parent.pr ? m.d.dec(parent.pr.mem, 1) : ""; color: Cores.texto2 }
        }
    }
}
