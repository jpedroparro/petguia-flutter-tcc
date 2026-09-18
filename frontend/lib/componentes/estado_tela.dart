import "package:flutter/material.dart";

import "../tema/tipografia.dart";
import "app_selo.dart";

/// Estado de tela cheia (erro, vazio, aviso) — selo + mensagem centralizados.
/// Consolida o padrão `_estado({icone, cor, texto})` que existia
/// reimplementado em várias abas/telas do painel da equipe.
class EstadoTela extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const EstadoTela({
    super.key,
    required this.icone,
    required this.cor,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSelo(icone: icone, corIcone: cor),
            const SizedBox(height: 12),
            Text(
              texto,
              style: Tipografia.tema.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
