import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "app_botao.dart";
import "app_card.dart";

/// Diálogo de confirmação pra ações de negócio irreversíveis ou de alto
/// impacto (recusar/confirmar reunificação, marcar reunificado etc.) —
/// RNF06 pede uso "em condições de estresse operacional", e sem esse
/// passo um toque errado vira decisão tomada na hora, sem volta.
///
/// Retorna `true` só se o usuário confirmar explicitamente; `false`/`null`
/// (cancelar, tocar fora, voltar) significa não prosseguir.
Future<bool> confirmarAcao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String textoConfirmar,
  bool destrutiva = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Tipografia.tema.titleLarge),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: Tipografia.tema.bodyMedium?.copyWith(
                color: Cores.textoMedio,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppBotaoSecundario(
                    texto: "Cancelar",
                    aoPressionar: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: destrutiva
                      ? _BotaoConfirmarDestrutivo(
                          texto: textoConfirmar,
                          aoPressionar: () => Navigator.of(context).pop(true),
                        )
                      : AppBotaoPrimario(
                          texto: textoConfirmar,
                          aoPressionar: () => Navigator.of(context).pop(true),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return resultado ?? false;
}

/// Mesmo visual de [AppBotaoPrimario], mas em vermelho (`alerta500`) —
/// reservado pra confirmar ações que negam/revertem algo pra alguém (ex:
/// recusar reunificação), pra diferenciar de uma confirmação positiva.
class _BotaoConfirmarDestrutivo extends StatelessWidget {
  final String texto;
  final VoidCallback aoPressionar;

  const _BotaoConfirmarDestrutivo({
    required this.texto,
    required this.aoPressionar,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Cores.alerta500,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: aoPressionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                texto.toUpperCase(),
                style: Tipografia.tema.labelLarge?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
