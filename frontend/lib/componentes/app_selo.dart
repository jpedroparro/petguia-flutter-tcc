import "package:flutter/material.dart";

import "../tema/cores.dart";

/// Selo/badge circular — gradiente radial sutil ink-800→ink-700, ícone
/// central relacionado ao contexto (pata, onda, localização).
class AppSelo extends StatelessWidget {
  final IconData icone;
  final double tamanho;
  final Color corIcone;

  const AppSelo({
    super.key,
    required this.icone,
    this.tamanho = 44,
    this.corIcone = Cores.textoAlto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Cores.line),
        gradient: const RadialGradient(colors: [Cores.ink800, Cores.ink700]),
      ),
      child: Icon(icone, color: corIcone, size: tamanho * 0.45),
    );
  }
}
