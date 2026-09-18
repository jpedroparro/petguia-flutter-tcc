import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../componentes/feedback.dart";
import "../dados/funcoes_repositorio.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Fila de alertas de resgate urgente — animais presos/ilhados que
/// precisam de equipamento especial (barco, etc.), reportados pelo
/// público. Defesa Civil/bombeiros logados atendem e concluem por aqui.
class ResgatesAba extends StatefulWidget {
  const ResgatesAba({super.key});

  @override
  State<ResgatesAba> createState() => _ResgatesAbaState();
}

class _ResgatesAbaState extends State<ResgatesAba> {
  final _repositorio = FuncoesRepositorio();
  late Future<List<Map<String, dynamic>>> _futuro;
  String? _processandoId;

  @override
  void initState() {
    super.initState();
    _futuro = _repositorio.listarSolicitacoesResgate();
  }

  void _recarregar() {
    setState(() => _futuro = _repositorio.listarSolicitacoesResgate());
  }

  Future<void> _atender(String id) async {
    setState(() => _processandoId = id);
    try {
      await _repositorio.marcarResgateEmAtendimento(id);
      _recarregar();
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  Future<void> _concluir(String id) async {
    setState(() => _processandoId = id);
    try {
      await _repositorio.marcarResgateConcluido(id);
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
              texto: "Não foi possível carregar os alertas.",
            );
          }
          final todos = snap.data ?? const [];
          final pendentes = todos
              .where((s) => s["status"] == "pendente")
              .toList();
          final emAtendimento = todos
              .where((s) => s["status"] == "em_atendimento")
              .toList();
          final concluidos = todos
              .where((s) => s["status"] == "concluido")
              .toList();

          if (pendentes.isEmpty &&
              emAtendimento.isEmpty &&
              concluidos.isEmpty) {
            return const EstadoTela(
              icone: Icons.warning_amber_outlined,
              cor: Cores.textoMedio,
              texto: "Nenhum alerta de resgate registrado.",
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pendentes.isNotEmpty) ...[
                _titulo("🚨 PENDENTES", Cores.alerta500, pendentes.length),
                for (final s in pendentes)
                  _cartao(
                    s,
                    cor: Cores.alerta500,
                    botao: AppBotaoPrimario(
                      texto: "Atender",
                      carregando: _processandoId == s["id"],
                      aoPressionar: _processandoId == s["id"]
                          ? null
                          : () => _atender(s["id"] as String),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (emAtendimento.isNotEmpty) ...[
                _titulo("EM ATENDIMENTO", Cores.flare500, emAtendimento.length),
                for (final s in emAtendimento)
                  _cartao(
                    s,
                    cor: Cores.flare500,
                    botao: AppBotaoPrimario(
                      texto: "Concluir",
                      carregando: _processandoId == s["id"],
                      aoPressionar: _processandoId == s["id"]
                          ? null
                          : () => _concluir(s["id"] as String),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (concluidos.isNotEmpty)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    iconColor: Cores.safe500,
                    collapsedIconColor: Cores.safe500,
                    title: Text(
                      "✅ Concluídos (${concluidos.length})",
                      style: Tipografia.tema.titleMedium,
                    ),
                    children: [
                      for (final s in concluidos)
                        _cartao(s, cor: Cores.safe500),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _titulo(String texto, Color cor, int contagem) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        "$texto ($contagem)",
        style: Tipografia.rotulo(cor: cor, tamanho: 12, peso: FontWeight.w700),
      ),
    );
  }

  Widget _cartao(Map<String, dynamic> s, {required Color cor, Widget? botao}) {
    final rua = s["rua"] as String? ?? "";
    final bairro = s["bairro"] as String? ?? "";
    final fotoUrl = s["fotoUrl"] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fotoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      fotoUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(Icons.warning_amber_rounded, color: cor, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    s["descricaoSituacao"] as String? ?? "",
                    style: Tipografia.tema.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("$rua, $bairro", style: Tipografia.tema.bodyMedium),
            const SizedBox(height: 4),
            Text(
              "Contato: ${s["nomeContato"] ?? "—"} · "
              "${s["telefoneContato"] ?? "—"}",
              style: Tipografia.tema.bodySmall,
            ),
            if (botao != null) ...[const SizedBox(height: 14), botao],
          ],
        ),
      ),
    );
  }

}
