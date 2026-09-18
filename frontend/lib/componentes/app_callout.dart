import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";

enum TipoCallout { info, urgente, confirmacao }

/// Aviso/callout — fundo ink-800, borda esquerda de 3px na cor
/// semântica: water-500 (info), flare-500 (urgente), safe-500
/// (confirmação).
class AppCallout extends StatelessWidget {
  final String texto;
  final TipoCallout tipo;
  final IconData? icone;

  const AppCallout({
    super.key,
    required this.texto,
    this.tipo = TipoCallout.info,
    this.icone,
  });

  Color get _cor => switch (tipo) {
    TipoCallout.info => Cores.water500,
    TipoCallout.urgente => Cores.flare500,
    TipoCallout.confirmacao => Cores.safe500,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cores.ink800,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: _cor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Icon(icone, color: _cor, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              texto,
              style: Tipografia.tema.bodyMedium?.copyWith(
                color: Cores.textoAlto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
