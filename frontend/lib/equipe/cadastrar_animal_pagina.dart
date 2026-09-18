import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../componentes/seletor_foto.dart";
import "../dados/cloudinary_config.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/geo_utils.dart";
import "../dados/idade_utils.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/portal_repositorio.dart";
import "../dados/validacao_utils.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

const _portes = ["pequeno", "medio", "grande"];

const _estadosSaude = ["Estável", "Ferido", "Grave", "Desidratado"];

const _especies = ["Cachorro", "Gato", "Outro"];

const _racasPorEspecie = {
  "Cachorro": [
    "SRD (Vira-lata)",
    "Labrador",
    "Poodle",
    "Pastor Alemão",
    "Bulldog",
    "Golden Retriever",
    "Pit Bull",
    "Shih Tzu",
    "Yorkshire",
    "Rottweiler",
    "Beagle",
    "Salsicha",
    "Chihuahua",
    "Border Collie",
    "Outra",
  ],
  "Gato": [
    "SRD (Vira-lata)",
    "Persa",
    "Siamês",
    "Maine Coon",
    "Angorá",
    "Sphynx",
    "Ragdoll",
    "Bengal",
    "Outra",
  ],
  "Outro": ["Outra"],
};

/// Formulário de cadastro de animal já resgatado (em mãos da equipe) —
/// Módulo de Planejamento da Execução. Sempre exige um destino: abrigo com
/// vaga ou tutor no ato do cadastro — não existe "cadastrar e deixar sem
/// destino" por aqui. Pra reportar um animal que ainda precisa ser
/// resgatado (preso, ilhado), o fluxo é outro: "Pedir resgate urgente".
class CadastrarAnimalPagina extends StatefulWidget {
  const CadastrarAnimalPagina({super.key});

  @override
  State<CadastrarAnimalPagina> createState() => _CadastrarAnimalPaginaState();
}

class _CadastrarAnimalPaginaState extends State<CadastrarAnimalPagina> {
  final _formKey = GlobalKey<FormState>();
  final _estadoSaudeOutroControlador = TextEditingController();
  final _ruaControlador = TextEditingController();
  final _bairroControlador = TextEditingController();
  final _cepControlador = TextEditingController();
  final _nomeControlador = TextEditingController();
  final _telefoneControlador = TextEditingController();
  final _tutorNomeControlador = TextEditingController();
  final _tutorCpfControlador = TextEditingController();
  final _repositorio = FuncoesRepositorio();
  final _picker = ImagePicker();

  String _especie = _especies.first;
  String _raca = _racasPorEspecie[_especies.first]!.first;
  String _porte = _portes.first;
  String? _estadoSaude;
  bool _estadoSaudeOutro = false;
  bool _comColeira = false;
  bool _vouSerTutor = false;
  String? _abrigoId;
  Uint8List? _fotoBytes;
  double? _latitude;
  double? _longitude;
  DateTime? _tutorNascimento;
  bool _obtendoLocalizacao = false;
  bool _salvando = false;
  String? _erro;
  // Preenchido quando o animal já foi criado, mas a confirmação da tutoria
  // falhou depois — evita duplicar o animal se o operador tentar salvar de
  // novo: nesse caso, só retenta confirmar a tutoria pro mesmo animal.
  String? _animalIdCriadoPendente;
  // Preenchido quando a solicitação de tutoria já foi criada (pendente),
  // mas a CONFIRMAÇÃO dela falhou depois (ex: rede caiu entre as duas
  // chamadas) — evita criar uma segunda solicitação órfã no retry; nesse
  // caso, só retenta confirmar a que já existe.
  String? _solicitacaoTutoriaIdPendente;

  @override
  void dispose() {
    _estadoSaudeOutroControlador.dispose();
    _ruaControlador.dispose();
    _bairroControlador.dispose();
    _cepControlador.dispose();
    _nomeControlador.dispose();
    _telefoneControlador.dispose();
    _tutorNomeControlador.dispose();
    _tutorCpfControlador.dispose();
    super.dispose();
  }

  void _mudarEspecie(String v) {
    setState(() {
      _especie = v;
      _raca = _racasPorEspecie[v]!.first;
    });
  }

  Future<void> _escolherDataNascimentoTutor() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime(agora.year - 30, agora.month, agora.day),
      firstDate: DateTime(agora.year - 120),
      lastDate: agora,
      helpText: "Data de nascimento",
    );
    if (escolhida != null) setState(() => _tutorNascimento = escolhida);
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    final arquivo = await _picker.pickImage(
      source: origem,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (arquivo != null) {
      final bytes = await arquivo.readAsBytes();
      setState(() => _fotoBytes = bytes);
    }
  }

  void _abrirEscolhaDeFoto() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Cores.ink800,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: Cores.water500,
              ),
              title: Text("Tirar foto", style: Tipografia.tema.bodyLarge),
              onTap: () {
                Navigator.of(context).pop();
                _escolherFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Cores.water500,
              ),
              title: Text(
                "Escolher da galeria",
                style: Tipografia.tema.bodyLarge,
              ),
              onTap: () {
                Navigator.of(context).pop();
                _escolherFoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pede a localização atual e usa a geocodificação reversa (backend, que
  /// consulta o Nominatim) pra sugerir rua/bairro/CEP — os campos continuam
  /// editáveis, isso só evita digitação manual.
  Future<void> _usarMinhaLocalizacao() async {
    setState(() => _obtendoLocalizacao = true);
    try {
      final posicao = await obterPosicaoAtual();
      if (posicao == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Não foi possível obter sua localização agora."),
            ),
          );
        }
        return;
      }
      _latitude = posicao.latitude;
      _longitude = posicao.longitude;

      final endereco = await _repositorio.buscarEnderecoPorCoordenadas(
        posicao.latitude,
        posicao.longitude,
      );
      if (endereco != null) {
        final rua = endereco["rua"] as String?;
        final bairro = endereco["bairro"] as String?;
        final cep = endereco["cep"] as String?;
        if (rua != null) _ruaControlador.text = rua;
        if (bairro != null) _bairroControlador.text = bairro;
        if (cep != null) _cepControlador.text = cep;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Não foi possível obter sua localização agora."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _obtendoLocalizacao = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final estadoSaude = _estadoSaudeOutro
        ? _estadoSaudeOutroControlador.text.trim()
        : _estadoSaude;
    if (estadoSaude == null || estadoSaude.isEmpty) {
      setState(() => _erro = "Informe o estado de saúde do animal.");
      return;
    }
    if (_vouSerTutor &&
        (_tutorNascimento == null || idadeEm(_tutorNascimento!) < 18)) {
      setState(
        () => _erro = "Informe a data de nascimento do tutor (maior de idade).",
      );
      return;
    }
    if (!_vouSerTutor && _abrigoId == null) {
      setState(
        () => _erro =
            "Selecione um abrigo ou marque \"Vou ser o tutor\" — um "
            "animal resgatado não pode ficar sem destino. Se o animal ainda "
            "não foi resgatado, use \"Pedir resgate urgente\" em vez deste "
            "formulário.",
      );
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    // Se uma tentativa anterior já criou o animal e só falhou depois disso,
    // não recria o animal.
    final animalJaExistente = _animalIdCriadoPendente;
    if (animalJaExistente != null) {
      if (_vouSerTutor) {
        // Ainda quer ser tutor: retenta só a parte que faltou (a
        // solicitação em si, se ela também já existe, ou a confirmação).
        await _confirmarTutoriaPara(animalJaExistente);
      } else {
        // Mudou de ideia — desmarcou "vou ser tutor" e escolheu um abrigo
        // em vez disso. Sem este ramo, essa escolha era descartada
        // silenciosamente e o retry sempre insistia na tutoria antiga.
        await _alocarEmAbrigoPara(animalJaExistente, _abrigoId!);
      }
      return;
    }

    try {
      String? fotoUrl;
      if (_fotoBytes != null) {
        fotoUrl = await enviarFotoParaCloudinary(_fotoBytes!);
      }

      final animal = await _repositorio.cadastrarAnimal({
        "especie": _especie,
        "raca": _raca,
        "porte": _porte,
        "estadoSaude": estadoSaude,
        "rua": _ruaControlador.text.trim(),
        "bairro": _bairroControlador.text.trim(),
        "cepResgate": _cepControlador.text.trim().isEmpty
            ? null
            : _cepControlador.text.trim(),
        "latitudeResgate": _latitude,
        "longitudeResgate": _longitude,
        "comColeira": _comColeira,
        "nomeIdentificacao": _nomeControlador.text.trim().isEmpty
            ? null
            : _nomeControlador.text.trim(),
        "telefoneContato": _telefoneControlador.text.trim().isEmpty
            ? null
            : _telefoneControlador.text.trim(),
        "fotoUrl": fotoUrl,
        "abrigoId": _abrigoId,
      });

      if (_vouSerTutor) {
        await _confirmarTutoriaPara(animal["id"] as String);
      } else {
        if (mounted) Navigator.of(context).pop(true);
      }
    } on FuncaoRepositorioException catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = "Não foi possível salvar o animal agora.");
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// A equipe já está com a pessoa ali no momento do cadastro — não faz
  /// sentido pedir aprovação depois pra confirmar o que a própria equipe
  /// acabou de registrar. Solicita e já confirma em sequência. Se falhar
  /// (ex: CPF inválido, ou a rede caiu entre as duas chamadas), guarda o
  /// que já foi criado pra não duplicar nada numa nova tentativa — nem o
  /// animal, nem a solicitação de tutoria.
  Future<void> _confirmarTutoriaPara(String animalId) async {
    try {
      final solicitacaoIdJaExistente = _solicitacaoTutoriaIdPendente;
      final solicitacaoId = solicitacaoIdJaExistente ??
          (await _repositorio.solicitarTutoria({
            "animalId": animalId,
            "nomeTutor": _tutorNomeControlador.text.trim(),
            "dataNascimentoTutor": dataNascimentoIso(_tutorNascimento!),
            "cpfTutor": _tutorCpfControlador.text.trim(),
            "telefoneTutor": _telefoneControlador.text.trim(),
          }))["id"] as String;
      if (solicitacaoIdJaExistente == null) {
        _solicitacaoTutoriaIdPendente = solicitacaoId;
      }
      await _repositorio.confirmarTutoria(solicitacaoId);
      if (mounted) Navigator.of(context).pop(true);
    } on FuncaoRepositorioException catch (e) {
      setState(() {
        _animalIdCriadoPendente = animalId;
        _erro =
            "O animal já foi salvo, mas não foi possível confirmar a "
            "tutoria: ${e.mensagem}. Corrija os dados do tutor acima e "
            "toque em \"Tentar tutoria de novo\" — isso não vai duplicar "
            "o animal.";
      });
    } catch (_) {
      setState(() {
        _animalIdCriadoPendente = animalId;
        _erro =
            "O animal já foi salvo, mas não foi possível confirmar a "
            "tutoria agora. Toque em \"Tentar tutoria de novo\" — isso não "
            "vai duplicar o animal.";
      });
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Cobre o caso de o operador mudar de ideia depois de uma falha parcial:
  /// o animal já foi criado (aguardando tutoria), mas ele desmarcou "vou
  /// ser tutor" e escolheu um abrigo em vez disso.
  Future<void> _alocarEmAbrigoPara(String animalId, String abrigoId) async {
    try {
      await _repositorio.marcarAnimalComoEmAbrigo(animalId, abrigoId);
      if (mounted) Navigator.of(context).pop(true);
    } on FuncaoRepositorioException catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = "Não foi possível alocar o animal no abrigo agora.");
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Novo resgate", style: Tipografia.tema.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_erro != null) ...[
                    AppCallout(
                      texto: _erro!,
                      tipo: TipoCallout.urgente,
                      icone: Icons.error_outline,
                    ),
                    const SizedBox(height: 16),
                  ],
                  SeletorFoto(bytes: _fotoBytes, aoTocar: _abrirEscolhaDeFoto),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _especie,
                          dropdownColor: Cores.ink800,
                          style: const TextStyle(color: Cores.textoAlto),
                          decoration: const InputDecoration(
                            labelText: "Espécie",
                            prefixIcon: Icon(
                              Icons.pets,
                              color: Cores.textoBaixo,
                            ),
                          ),
                          items: _especies
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => _mudarEspecie(v ?? _especie),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _raca,
                          dropdownColor: Cores.ink800,
                          isExpanded: true,
                          style: const TextStyle(color: Cores.textoAlto),
                          decoration: const InputDecoration(labelText: "Raça"),
                          items: _racasPorEspecie[_especie]!
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _raca = v ?? _raca),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SeletorPorte(
                    valor: _porte,
                    aoMudar: (v) => setState(() => _porte = v),
                  ),
                  const SizedBox(height: 14),
                  _SeletorEstadoSaude(
                    valor: _estadoSaude,
                    outroSelecionado: _estadoSaudeOutro,
                    outroControlador: _estadoSaudeOutroControlador,
                    aoEscolher: (opcao) => setState(() {
                      _estadoSaudeOutro = false;
                      _estadoSaude = opcao;
                    }),
                    aoEscolherOutro: () => setState(() {
                      _estadoSaudeOutro = true;
                      _estadoSaude = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  AppCampoTexto(
                    controller: _ruaControlador,
                    rotulo: "Rua do resgate",
                    icone: Icons.location_on_outlined,
                    validador: (v) => (v == null || v.trim().isEmpty)
                        ? "Informe a rua"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppCampoTexto(
                          controller: _bairroControlador,
                          rotulo: "Bairro",
                          validador: (v) => (v == null || v.trim().isEmpty)
                              ? "Informe o bairro"
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppCampoTexto(
                          controller: _cepControlador,
                          rotulo: "CEP",
                          tipoTeclado: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _obtendoLocalizacao
                          ? null
                          : _usarMinhaLocalizacao,
                      icon: _obtendoLocalizacao
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
                              size: 16,
                              color: Cores.flare500,
                            ),
                      label: Text(
                        _obtendoLocalizacao
                            ? "Obtendo localização..."
                            : "Usar minha localização",
                        style: Tipografia.rotulo(
                          cor: Cores.flare500,
                          tamanho: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCampoTexto(
                    controller: _nomeControlador,
                    rotulo: "Nome (se identificado)",
                    icone: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppCampoTexto(
                    controller: _telefoneControlador,
                    rotulo: _vouSerTutor
                        ? "Telefone de contato"
                        : "Telefone de contato (se houver)",
                    icone: Icons.phone_outlined,
                    tipoTeclado: TextInputType.phone,
                    validador: (v) {
                      if (!_vouSerTutor) return null;
                      if (v == null || v.trim().isEmpty) {
                        return "Informe um telefone de contato";
                      }
                      return validarTelefone(v)
                          ? null
                          : "Informe um telefone válido, com DDD";
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _vouSerTutor,
                    onChanged: (v) => setState(() {
                      _vouSerTutor = v;
                      if (v) _abrigoId = null;
                    }),
                    title: Text(
                      "Vou ser o tutor",
                      style: Tipografia.tema.bodyMedium,
                    ),
                    subtitle: Text(
                      "Usa o telefone de contato acima e pede seu nome e "
                      "CPF abaixo — já registra como tutor temporário, sem "
                      "precisar de aprovação depois. Um animal resgatado "
                      "precisa ir pra um abrigo ou já sair com um tutor, "
                      "não os dois.",
                      style: Tipografia.tema.bodySmall,
                    ),
                    activeThumbColor: Cores.flare500,
                  ),
                  if (_vouSerTutor) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCampoTexto(
                            controller: _tutorNomeControlador,
                            rotulo: "Seu nome",
                            icone: Icons.person_outline,
                            validador: (v) =>
                                (_vouSerTutor &&
                                    (v == null || v.trim().isEmpty))
                                ? "Informe seu nome"
                                : null,
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _escolherDataNascimentoTutor,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: "Data de nascimento",
                                prefixIcon: Icon(
                                  Icons.cake_outlined,
                                  color: Cores.textoBaixo,
                                ),
                              ),
                              child: Text(
                                _tutorNascimento == null
                                    ? ""
                                    : "${_tutorNascimento!.day.toString().padLeft(2, '0')}/"
                                          "${_tutorNascimento!.month.toString().padLeft(2, '0')}/"
                                          "${_tutorNascimento!.year}"
                                          " (${idadeEm(_tutorNascimento!)} anos)",
                                style: const TextStyle(color: Cores.textoAlto),
                              ),
                            ),
                          ),
                          if (_vouSerTutor &&
                              _tutorNascimento != null &&
                              idadeEm(_tutorNascimento!) < 18) ...[
                            const SizedBox(height: 6),
                            AppCallout(
                              texto: "O tutor precisa ser maior de idade.",
                              tipo: TipoCallout.urgente,
                              icone: Icons.error_outline,
                            ),
                          ],
                          const SizedBox(height: 14),
                          AppCampoTexto(
                            controller: _tutorCpfControlador,
                            rotulo: "Seu CPF",
                            icone: Icons.badge_outlined,
                            tipoTeclado: TextInputType.number,
                            validador: (v) {
                              if (!_vouSerTutor) return null;
                              if (v == null || v.trim().isEmpty) {
                                return "Informe seu CPF";
                              }
                              return validarCPF(v) ? null : "CPF inválido";
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _comColeira,
                    onChanged: (v) => setState(() => _comColeira = v),
                    title: Text(
                      "Estava com coleira",
                      style: Tipografia.tema.bodyMedium,
                    ),
                    activeThumbColor: Cores.flare500,
                  ),
                  if (!_vouSerTutor) ...[
                    const SizedBox(height: 6),
                    _SeletorAbrigo(
                      valor: _abrigoId,
                      aoMudar: (v) => setState(() => _abrigoId = v),
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppBotaoPrimario(
                    texto: _salvando
                        ? "Salvando..."
                        : _animalIdCriadoPendente == null
                        ? "Salvar animal"
                        : _vouSerTutor
                        ? "Tentar tutoria de novo"
                        : "Alocar no abrigo",
                    carregando: _salvando,
                    aoPressionar: _salvando ? null : _salvar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeletorEstadoSaude extends StatelessWidget {
  final String? valor;
  final bool outroSelecionado;
  final TextEditingController outroControlador;
  final ValueChanged<String> aoEscolher;
  final VoidCallback aoEscolherOutro;

  const _SeletorEstadoSaude({
    required this.valor,
    required this.outroSelecionado,
    required this.outroControlador,
    required this.aoEscolher,
    required this.aoEscolherOutro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Estado de saúde", style: Tipografia.tema.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcao in _estadosSaude)
              _chip(
                texto: opcao,
                selecionado: !outroSelecionado && valor == opcao,
                aoTocar: () => aoEscolher(opcao),
              ),
            _chip(
              texto: "Outro...",
              selecionado: outroSelecionado,
              aoTocar: aoEscolherOutro,
            ),
          ],
        ),
        if (outroSelecionado) ...[
          const SizedBox(height: 10),
          AppCampoTexto(
            controller: outroControlador,
            rotulo: "Descreva o estado de saúde",
            icone: Icons.favorite_border,
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required String texto,
    required bool selecionado,
    required VoidCallback aoTocar,
  }) {
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selecionado ? Cores.flare500 : Colors.transparent,
          border: Border.all(
            color: selecionado ? Cores.flare500 : Cores.lineForte,
          ),
        ),
        child: Text(
          texto,
          style: Tipografia.tema.bodySmall?.copyWith(
            color: selecionado ? Colors.white : Cores.textoAlto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SeletorPorte extends StatelessWidget {
  final String valor;
  final ValueChanged<String> aoMudar;

  const _SeletorPorte({required this.valor, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      dropdownColor: Cores.ink800,
      style: const TextStyle(color: Cores.textoAlto),
      decoration: const InputDecoration(
        labelText: "Porte",
        prefixIcon: Icon(Icons.straighten, color: Cores.textoBaixo),
      ),
      items: _portes
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) => aoMudar(v ?? valor),
    );
  }
}

class _SeletorAbrigo extends StatelessWidget {
  final String? valor;
  final ValueChanged<String?> aoMudar;

  const _SeletorAbrigo({required this.valor, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Abrigo>>(
      stream: PortalRepositorio().abrigos(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EstadoTela(
            icone: Icons.error_outline,
            cor: Cores.alerta500,
            texto: "Não foi possível carregar os abrigos agora.",
          );
        }
        final carregando = !snap.hasData;
        final abrigos = snap.data ?? const <Abrigo>[];
        final comVaga = abrigos
            .where((a) => a.capacidadeOcupada < a.capacidadeTotal)
            .toList();

        return DropdownButtonFormField<String?>(
          initialValue: valor,
          dropdownColor: Cores.ink800,
          style: const TextStyle(color: Cores.textoAlto),
          decoration: const InputDecoration(
            labelText: "Alocar em abrigo",
            prefixIcon: Icon(Icons.home_outlined, color: Cores.textoBaixo),
          ),
          hint: Text(
            carregando ? "Carregando abrigos..." : "Selecione um abrigo com vaga",
          ),
          items: carregando
              ? const []
              : [
                  for (final a in comVaga)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        "${a.nome} (${a.capacidadeOcupada}/${a.capacidadeTotal})",
                      ),
                    ),
                ],
          onChanged: carregando ? null : aoMudar,
        );
      },
    );
  }
}
