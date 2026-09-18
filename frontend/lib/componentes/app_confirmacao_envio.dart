import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "app_botao.dart";
import "app_card.dart";
import "app_selo.dart";

/// Tela de sucesso pós-envio dos formulários públicos (reunificação,
/// resgate) — mesma estrutura, texto ajustável ao contexto de cada um. O
/// botão só faz `pop()`, então [textoBotao] deve descrever pra onde essa
/// tela específica volta (nem toda tela que usa isso foi empilhada a
/// partir do portal).
class AppConfirmacaoEnvio extends StatelessWidget {
  final String textoBotao;

  const AppConfirmacaoEnvio({super.key, this.textoBotao = "Voltar"});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSelo(icone: Icons.check, corIcone: Cores.safe500),
          const SizedBox(height: 12),
          Text(
            "Pedido enviado!",
            style: Tipografia.tema.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "A equipe vai analisar e entrar em contato pelo telefone informado.",
            style: Tipografia.tema.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          AppBotaoSecundario(
            texto: textoBotao,
            aoPressionar: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
