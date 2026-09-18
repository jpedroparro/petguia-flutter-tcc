import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Quantas páginas uma lista de [totalItens] ocupa, a [itensPorPagina].
/// Nunca retorna 0 — lista vazia ainda ocupa 1 página (vazia).
int totalDePaginas(int totalItens, int itensPorPagina) {
  if (totalItens == 0) return 1;
  return ((totalItens - 1) ~/ itensPorPagina) + 1;
}

/// Recorta [itens] pra mostrar só a [pagina] (0-indexada) corrente.
List<T> paginar<T>(List<T> itens, int pagina, int itensPorPagina) {
  final inicio = pagina * itensPorPagina;
  if (inicio >= itens.length) return const [];
  final fim = (inicio + itensPorPagina).clamp(0, itens.length);
  return itens.sublist(inicio, fim);
}

/// Controles de "página anterior/próxima" — usado em listas que podem
/// crescer bastante (ruas afetadas, alertas de resgate), pra manter a
/// tela organizada em vez de um rolamento gigante.
class PaginacaoControles extends StatelessWidget {
  final int paginaAtual;
  final int totalPaginas;
  final ValueChanged<int> aoMudarPagina;

  const PaginacaoControles({
    super.key,
    required this.paginaAtual,
    required this.totalPaginas,
    required this.aoMudarPagina,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: paginaAtual > 0
                ? () => aoMudarPagina(paginaAtual - 1)
                : null,
            icon: const Icon(Icons.chevron_left, color: Cores.flare500),
          ),
          Text(
            "Página ${paginaAtual + 1} de $totalPaginas",
            style: Tipografia.rotulo(cor: Cores.textoMedio, tamanho: 12),
          ),
          IconButton(
            onPressed: paginaAtual < totalPaginas - 1
                ? () => aoMudarPagina(paginaAtual + 1)
                : null,
            icon: const Icon(Icons.chevron_right, color: Cores.flare500),
          ),
        ],
      ),
    );
  }
}
