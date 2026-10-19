pragma Singleton
import QtQuick

// Textos da interface (catálogo em app/i18n, escolhido pelo backend). Txt.t("chave", {arg: valor})
// devolve o texto no idioma atual; as ligações que chamam t() se refazem sozinhas quando o idioma
// muda, porque t() lê "textos".
QtObject {
    property var textos: ({})
    function t(chave, args) {
        let s = textos[chave]
        if (s === undefined) s = chave
        if (args)
            for (const k in args) s = s.split("{" + k + "}").join(String(args[k]))
        return s
    }
}
