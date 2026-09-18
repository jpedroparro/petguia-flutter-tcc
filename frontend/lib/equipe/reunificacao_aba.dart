import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_card.dart";
import "../componentes/confirmar_acao.dart";
import "../componentes/estado_tela.dart";
import "../componentes/feedback.dart";
import "../dados/funcoes_repositorio.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Fila de aprovação de reunificação com o tutor original — equipe
/// confirma ou recusa cada solicitação pública pendente.
class ReunificacaoAba extends StatefulWidget {
  const ReunificacaoAba({super.key});

  @override
  State<ReunificacaoAba> createState() => _ReunificacaoAbaState();
}

class _ReunificacaoAbaState extends State<ReunificacaoAba> {
  final _repositorio = FuncoesRepositorio();
  late Future<List<Map<String, dynamic>>> _futuro;
  String? _processandoId;

  @override
  void initState() {
    super.initState();
    _futuro = _repositorio.listarSolicitacoesReunificacao();
  }

  void _recarregar() {
    setState(() => _futuro = _repositorio.listarSolicitacoesReunificacao());
  }

  Future<void> _confirmar(String id, String nomeTutor) async {
    final confirmou = await confirmarAcao(
      context,
      titulo: "Confirmar reunificação?",
      mensagem:
          'O animal será marcado como reunificado com "$nomeTutor". '
          "Essa ação não pode ser desfeita pelo app.",
      textoConfirmar: "Confirmar",
    );
    if (!confirmou || !mounted) return;

    setState(() => _processandoId = id);
    try {
      await _repositorio.confirmarReunificacao(id);
      _recarregar();
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  Future<void> _recusar(String id, String nomeTutor) async {
    final confirmou = await confirmarAcao(
      context,
      titulo: "Recusar esta solicitação?",
      mensagem:
          'A solicitação de "$nomeTutor" será negada. Se for engano, o '
          "tutor precisará solicitar de novo pelo portal público.",
      textoConfirmar: "Recusar",
      destrutiva: true,
    );
    if (!confirmou || !mounted) return;

    setState(() => _processandoId = id);
    try {
      await _repositorio.recusarReunificacao(id);
      _recarregar();
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _recarregar(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Cores.flare500),
            );
          }
          if (snap.hasError) {
            return const EstadoTela(
              icone: Icons.error_outline,
              cor: Cores.alerta500,
              texto: "Não foi possível carregar as solicitações.",
            );
          }
          final pendentes = (snap.data ?? const [])
              .where((s) => s["status"] == "pendente")
              .toList();
          if (pendentes.isEmpty) {
            return const EstadoTela(
              icone: Icons.volunteer_activism_outlined,
              cor: Cores.textoMedio,
              texto: "Nenhuma solicitação de reunificação pendente.",
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pendentes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final s = pendentes[i];
              final id = s["id"] as String;
              final nomeTutor = (s["nomeTutor"] as String?) ?? "esse tutor";
              final processando = _processandoId == id;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tutor: ${s["nomeTutor"] ?? "—"}",
                      style: Tipografia.tema.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Telefone: ${s["telefoneTutor"] ?? "—"}",
                      style: Tipografia.tema.bodyMedium,
                    ),
                    if ((s["mensagem"] as String?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${s["mensagem"]}"',
                        style: Tipografia.tema.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppBotaoSecundario(
                            texto: processando ? "..." : "Recusar",
                            aoPressionar: processando
                                ? null
                                : () => _recusar(id, nomeTutor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppBotaoPrimario(
                            texto: "Confirmar",
                            carregando: processando,
                            aoPressionar: processando
                                ? null
                                : () => _confirmar(id, nomeTutor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

}
