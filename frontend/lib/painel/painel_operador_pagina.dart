import "dart:async";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_card.dart";
import "../componentes/app_selo.dart";
import "../componentes/estado_tela.dart";
import "../componentes/feedback.dart";
import "../componentes/paginacao.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/geo_utils.dart";
import "../dados/maps_utils.dart";
import "../dados/whatsapp_utils.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

// Usada pelo Timer.periodic comentado em initState() (TEMPORÁRIO, ver
// lá) — volta a ser usada quando reativar a atualização automática.
// ignore: unused_element
const _intervaloAtualizacao = Duration(seconds: 30);
const _alertasPorPagina = 10;

/// Painel único do operador de campo — Módulo de Supervisão da Execução.
/// Tudo que quem está resgatando precisa de relance: nível do rio, se a
/// posição atual dele está em risco, e os alertas de resgate mais
/// urgentes/próximos, atualizando sozinho a cada 30s enquanto a tela está
/// aberta.
class PainelOperadorPagina extends StatefulWidget {
  const PainelOperadorPagina({super.key});

  @override
  State<PainelOperadorPagina> createState() => _PainelOperadorPaginaState();
}

class _PainelOperadorPaginaState extends State<PainelOperadorPagina> {
  final _repositorio = FuncoesRepositorio();
  Map<String, dynamic>? _painel;
  Position? _posicao;
  bool _carregando = true;
  String? _processandoAlertaId;
  String? _erro;
  Timer? _timer;
  int _paginaAlertas = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
    // TEMPORÁRIO — desligado pra não estourar a cota gratuita do Firestore
    // (RESOURCE_EXHAUSTED em produção e local, 27/08/2026). Reativar antes
    // da apresentação/testes finais do TCC: descomentar o Timer.periodic
    // abaixo e remover o FloatingActionButton "Atualizar (TEMPORÁRIO)" no
    // fim deste arquivo.
    // _timer = Timer.periodic(
    //   _intervaloAtualizacao,
    //   (_) => _carregar(silencioso: true),
    // );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [silencioso] evita mostrar o spinner de tela cheia nas atualizações
  /// automáticas — só a primeira carga e o "puxar pra atualizar" mostram.
  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final posicao = await obterPosicaoAtual();
      final painel = await _repositorio.buscarPainelOperador(
        latitude: posicao?.latitude,
        longitude: posicao?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _painel = painel;
        _posicao = posicao;
        _erro = null;
      });
    } catch (_) {
      // Atualização automática silenciosa mantém o último dado bom na
      // tela em vez de trocar por erro — só a carga inicial (ou o "puxar
      // pra atualizar") mostra erro de fato.
      if (!silencioso && mounted) {
        setState(() => _erro = "Não foi possível carregar o painel agora.");
      }
    } finally {
      if (!silencioso && mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _atender(String id) async {
    setState(() => _processandoAlertaId = id);
    try {
      await _repositorio.marcarResgateEmAtendimento(id);
      await _carregar(silencioso: true);
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoAlertaId = null);
    }
  }

  Future<void> _concluir(String id) async {
    setState(() => _processandoAlertaId = id);
    try {
      await _repositorio.marcarResgateConcluido(id);
      await _carregar(silencioso: true);
    } on FuncaoRepositorioException catch (e) {
      if (mounted) mostrarErro(context, e.mensagem);
    } catch (_) {
      if (mounted) mostrarErro(context, "Não foi possível concluir a ação.");
    } finally {
      if (mounted) setState(() => _processandoAlertaId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _carregar,
        color: Cores.flare500,
        child: _carregando
            ? const Center(
                child: CircularProgressIndicator(color: Cores.flare500),
              )
            : _erro != null
            ? _estadoErro()
            : _conteudo(),
      ),
      // TEMPORÁRIO — ver o comentário em initState(). Remover junto com a
      // reativação do Timer.periodic.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "atualizar_painel_operador",
        backgroundColor: Cores.flare500,
        icon: const Icon(Icons.refresh),
        label: const Text("Atualizar (TEMPORÁRIO)"),
        onPressed: () => _carregar(),
      ),
    );
  }

  Widget _estadoErro() {
    return ListView(
      children: [
        EstadoTela(
          icone: Icons.error_outline,
          cor: Cores.alerta500,
          texto: _erro!,
        ),
      ],
    );
  }

  Widget _conteudo() {
    final painel = _painel ?? const {};
    final rio = painel["rio"] as Map<String, dynamic>? ?? const {};
    final nivelAtual = rio["nivelAtual"] as num?;
    // Nunca cair pra "normal" — sem dado é sem dado, não "rio baixo".
    final classificacaoRio = rio["classificacao"] as String?;
    final riscoOperador = painel["riscoOperador"] as Map<String, dynamic>?;
    final alertas =
        (painel["alertasProximos"] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final totalPaginasAlertas = totalDePaginas(
      alertas.length,
      _alertasPorPagina,
    );
    final paginaEfetiva = _paginaAlertas.clamp(0, totalPaginasAlertas - 1);
    final alertasDaPagina = paginar(alertas, paginaEfetiva, _alertasPorPagina);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_posicao == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCallout(
              texto:
                  "Sem acesso à sua localização — ative o GPS pra ver "
                  "se você está numa área de risco e ordenar os alertas "
                  "pelos mais próximos.",
              tipo: TipoCallout.info,
              icone: Icons.location_off_outlined,
            ),
          ),
        if (riscoOperador != null &&
            (riscoOperador["classificacaoRua"] == "parcial" ||
                riscoOperador["classificacaoRua"] == "interditada"))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCallout(
              texto: "Você está numa área de risco: ${riscoOperador["motivo"]}",
              tipo: TipoCallout.urgente,
              icone: Icons.warning_amber_rounded,
            ),
          ),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: classificacaoRio == null
                      ? Cores.textoMedio
                      : classificacaoRioCor[classificacaoRio] ??
                            Cores.textoMedio,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nivelAtual == null || classificacaoRio == null
                      ? "Sem leitura do rio no momento"
                      : "Rio: ${classificacaoRioLabel[classificacaoRio] ?? classificacaoRio} "
                            "· ${nivelAtual.toStringAsFixed(2)}m",
                  style: Tipografia.tema.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Alertas de resgate mais urgentes",
          style: Tipografia.tema.titleMedium,
        ),
        const SizedBox(height: 10),
        if (alertas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const AppSelo(
                  icone: Icons.check_circle_outline,
                  corIcone: Cores.safe500,
                ),
                const SizedBox(height: 12),
                Text(
                  "Nenhum alerta de resgate pendente no momento.",
                  style: Tipografia.tema.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          for (final item in alertasDaPagina)
            _AlertaCartao(
              item: item,
              processando:
                  _processandoAlertaId ==
                  (item["alerta"] as Map<String, dynamic>)["id"],
              aoAtender: _atender,
              aoConcluir: _concluir,
            ),
          PaginacaoControles(
            paginaAtual: paginaEfetiva,
            totalPaginas: totalPaginasAlertas,
            aoMudarPagina: (p) => setState(() => _paginaAlertas = p),
          ),
        ],
      ],
    );
  }
}

class _AlertaCartao extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool processando;
  final ValueChanged<String> aoAtender;
  final ValueChanged<String> aoConcluir;

  const _AlertaCartao({
    required this.item,
    required this.processando,
    required this.aoAtender,
    required this.aoConcluir,
  });

  @override
  Widget build(BuildContext context) {
    final alerta = item["alerta"] as Map<String, dynamic>;
    final id = alerta["id"] as String;
    final status = alerta["status"] as String? ?? "pendente";
    final classificacaoRua =
        item["classificacaoRua"] as String? ?? "desconhecida";
    final distancia = (item["distanciaKm"] as num?)?.toDouble();
    final fotoUrl = alerta["fotoUrl"] as String?;
    final latitude = (alerta["latitude"] as num?)?.toDouble();
    final longitude = (alerta["longitude"] as num?)?.toDouble();
    final telefone = alerta["telefoneContato"] as String?;

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
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta["descricaoSituacao"] as String? ?? "",
                        style: Tipografia.tema.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${alerta["rua"] ?? "—"}, ${alerta["bairro"] ?? "—"}"
                        "${distancia != null ? " · ${distancia.toStringAsFixed(1)}km" : ""}",
                        style: Tipografia.tema.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (classificacaoRuaCor[classificacaoRua] ??
                                Cores.textoMedio)
                            .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    classificacaoRuaLabel[classificacaoRua] ??
                        classificacaoRua,
                    style: Tipografia.rotulo(
                      cor:
                          classificacaoRuaCor[classificacaoRua] ??
                          Cores.textoMedio,
                      tamanho: 11,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Cores.ink700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status == "pendente" ? "Pendente" : "Em atendimento",
                    style: Tipografia.rotulo(cor: Cores.textoAlto, tamanho: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (latitude != null && longitude != null)
                  TextButton.icon(
                    onPressed: () => abrirRotaAte(latitude, longitude),
                    icon: const Icon(
                      Icons.directions,
                      size: 16,
                      color: Cores.water500,
                    ),
                    label: Text(
                      "Como chegar",
                      style: Tipografia.rotulo(
                        cor: Cores.water500,
                        tamanho: 12,
                      ),
                    ),
                  ),
                if (telefone != null && telefone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => abrirWhatsApp(
                      telefone,
                      mensagem:
                          "Olá! Aqui é da equipe do PetGuia Enchentes 🐾. "
                          "Estamos a caminho pra ajudar com o resgate que você "
                          "reportou.",
                    ),
                    icon: const Icon(
                      Icons.chat_outlined,
                      size: 16,
                      color: Cores.safe500,
                    ),
                    label: Text(
                      "WhatsApp",
                      style: Tipografia.rotulo(cor: Cores.safe500, tamanho: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (status == "pendente")
              AppBotaoPrimario(
                texto: processando ? "..." : "Atender",
                carregando: processando,
                aoPressionar: processando ? null : () => aoAtender(id),
              )
            else
              AppBotaoSecundario(
                texto: processando ? "..." : "Concluir",
                aoPressionar: processando ? null : () => aoConcluir(id),
              ),
          ],
        ),
      ),
    );
  }
}
