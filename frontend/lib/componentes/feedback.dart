import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Aviso de falha numa ação de negócio (atender resgate, marcar
/// reunificado, confirmar/recusar reunificação etc.) — usa vermelho +
/// ícone + duração maior que o padrão do Flutter (4s), porque um
/// `SnackBar` incolor e curto some rápido demais sob estresse
/// operacional e o operador segue achando que a ação deu certo.
void mostrarErro(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Cores.ink800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Cores.alerta500),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Cores.alerta500, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: Tipografia.tema.bodyMedium?.copyWith(
                  color: Cores.textoAlto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
