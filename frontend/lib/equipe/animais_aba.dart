import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/confirmar_acao.dart";
import "../componentes/estado_tela.dart";
import "../componentes/feedback.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/modelos/animal.dart";
import "../dados/portal_repositorio.dart";
import "../portal/animal_cartao.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "cadastrar_animal_pagina.dart";

/// Lista de animais com as ações de transição de status da equipe —
/// mesmo fluxo do Módulo de Planejamento da Execução: resgatado →
/// em_abrigo → reunificado/com_tutor.
class AnimaisAba extends StatefulWidget {
  const AnimaisAba({super.key});

  @override
  State<AnimaisAba> createState() => _AnimaisAbaState();
}

class _AnimaisAbaState extends State<AnimaisAba> {
  final _repositorio = FuncoesRepositorio();
  String? _processandoId;
  Map<String, Map<String, dynamic>> _urgenciaPorId = {};

  @override
  void initState() {
    super.initState();
    _carregarUrgencia();
  }

  /// Busca o ranking de urgência (Módulo de Análise e Decisão) — reforço
  /// visual sobre a lista de resgatados; se falhar, a lista continua
  /// funcional na ordem padrão, só sem a ordenação por risco.
  Future<void> _carregarUrgencia() async {
    try {
      final ranking = await _repositorio.listarUrgencia();
      if (!mounted) return;
      setState(() {
        _urgenciaPorId = {
          for (final r in ranking) (r["animal"] as Map)["id"] as String: r,
        };
      });
    } catch (_) {
      // Ranking é um reforço, não crítico — segue sem ordenar por urgência.
    }
  }

  Future<void> _executar(String animalId, Future<void> Function() acao) async {
    if (!mounted) return;
    setState(() => _processandoId = animalId);
    try {
      await acao();
      _carregarUrgencia();
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  /// "Marcar reunificado"/"Marcar com tutor" encerram o ciclo de vida do
  /// animal no sistema — pede confirmação antes, mesmo motivo do
  /// [confirmarAcao] na aba de Reunificação.
  Future<void> _executarComConfirmacao(
    Animal animal, {
    required String titulo,
    required String mensagem,
    required String textoConfirmar,
    required Future<void> Function() acao,
  }) async {
    final confirmou = await confirmarAcao(
      context,
      titulo: titulo,
      mensagem: mensagem,
      textoConfirmar: textoConfirmar,
    );
    if (!confirmou) return;
    await _executar(animal.id, acao);
  }

  Future<void> _abrirSeletorDeAbrigo(Animal animal) async {
    final abrigoId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Cores.ink800,
      builder: (context) => _SeletorDeAbrigoFolha(),
    );
    if (abrigoId == null) return;
    await _executar(
      animal.id,
      () => _repositorio.marcarAnimalComoEmAbrigo(animal.id, abrigoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Animal>>(
        stream: PortalRepositorio().animais(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EstadoTela(
              icone: Icons.error_outline,
              cor: Cores.alerta500,
              texto: "Não foi possível carregar os animais.",
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Cores.flare500),
            );
          }
          final animais = _ordenarPorUrgencia(snap.data!);
          if (animais.isEmpty) {
            return const EstadoTela(
              icone: Icons.pets,
              cor: Cores.textoMedio,
              texto: "Nenhum animal cadastrado ainda.",
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: animais.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final animal = animais[i];
              final processando = _processandoId == animal.id;
              final urgencia = _urgenciaPorId[animal.id];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimalCartao(animal: animal),
                  if (animal.status == StatusAnimal.resgatado &&
                      urgencia != null) ...[
                    const SizedBox(height: 6),
                    _UrgenciaEtiqueta(urgencia: urgencia),
                  ],
                  const SizedBox(height: 8),
                  _acoesPara(animal, processando),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Cores.flare500,
        icon: const Icon(Icons.add),
        label: const Text("Novo resgate"),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CadastrarAnimalPagina()),
        ),
      ),
    );
  }

  /// Coloca os "resgatados" em ordem de urgência (Módulo de Análise e
  /// Decisão) antes dos demais, que mantêm a ordem por data de cadastro.
  List<Animal> _ordenarPorUrgencia(List<Animal> animais) {
    final resgatados = animais
        .where((a) => a.status == StatusAnimal.resgatado)
        .toList();
    final outros = animais
        .where((a) => a.status != StatusAnimal.resgatado)
        .toList();

    resgatados.sort((a, b) {
      final pontuacaoA =
          _urgenciaPorId[a.id]?["pontuacaoUrgencia"] as num? ?? -1;
      final pontuacaoB =
          _urgenciaPorId[b.id]?["pontuacaoUrgencia"] as num? ?? -1;
      return pontuacaoB.compareTo(pontuacaoA);
    });

    return [...resgatados, ...outros];
  }

  Widget _acoesPara(Animal animal, bool processando) {
    switch (animal.status) {
      case StatusAnimal.resgatado:
        return AppBotaoSecundario(
          texto: processando ? "..." : "Alocar em abrigo",
          aoPressionar: processando
              ? null
              : () => _abrirSeletorDeAbrigo(animal),
        );
      case StatusAnimal.emAbrigo:
        return Row(
          children: [
            Expanded(
              child: AppBotaoSecundario(
                texto: processando ? "..." : "Marcar reunificado",
                aoPressionar: processando
                    ? null
                    : () => _executarComConfirmacao(
                        animal,
                        titulo: "Marcar como reunificado?",
                        mensagem:
                            "O animal será marcado como reunificado com o "
                            "tutor original. Essa ação encerra o "
                            "acompanhamento dele no sistema.",
                        textoConfirmar: "Marcar reunificado",
                        acao: () =>
                            _repositorio.marcarAnimalComoReunificado(animal.id),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppBotaoSecundario(
                texto: processando ? "..." : "Marcar com tutor",
                aoPressionar: processando
                    ? null
                    : () => _executarComConfirmacao(
                        animal,
                        titulo: "Marcar com tutor temporário?",
                        mensagem:
                            "O animal sai da lista de abrigo e passa a "
                            "constar como sob cuidados de um tutor "
                            "temporário.",
                        textoConfirmar: "Marcar com tutor",
                        acao: () =>
                            _repositorio.marcarAnimalComoComTutor(animal.id),
                      ),
              ),
            ),
          ],
        );
      case StatusAnimal.comTutor:
      case StatusAnimal.reunificado:
        return const SizedBox.shrink();
    }
  }

}

/// Explica a posição do animal no ranking de urgência — a rua onde foi
/// encontrado e o motivo calculado pelo Módulo de Análise e Decisão, para
/// a equipe entender a ordem, não só confiar nela às cegas.
class _UrgenciaEtiqueta extends StatelessWidget {
  final Map<String, dynamic> urgencia;

  const _UrgenciaEtiqueta({required this.urgencia});

  @override
  Widget build(BuildContext context) {
    final classificacao =
        urgencia["classificacaoRua"] as String? ?? "desconhecida";
    final cor = classificacaoRuaCor[classificacao] ?? Cores.textoMedio;
    final motivo = urgencia["motivo"] as String? ?? "";

    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 14, color: cor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            motivo,
            style: Tipografia.rotulo(cor: cor, tamanho: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SeletorDeAbrigoFolha extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Abrigo>>(
        stream: PortalRepositorio().abrigos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: EstadoTela(
                icone: Icons.error_outline,
                cor: Cores.alerta500,
                texto: "Não foi possível carregar os abrigos.",
              ),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: Cores.flare500),
              ),
            );
          }
          final comVaga = snap.data!
              .where((a) => a.capacidadeOcupada < a.capacidadeTotal)
              .toList();
          if (comVaga.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Nenhum abrigo com vaga disponível no momento.",
                style: Tipografia.tema.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  "Escolha o abrigo",
                  style: Tipografia.tema.titleMedium,
                ),
              ),
              for (final a in comVaga)
                ListTile(
                  leading: const Icon(
                    Icons.home_outlined,
                    color: Cores.water500,
                  ),
                  title: Text(a.nome, style: Tipografia.tema.bodyLarge),
                  subtitle: Text(
                    "${a.capacidadeOcupada}/${a.capacidadeTotal} ocupado",
                    style: Tipografia.tema.bodySmall,
                  ),
                  onTap: () => Navigator.of(context).pop(a.id),
                ),
            ],
          );
        },
      ),
    );
  }
}
