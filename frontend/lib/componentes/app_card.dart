import "package:flutter/material.dart";

import "../tema/cores.dart";

/// Superfície padrão do app — fundo ink-800, borda 1px line, canto cortado
/// (não arredondado) de 10px, referência às placas de sinalização e
/// etiquetas de campo da Defesa Civil. Toda tela deve usar isso em vez de
/// criar containers próprios.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: Cores.ink800,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Cores.line),
        ),
      ),
      child: child,
    );
  }
}
