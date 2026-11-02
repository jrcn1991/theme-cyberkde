import QtQuick
import "comum"

// REDE: os nós da referência com rótulos LAN → GW → INTERNET e as latências.
Modulo {
    id: m
    titulo: d.t("Rede", "Network"); codigo: d.t("conexão", "link")
    rodape: d.redeAlvos + d.t(" · ping a cada ", " · ping every ") + d.pingSeg + " s"
    dica: d.t("Até onde o sinal chega: LAN (interfaces ligadas), GW (o roteador, com a latência) e INTERNET (os alvos públicos que responderam ao ping). Nunca sonda outras máquinas da rede local.",
              "How far the signal gets: LAN (interfaces up), GW (the router, with latency) and INTERNET (public targets that answered the ping). Never probes other machines on the local network.")
    Rede {
        k: m.k * m.width / m.u(358); width: m.width; height: m.u(124)
        alcance: Math.min(m.d.alcance, Math.round(22 * m.montado)); pulso: m.d.pulsoRede
        textoLan: m.d.redeLan; textoGw: m.d.redeGw; gwOk: m.d.gwOk; textoNet: m.d.redeNet
    }
}
