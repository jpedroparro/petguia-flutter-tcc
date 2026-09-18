import "package:flutter/material.dart";

import "../tema/cores.dart";

/// Elemento de assinatura do PetGuia Enchentes: barrinhas verticais +
/// linha teal, lembrando uma régua de nível d'água. Usar como rodapé
/// decorativo ou indicador de progresso/nível de urgência — não forçar
/// em toda tela, só onde fizer sentido semântico.
class ReguaNivelDagua extends StatelessWidget {
  /// Nível preenchido, de 0.0 a 1.0.
  final double nivel;
  final int quantidadeBarras;

  const ReguaNivelDagua({
    super.key,
    this.nivel = 1.0,
    this.quantidadeBarras = 24,
  });

  @override
  Widget build(BuildContext context) {
    final preenchidas = (quantidadeBarras * nivel.clamp(0, 1)).round();
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(quantidadeBarras, (i) {
              final ativa = i < preenchidas;
              return Container(
                width: 2,
                height: ativa ? 18 : 10,
                color: ativa ? Cores.water500 : Cores.line,
              );
            }),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Cores.water500.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
