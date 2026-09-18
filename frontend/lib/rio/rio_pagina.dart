import "dart:async";

import "package:flutter/material.dart";

import "../componentes/app_card.dart";
import "../componentes/app_selo.dart";
import "../componentes/estado_tela.dart";
import "../componentes/paginacao.dart";
import "../dados/funcoes_repositorio.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

const _cameraElevadoJoseThomeUrl =
    "https://public.asthon.com.br/public/stations/elevado_jose_thome/snapshot";
const _intervaloAtualizacao = Duration(seconds: 30);
const _ruasPorPagina = 15;

/// Cota do rio e ruas afetadas — Módulo de Análise e Decisão. Dado público
/// da Defesa Civil de Rio do Sul (API Asthon), sem exigir login.
class RioPagina extends StatefulWidget {
  const RioPagina({super.key});

  @override
  State<RioPagina> createState() => _RioPaginaState();
}

class _RioPaginaState extends State<RioPagina> {
  final _repositorio = FuncoesRepositorio();
  Map<String, dynamic>? _rio;
  List<Map<String, dynamic>>? _estacoes;
  bool _carregando = true;
  String? _erro;
  Timer? _timer;
  int _paginaRuas = 0;

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
      final resultados = await Future.wait([
        _repositorio.buscarRio(),
        _repositorio.buscarEstacoesRio(),
      ]);
      if (!mounted) return;
      setState(() {
        _rio = resultados[0] as Map<String, dynamic>;
        _estacoes = resultados[1] as List<Map<String, dynamic>>;
        _erro = null;
      });
    } catch (_) {
      // Numa atualização automática silenciosa, mantém o último dado bom na
      // tela em vez de trocar por uma mensagem de erro — só a carga inicial
      // (ou o "puxar pra atualizar") mostra erro de fato.
      if (!silencioso && mounted) {
        setState(
          () => _erro = "Não foi possível carregar a cota do rio agora.",
        );
      }
    } finally {
      if (!silencioso && mounted) setState(() => _carregando = false);
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
        heroTag: "atualizar_rio",
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
    final nivelAtual = _rio?["nivelAtual"] as num?;
    final classificacao = _rio?["classificacao"] as String? ?? "normal";
    final ruas =
        (_rio?["ruasBloqueadas"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Interditada primeiro, parcial depois — o que mais importa fica na
    // página 1, não em ordem alfabética ou de cadastro.
    final ruasOrdenadas = [...ruas]
      ..sort((a, b) {
        final pesoA = a["status"] == "interditada" ? 0 : 1;
        final pesoB = b["status"] == "interditada" ? 0 : 1;
        return pesoA.compareTo(pesoB);
      });
    final totalPaginasRuas = totalDePaginas(
      ruasOrdenadas.length,
      _ruasPorPagina,
    );
    final paginaEfetiva = _paginaRuas.clamp(0, totalPaginasRuas - 1);
    final ruasDaPagina = paginar(ruasOrdenadas, paginaEfetiva, _ruasPorPagina);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CameraAoVivo(),
        const SizedBox(height: 16),
        for (final estacao in _estacoes ?? []) ...[
          _EstacaoCard(estacao: estacao),
          const SizedBox(height: 12),
        ],
        if (nivelAtual != null) ...[
          const SizedBox(height: 4),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: classificacaoRioCor[classificacao] ?? Cores.textoMedio,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${classificacaoRioLabel[classificacao] ?? classificacao} · "
                    "${nivelAtual.toStringAsFixed(2)}m (Ponte Dom Tito Buss)",
                    style: Tipografia.tema.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text("Ruas afetadas pela cheia", style: Tipografia.tema.titleMedium),
        const SizedBox(height: 10),
        if (ruas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                AppSelo(
                  icone: nivelAtual == null
                      ? Icons.signal_wifi_off
                      : Icons.water_outlined,
                  corIcone: Cores.textoMedio,
                ),
                const SizedBox(height: 12),
                Text(
                  // Lista vazia por falta de leitura do rio (nivelAtual
                  // null) é uma mensagem diferente de "nenhuma rua afetada
                  // com dado real" — as duas parecem idênticas na tela se
                  // não forem distinguidas, e a segunda pode ser lida como
                  // "tudo liberado" quando na verdade não há dado nenhum.
                  nivelAtual == null
                      ? "Sem leitura do rio no momento — não é possível "
                            "avaliar as ruas."
                      : "Nenhuma rua afetada no nível atual do rio.",
                  style: Tipografia.tema.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          for (final rua in ruasDaPagina) _RuaAfetadaTile(rua: rua),
          PaginacaoControles(
            paginaAtual: paginaEfetiva,
            totalPaginas: totalPaginasRuas,
            aoMudarPagina: (p) => setState(() => _paginaRuas = p),
          ),
        ],
      ],
    );
  }
}

class _EstacaoCard extends StatelessWidget {
  final Map<String, dynamic> estacao;

  const _EstacaoCard({required this.estacao});

  @override
  Widget build(BuildContext context) {
    final nivel = estacao["nivelM"] as num?;
    final bandLabel = estacao["bandLabel"] as String? ?? "Sem dados";
    final chuva1h = estacao["chuva1h"] as num?;
    final chuva24h = estacao["chuva24h"] as num?;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estacao["nome"] as String? ?? "Estação",
                  style: Tipografia.tema.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Cores.ink700,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bandLabel,
                  style: Tipografia.rotulo(cor: Cores.textoAlto, tamanho: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                nivel != null ? nivel.toStringAsFixed(2) : "—",
                style: Tipografia.tema.displaySmall,
              ),
              const SizedBox(width: 6),
              Text("m · nível do rio", style: Tipografia.tema.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Chuva 1h: ${chuva1h?.toStringAsFixed(1) ?? "—"} mm · "
            "24h: ${chuva24h?.toStringAsFixed(1) ?? "—"} mm",
            style: Tipografia.tema.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RuaAfetadaTile extends StatelessWidget {
  final Map<String, dynamic> rua;

  const _RuaAfetadaTile({required this.rua});

  @override
  Widget build(BuildContext context) {
    final status = rua["status"] as String? ?? "parcial";
    final cotaMinima = (rua["cotaMinima"] as num?)?.toDouble();
    final cotaMaxima = (rua["cotaMaxima"] as num?)?.toDouble();
    final cotaMaximaEstimada = rua["cotaMaximaEstimada"] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rua["nome"] as String? ?? "Rua",
                    style: Tipografia.tema.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "alaga a partir de ${cotaMinima?.toStringAsFixed(2) ?? "?"}m"
                    "${cotaMaxima != null ? " · interditada a partir de ${cotaMaxima.toStringAsFixed(2)}m" : ""}"
                    "${cotaMaximaEstimada ? " (estimado)" : ""}",
                    style: Tipografia.tema.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (classificacaoRuaCor[status] ?? Cores.textoMedio)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                classificacaoRuaLabel[status] ?? status,
                style: Tipografia.rotulo(
                  cor: classificacaoRuaCor[status] ?? Cores.textoMedio,
                  tamanho: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snapshot da câmera do Elevado José Thomé, recarregado a cada 30s (mesmo
/// intervalo do sistema web) — não é um fluxo de vídeo de verdade, a fonte
/// pública só oferece uma foto atualizada periodicamente.
class _CameraAoVivo extends StatefulWidget {
  const _CameraAoVivo();

  @override
  State<_CameraAoVivo> createState() => _CameraAoVivoState();
}

class _CameraAoVivoState extends State<_CameraAoVivo> {
  late int _timestamp;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timestamp = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(_intervaloAtualizacao, (_) {
      setState(() => _timestamp = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.fromMillisecondsSinceEpoch(_timestamp);
    final horario =
        "${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.network(
            "$_cameraElevadoJoseThomeUrl?t=$_timestamp",
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 180,
              color: Cores.ink800,
              alignment: Alignment.center,
              child: const Icon(
                Icons.videocam_off_outlined,
                color: Cores.textoBaixo,
                size: 32,
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 180,
                color: Cores.ink800,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Cores.flare500),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                "Atualiza a cada 30s",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                "Elevado José Thomé · Atualizado às $horario",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
