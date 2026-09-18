import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../componentes/paginacao.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/geo_utils.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/modelos/animal.dart";
import "../dados/portal_repositorio.dart";
import "../equipe/equipe_pagina.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "animal_cartao.dart";
import "solicitar_reunificacao_pagina.dart";

const _raioBuscaKm = 10.0;
const _itensPorPagina = 10;

/// Coordenada de destino de um animal, pra "Como chegar": o próprio ponto
/// de resgate (aguardando abrigo) ou a localização do abrigo (em abrigo).
/// "Com tutor"/"reunificado" não têm um destino rastreável.
({double latitude, double longitude})? _destinoDoAnimal(
  Animal animal,
  List<Abrigo> abrigos,
) {
  if (animal.status == StatusAnimal.resgatado &&
      animal.latitudeResgate != null &&
      animal.longitudeResgate != null) {
    return (
      latitude: animal.latitudeResgate!,
      longitude: animal.longitudeResgate!,
    );
  }
  if (animal.status == StatusAnimal.emAbrigo) {
    for (final abrigo in abrigos) {
      if (abrigo.id == animal.abrigoId &&
          abrigo.latitude != null &&
          abrigo.longitude != null) {
        return (latitude: abrigo.latitude!, longitude: abrigo.longitude!);
      }
    }
  }
  return null;
}

/// Animais dentro do raio de busca a partir de uma origem — só considera
/// quem tem destino rastreável (resgatado com coordenada, ou em abrigo);
/// "com tutor"/"reunificado" nunca entram numa busca por região ativa.
List<Animal> _filtrarPorRegiao(
  List<Animal> animais,
  List<Abrigo> abrigos,
  ({double latitude, double longitude})? origem,
) {
  if (origem == null) return animais;
  return animais.where((animal) {
    final destino = _destinoDoAnimal(animal, abrigos);
    if (destino == null) return false;
    return distanciaKm(
          origem.latitude,
          origem.longitude,
          destino.latitude,
          destino.longitude,
        ) <=
        _raioBuscaKm;
  }).toList();
}

/// Tela inicial do app — portal público, sem exigir login. Mesma ideia do
/// portal do sistema web: agrupado por abrigo, com uma seção destacada para
/// quem ainda não tem vaga, e busca por região pra filtrar por proximidade.
class PortalPagina extends StatefulWidget {
  const PortalPagina({super.key});

  @override
  State<PortalPagina> createState() => _PortalPaginaState();
}

class _PortalPaginaState extends State<PortalPagina> {
  final _repositorioPortal = PortalRepositorio();
  final _repositorio = FuncoesRepositorio();
  final _buscaControlador = TextEditingController();

  ({double latitude, double longitude})? _origemBusca;
  String? _origemBuscaRotulo;
  bool _buscando = false;
  bool _obtendoLocalizacao = false;
  String? _erroBusca;
  String? _abrigoFiltroId;

  @override
  void dispose() {
    _buscaControlador.dispose();
    super.dispose();
  }

  Future<void> _buscarPorRegiao() async {
    final texto = _buscaControlador.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _buscando = true;
      _erroBusca = null;
    });
    try {
      final coordenadas = await _repositorio.geocodificarEndereco(texto);
      if (coordenadas == null) {
        setState(
          () => _erroBusca = "Não encontramos esse endereço em Rio do Sul.",
        );
        return;
      }
      setState(() {
        _origemBusca = coordenadas;
        _origemBuscaRotulo = texto;
      });
    } catch (_) {
      setState(
        () => _erroBusca = "Não foi possível buscar agora. Tente de novo.",
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  /// Busca direto pela localização atual do aparelho — sem precisar
  /// digitar CEP/rua. Usa a coordenada como origem e faz geocodificação
  /// reversa só pra montar o rótulo exibido ("perto de ...").
  Future<void> _buscarPorLocalizacaoAtual() async {
    setState(() {
      _obtendoLocalizacao = true;
      _erroBusca = null;
    });
    try {
      final posicao = await obterPosicaoAtual();
      if (posicao == null) {
        if (mounted) {
          setState(
            () => _erroBusca = "Não foi possível obter sua localização agora.",
          );
        }
        return;
      }

      String rotulo = "sua localização atual";
      final endereco = await _repositorio.buscarEnderecoPorCoordenadas(
        posicao.latitude,
        posicao.longitude,
      );
      final rua = endereco?["rua"] as String?;
      final bairro = endereco?["bairro"] as String?;
      if (rua != null || bairro != null) {
        rotulo = [
          rua,
          bairro,
        ].where((v) => v != null && v.isNotEmpty).join(", ");
      }

      setState(() {
        _origemBusca = (
          latitude: posicao.latitude,
          longitude: posicao.longitude,
        );
        _origemBuscaRotulo = rotulo;
        _buscaControlador.text = rotulo;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _erroBusca = "Não foi possível obter sua localização agora.",
        );
      }
    } finally {
      if (mounted) setState(() => _obtendoLocalizacao = false);
    }
  }

  void _limparBusca() {
    setState(() {
      _origemBusca = null;
      _origemBuscaRotulo = null;
      _erroBusca = null;
      _buscaControlador.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🐾"),
            const SizedBox(width: 8),
            Text("PetGuia Enchentes", style: Tipografia.tema.headlineMedium),
          ],
        ),
        actions: [_AcaoConta()],
      ),
      body: StreamBuilder<List<Abrigo>>(
        stream: _repositorioPortal.abrigos(),
        builder: (context, abrigosSnap) {
          if (abrigosSnap.hasError) {
            return const EstadoTela(
              icone: Icons.error_outline,
              cor: Cores.alerta500,
              texto: "Não foi possível carregar os abrigos agora.",
            );
          }
          if (!abrigosSnap.hasData) {
            return const _EstadoCarregando();
          }
          final abrigos = abrigosSnap.data!;

          return StreamBuilder<List<Animal>>(
            stream: _repositorioPortal.animais(),
            builder: (context, animaisSnap) {
              if (animaisSnap.hasError) {
                return const EstadoTela(
                  icone: Icons.error_outline,
                  cor: Cores.alerta500,
                  texto: "Não foi possível carregar os animais agora.",
                );
              }
              if (!animaisSnap.hasData) {
                return const _EstadoCarregando();
              }
              final animais = animaisSnap.data!;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CartaoBuscaRegiao(
                    controlador: _buscaControlador,
                    buscando: _buscando,
                    obtendoLocalizacao: _obtendoLocalizacao,
                    erro: _erroBusca,
                    origemAtivaRotulo: _origemBuscaRotulo,
                    totalEncontrados: _origemBusca == null
                        ? null
                        : _filtrarPorRegiao(
                            animais,
                            abrigos,
                            _origemBusca,
                          ).length,
                    totalGeral: animais.length,
                    aoBuscar: _buscarPorRegiao,
                    aoUsarLocalizacao: _buscarPorLocalizacaoAtual,
                    aoLimpar: _limparBusca,
                  ),
                  const SizedBox(height: 12),
                  _SeletorAbrigoFiltro(
                    abrigos: abrigos,
                    valor: _abrigoFiltroId,
                    aoMudar: (v) => setState(() => _abrigoFiltroId = v),
                  ),
                  const SizedBox(height: 16),
                  if (animais.isEmpty)
                    const _EstadoVazio()
                  else
                    _Conteudo(
                      animais: animais,
                      abrigos: abrigos,
                      origemBusca: _origemBusca,
                      abrigoFiltroId: _abrigoFiltroId,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CartaoBuscaRegiao extends StatelessWidget {
  final TextEditingController controlador;
  final bool buscando;
  final bool obtendoLocalizacao;
  final String? erro;
  final String? origemAtivaRotulo;
  final int? totalEncontrados;
  final int totalGeral;
  final VoidCallback aoBuscar;
  final VoidCallback aoUsarLocalizacao;
  final VoidCallback aoLimpar;

  const _CartaoBuscaRegiao({
    required this.controlador,
    required this.buscando,
    required this.obtendoLocalizacao,
    required this.erro,
    required this.origemAtivaRotulo,
    required this.totalEncontrados,
    required this.totalGeral,
    required this.aoBuscar,
    required this.aoUsarLocalizacao,
    required this.aoLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Buscar por região", style: Tipografia.tema.titleMedium),
          const SizedBox(height: 2),
          Text(
            "Digite seu CEP ou rua — mostramos os animais num raio de "
            "${_raioBuscaKm.toStringAsFixed(0)}km.",
            style: Tipografia.tema.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCampoTexto(
                  controller: controlador,
                  rotulo: "CEP ou rua",
                  icone: Icons.location_searching,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 88,
                child: AppBotaoPrimario(
                  texto: buscando ? "..." : "Buscar",
                  carregando: buscando,
                  aoPressionar: buscando ? null : aoBuscar,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Cores.ink700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Cores.lineForte),
                  ),
                  child: Tooltip(
                    message: "Buscar pela minha localização",
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: obtendoLocalizacao ? null : aoUsarLocalizacao,
                        child: Center(
                          child: obtendoLocalizacao
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Cores.flare500,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  size: 18,
                                  color: Cores.flare500,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (erro != null) ...[
            const SizedBox(height: 8),
            Text(
              erro!,
              style: Tipografia.rotulo(cor: Cores.alerta500, tamanho: 12),
            ),
          ],
          if (origemAtivaRotulo != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.filter_alt, size: 14, color: Cores.flare500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$totalEncontrados de $totalGeral animais num raio de "
                    "${_raioBuscaKm.toStringAsFixed(0)}km de \"$origemAtivaRotulo\"",
                    style: Tipografia.rotulo(cor: Cores.flare500, tamanho: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: aoLimpar,
                  child: Text(
                    "Limpar",
                    style: Tipografia.rotulo(
                      cor: Cores.textoMedio,
                      tamanho: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Filtro direto por abrigo — reduz a rolagem quando já se sabe qual
/// abrigo procurar, mostrando só o bloco daquele abrigo em vez da lista
/// inteira.
class _SeletorAbrigoFiltro extends StatelessWidget {
  final List<Abrigo> abrigos;
  final String? valor;
  final ValueChanged<String?> aoMudar;

  const _SeletorAbrigoFiltro({
    required this.abrigos,
    required this.valor,
    required this.aoMudar,
  });

  @override
  Widget build(BuildContext context) {
    if (abrigos.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      initialValue: valor,
      dropdownColor: Cores.ink800,
      isExpanded: true,
      style: const TextStyle(color: Cores.textoAlto),
      decoration: const InputDecoration(
        labelText: "Filtrar por abrigo",
        prefixIcon: Icon(Icons.home_outlined, color: Cores.textoBaixo),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text("Todos os abrigos")),
        for (final a in abrigos)
          DropdownMenuItem(
            value: a.id,
            child: Text(a.nome, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: aoMudar,
    );
  }
}

/// Menu com "Sair" (logado) no topo — login agora é a tela inicial do app,
/// então quem chega no portal deslogado (via "Consulta") não vê nada aqui;
/// só quem entrou logado e navegou pro portal vê o atalho de volta.
class _AcaoConta extends StatelessWidget {
  const _AcaoConta();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final usuario = snap.data;
        if (usuario == null) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: Cores.water500),
              tooltip: "Painel da equipe",
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const EquipePagina())),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Cores.textoMedio),
              tooltip: "Sair (${usuario.email})",
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        );
      },
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String rotulo;
  final String titulo;
  final int contagem;
  final Color cor;

  const _TituloSecao({
    required this.rotulo,
    required this.titulo,
    required this.contagem,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Tipografia.rotulo(cor: cor)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(titulo, style: Tipografia.tema.headlineMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Cores.ink800,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Cores.line),
                ),
                child: Text(
                  "$contagem",
                  style: Tipografia.rotulo(cor: Cores.textoMedio, tamanho: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends StatefulWidget {
  final List<Animal> animais;
  final List<Abrigo> abrigos;
  final ({double latitude, double longitude})? origemBusca;
  final String? abrigoFiltroId;

  const _Conteudo({
    required this.animais,
    required this.abrigos,
    this.origemBusca,
    this.abrigoFiltroId,
  });

  @override
  State<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends State<_Conteudo> {
  // Página atual por seção (aguardando/abrigo-<id>/comTutor/reunificados)
  // — cada seção pagina de forma independente, mesmo padrão de
  // rio_pagina.dart/painel_operador_pagina.dart.
  final Map<String, int> _paginas = {};

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrarPorRegiao(
      widget.animais,
      widget.abrigos,
      widget.origemBusca,
    );

    if (widget.origemBusca != null && filtrados.isEmpty) {
      return EstadoTela(
        icone: Icons.search_off,
        cor: Cores.textoMedio,
        texto: "Nenhum animal com localização conhecida num raio de "
            "${_raioBuscaKm.toStringAsFixed(0)}km dessa região.",
      );
    }

    // Com um abrigo específico selecionado no filtro, mostra só o bloco
    // dele — o resto (aguardando abrigo, com tutor, reunificados, outros
    // abrigos) some da tela pra cortar a rolagem.
    final filtrandoPorAbrigo = widget.abrigoFiltroId != null;

    final aguardandoAbrigo = filtrandoPorAbrigo
        ? const <Animal>[]
        : filtrados.where((a) => a.status == StatusAnimal.resgatado).toList();
    final comTutor = filtrandoPorAbrigo
        ? const <Animal>[]
        : filtrados.where((a) => a.status == StatusAnimal.comTutor).toList();
    final reunificados = filtrandoPorAbrigo
        ? const <Animal>[]
        : filtrados.where((a) => a.status == StatusAnimal.reunificado).toList();

    final gruposPorAbrigo = widget.abrigos
        .where(
          (abrigo) => !filtrandoPorAbrigo || abrigo.id == widget.abrigoFiltroId,
        )
        .map((abrigo) {
          final doAbrigo = filtrados
              .where(
                (a) =>
                    a.status == StatusAnimal.emAbrigo &&
                    a.abrigoId == abrigo.id,
              )
              .toList();
          return (abrigo: abrigo, animais: doAbrigo);
        })
        .where((grupo) => filtrandoPorAbrigo || grupo.animais.isNotEmpty)
        .toList();

    if (aguardandoAbrigo.isEmpty &&
        comTutor.isEmpty &&
        reunificados.isEmpty &&
        gruposPorAbrigo.isEmpty) {
      return const _EstadoVazio();
    }

    Widget cartao(Animal a, {VoidCallback? aoSolicitar}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimalCartao(
        animal: a,
        destino: _destinoDoAnimal(a, widget.abrigos),
        aoSolicitar: aoSolicitar,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aguardandoAbrigo.isNotEmpty) ...[
          _TituloSecao(
            rotulo: "AGUARDANDO ABRIGO",
            titulo: "🆘 Resgatados",
            contagem: aguardandoAbrigo.length,
            cor: Cores.flare500,
          ),
          ..._secaoPaginada(
            chave: "aguardando",
            lista: aguardandoAbrigo,
            construirCartao: (a) =>
                cartao(a, aoSolicitar: () => _abrirSolicitacao(context, a)),
          ),
          const SizedBox(height: 16),
        ],
        for (final grupo in gruposPorAbrigo) ...[
          _TituloSecao(
            rotulo: "ABRIGO",
            titulo: "🏠 ${grupo.abrigo.nome}",
            contagem: grupo.animais.length,
            cor: Cores.water500,
          ),
          ..._secaoPaginada(
            chave: "abrigo-${grupo.abrigo.id}",
            lista: grupo.animais,
            construirCartao: (a) =>
                cartao(a, aoSolicitar: () => _abrirSolicitacao(context, a)),
          ),
          const SizedBox(height: 16),
        ],
        if (comTutor.isNotEmpty) ...[
          _TituloSecao(
            rotulo: "SOB CUIDADOS TEMPORÁRIOS",
            titulo: "🏡 Com tutor",
            contagem: comTutor.length,
            cor: Cores.safe500,
          ),
          ..._secaoPaginada(
            chave: "comTutor",
            lista: comTutor,
            construirCartao: cartao,
          ),
          const SizedBox(height: 16),
        ],
        if (reunificados.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              iconColor: Cores.safe500,
              collapsedIconColor: Cores.safe500,
              title: Text(
                "✅ Reunificados (${reunificados.length})",
                style: Tipografia.tema.titleMedium,
              ),
              children: _secaoPaginada(
                chave: "reunificados",
                lista: reunificados,
                construirCartao: cartao,
              ),
            ),
          ),
      ],
    );
  }

  /// Corta uma seção de animais em páginas de [_itensPorPagina] — sem
  /// isso, um abrigo (ou a soma das seções) com muitos animais vira um
  /// grid gigantesco de rolagem só numa tela.
  List<Widget> _secaoPaginada({
    required String chave,
    required List<Animal> lista,
    required Widget Function(Animal) construirCartao,
  }) {
    final totalPaginas = totalDePaginas(lista.length, _itensPorPagina);
    final paginaEfetiva = (_paginas[chave] ?? 0).clamp(0, totalPaginas - 1);
    final itensDaPagina = paginar(lista, paginaEfetiva, _itensPorPagina);

    return [
      for (final a in itensDaPagina) construirCartao(a),
      PaginacaoControles(
        paginaAtual: paginaEfetiva,
        totalPaginas: totalPaginas,
        aoMudarPagina: (p) => setState(() => _paginas[chave] = p),
      ),
    ];
  }
}

/// Única ação pública sobre um animal já listado: pedir a devolução como
/// tutor original (reunificação). Virar tutor temporário só se decide no
/// momento do resgate, pela equipe — um estranho pelo portal não pode
/// reivindicar tutoria de um animal que só viu numa foto (ver
/// `equipe/cadastrar_animal_pagina.dart`).
void _abrirSolicitacao(BuildContext context, Animal animal) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SolicitarReunificacaoPagina(animalId: animal.id),
    ),
  );
}

class _EstadoCarregando extends StatelessWidget {
  const _EstadoCarregando();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Cores.flare500));
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) => const EstadoTela(
    icone: Icons.pets,
    cor: Cores.textoMedio,
    texto: "Nenhum animal resgatado cadastrado no momento.",
  );
}
