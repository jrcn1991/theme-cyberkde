"""Modelo de itens de uma aba. Recebe a lista já filtrada e ordenada e aplica só a diferença
(rowsInserted/rowsRemoved/dataChanged), para a seleção, a rolagem e as animações por delegado
sobreviverem às mudanças observadas no disco."""

from PyQt6.QtCore import QAbstractListModel, QByteArray, QModelIndex, Qt, pyqtSignal, pyqtProperty

PAPEIS = ("nome", "caminho", "url", "ehPasta", "ehLink", "alvoLink", "oculto", "tamanho", "tamanhoTexto",
          "modificado", "modificadoTexto", "mime", "tipo", "grupo", "icone", "iconeUrl", "miniatura", "filhos", "filhosLimite",
          "codigo", "permissoes", "legivel", "gravavel", "selecionado", "pastaPai", "local", "origem", "apagadoEm",
          "subpastas", "subpastasTotal", "arquivosTotal", "subpastasEstado",
          "tags", "avaliacao", "comentario", "secao")
_BASE = Qt.ItemDataRole.UserRole + 1
_IDX = {nome: _BASE + i for i, nome in enumerate(PAPEIS)}
_ROLE_SEL = _IDX["selecionado"]
_ROLE_SECAO = _IDX["secao"]


class ModeloItens(QAbstractListModel):
    contagemMudou = pyqtSignal()

    def __init__(self, selecao, parent=None):
        super().__init__(parent)
        self._itens = []
        self._linha = {}          # caminho -> linha
        self._sel = selecao       # set de caminhos, da aba
        self.secao = None         # função item -> rótulo da seção (agrupar), da aba

    # ---- Qt
    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._itens)

    def roleNames(self):
        return {r: QByteArray(n.encode()) for n, r in _IDX.items()}

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._itens):
            return None
        item = self._itens[index.row()]
        if role == _ROLE_SEL:
            return item["caminho"] in self._sel
        if role == _ROLE_SECAO:
            return self.secao(item) if self.secao else ""
        if role == Qt.ItemDataRole.DisplayRole:
            return item["nome"]
        nome = PAPEIS[role - _BASE] if _BASE <= role < _BASE + len(PAPEIS) else None
        return item.get(nome) if nome else None

    @pyqtProperty(int, notify=contagemMudou)
    def count(self):
        return len(self._itens)

    # ---- acesso pelo Python
    def itens(self):
        return self._itens

    def item(self, linha):
        if 0 <= linha < len(self._itens):
            d = dict(self._itens[linha])
            d["selecionado"] = d["caminho"] in self._sel
            d["secao"] = self.secao(d) if self.secao else ""
            return d
        return None

    def linha_de(self, caminho):
        return self._linha.get(caminho, -1)

    def _reindexar(self):
        self._linha = {d["caminho"]: i for i, d in enumerate(self._itens)}

    # ---- mudanças
    def redefinir(self, novos):
        self.beginResetModel()
        self._itens = list(novos)
        self._reindexar()
        self.endResetModel()
        self.contagemMudou.emit()

    def acrescentar(self, novos):
        """Para a busca: resultados chegam aos poucos, no fim da lista."""
        if not novos:
            return
        n = len(self._itens)
        self.beginInsertRows(QModelIndex(), n, n + len(novos) - 1)
        self._itens.extend(novos)
        for i, d in enumerate(novos, n):
            self._linha[d["caminho"]] = i
        self.endInsertRows()
        self.contagemMudou.emit()

    def aplicar(self, novos):
        """Transforma a lista atual em `novos` com o mínimo de sinais."""
        if not self._itens or not novos:
            self.redefinir(novos)
            return
        pos = {d["caminho"]: i for i, d in enumerate(novos)}
        # mantém os antigos que continuam e cuja ordem relativa não quebrou (guloso: correto, nem sempre mínimo)
        manter = []
        ultimo = -1
        for d in self._itens:
            p = pos.get(d["caminho"], -1)
            if p > ultimo:
                manter.append(True)
                ultimo = p
            else:
                manter.append(False)
        # remove de trás para a frente, em blocos contíguos
        i = len(self._itens) - 1
        while i >= 0:
            if manter[i]:
                i -= 1
                continue
            fim = i
            while i >= 0 and not manter[i]:
                i -= 1
            self.beginRemoveRows(QModelIndex(), i + 1, fim)
            del self._itens[i + 1:fim + 1]
            self.endRemoveRows()
        # percorre a lista nova inserindo blocos e atualizando o que mudou
        i = 0
        while i < len(novos):
            atual = self._itens[i]["caminho"] if i < len(self._itens) else None
            if atual == novos[i]["caminho"]:
                if self._itens[i] != novos[i]:
                    self._itens[i] = novos[i]
                    idx = self.index(i)
                    self.dataChanged.emit(idx, idx, [])
                i += 1
                continue
            j = i
            while j < len(novos) and novos[j]["caminho"] != atual:
                j += 1
            self.beginInsertRows(QModelIndex(), i, j - 1)
            self._itens[i:i] = novos[i:j]
            self.endInsertRows()
            i = j
        self._reindexar()
        self.contagemMudou.emit()

    def atualizar_campo(self, valores, campo):
        """valores: {caminho: valor}. Usado para `filhos`, que chega depois da leitura."""
        linhas = []
        for caminho, v in valores.items():
            ln = self._linha.get(caminho)
            if ln is not None and self._itens[ln].get(campo) != v:
                self._itens[ln][campo] = v
                linhas.append(ln)
        self._emitir(linhas, [_IDX[campo]])

    def atualizar_campos(self, valores):
        """valores: {caminho: {campo: valor}}. Avisa só as linhas e os papéis que mudaram de fato
        (compara antes de gravar: os dicionários são compartilhados com a aba)."""
        linhas, papeis = [], set()
        for caminho, campos in valores.items():
            ln = self._linha.get(caminho)
            if ln is None:
                continue
            item = self._itens[ln]
            mudou = False
            for campo, v in campos.items():
                if item.get(campo) != v:
                    item[campo] = v
                    papeis.add(_IDX[campo])
                    mudou = True
            if mudou:
                linhas.append(ln)
        self._emitir(linhas, sorted(papeis))

    def secoes_mudaram(self):
        if self._itens:
            self.dataChanged.emit(self.index(0), self.index(len(self._itens) - 1), [_ROLE_SECAO])

    def selecao_mudou(self, caminhos):
        self._emitir([self._linha[c] for c in caminhos if c in self._linha], [_ROLE_SEL])

    def _emitir(self, linhas, papeis):
        if not linhas:
            return
        linhas.sort()
        ini = ant = linhas[0]
        for ln in linhas[1:] + [None]:
            if ln is not None and ln == ant + 1:
                ant = ln
                continue
            self.dataChanged.emit(self.index(ini), self.index(ant), papeis)
            if ln is not None:
                ini = ant = ln
