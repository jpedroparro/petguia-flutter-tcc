import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/geo_utils.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/validacao_utils.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Formulário de abrigo — Módulo de Planejamento da Execução. Serve tanto
/// pra criar (sem [abrigoExistente]) quanto pra editar (com
/// [abrigoExistente]): depois de criado, um abrigo só pode ser corrigido
/// por aqui, não tinha como antes.
class CriarAbrigoPagina extends StatefulWidget {
  final Abrigo? abrigoExistente;

  const CriarAbrigoPagina({super.key, this.abrigoExistente});

  @override
  State<CriarAbrigoPagina> createState() => _CriarAbrigoPaginaState();
}

class _CriarAbrigoPaginaState extends State<CriarAbrigoPagina> {
  final _formKey = GlobalKey<FormState>();
  final _nomeControlador = TextEditingController();
  final _ruaControlador = TextEditingController();
  final _numeroControlador = TextEditingController();
  final _enderecoControlador = TextEditingController();
  final _cepControlador = TextEditingController();
  final _telefoneControlador = TextEditingController();
  final _capacidadeControlador = TextEditingController();
  final _repositorio = FuncoesRepositorio();
  bool _salvando = false;
  bool _obtendoLocalizacao = false;
  double? _latitude;
  double? _longitude;
  String? _erro;

  Abrigo? get _existente => widget.abrigoExistente;
  bool get _editando => _existente != null;

  @override
  void initState() {
    super.initState();
    final existente = _existente;
    if (existente != null) {
      _nomeControlador.text = existente.nome;
      _enderecoControlador.text = existente.endereco;
      _cepControlador.text = existente.cep;
      _telefoneControlador.text = existente.telefone;
      _capacidadeControlador.text = existente.capacidadeTotal.toString();
      _latitude = existente.latitude;
      _longitude = existente.longitude;
    }
  }

  @override
  void dispose() {
    _nomeControlador.dispose();
    _ruaControlador.dispose();
    _numeroControlador.dispose();
    _enderecoControlador.dispose();
    _cepControlador.dispose();
    _telefoneControlador.dispose();
    _capacidadeControlador.dispose();
    super.dispose();
  }

  /// Marca a localização do abrigo no mapa — sem isso o abrigo nunca
  /// aparece na tela de Mapa/Rota, só na lista.
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
      setState(() {
        _latitude = posicao.latitude;
        _longitude = posicao.longitude;
      });
    } finally {
      if (mounted) setState(() => _obtendoLocalizacao = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final dados = {
        "nome": _nomeControlador.text.trim(),
        "endereco": _editando
            ? _enderecoControlador.text.trim()
            : "${_ruaControlador.text.trim()}, ${_numeroControlador.text.trim()}",
        "cep": _cepControlador.text.trim(),
        "telefone": _telefoneControlador.text.trim(),
        "capacidadeTotal": int.parse(_capacidadeControlador.text.trim()),
        "latitude": _latitude,
        "longitude": _longitude,
      };
      if (_editando) {
        await _repositorio.atualizarAbrigo(_existente!.id, dados);
      } else {
        await _repositorio.criarAbrigo(dados);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FuncaoRepositorioException catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = "Não foi possível salvar o abrigo agora.");
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editando ? "Editar abrigo" : "Novo abrigo",
          style: Tipografia.tema.titleLarge,
        ),
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
                  AppCampoTexto(
                    controller: _nomeControlador,
                    rotulo: "Nome do abrigo",
                    icone: Icons.home_outlined,
                    validador: (v) => (v == null || v.trim().isEmpty)
                        ? "Informe o nome"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  if (_editando)
                    AppCampoTexto(
                      controller: _enderecoControlador,
                      rotulo: "Endereço",
                      icone: Icons.location_on_outlined,
                      validador: (v) => (v == null || v.trim().isEmpty)
                          ? "Informe o endereço"
                          : null,
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppCampoTexto(
                            controller: _ruaControlador,
                            rotulo: "Rua",
                            icone: Icons.location_on_outlined,
                            validador: (v) => (v == null || v.trim().isEmpty)
                                ? "Informe a rua"
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppCampoTexto(
                            controller: _numeroControlador,
                            rotulo: "Número",
                            tipoTeclado: TextInputType.number,
                            validador: (v) => (v == null || v.trim().isEmpty)
                                ? "Informe o número"
                                : null,
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
                          : Icon(
                              _latitude != null
                                  ? Icons.check_circle
                                  : Icons.my_location,
                              size: 16,
                              color: Cores.flare500,
                            ),
                      label: Text(
                        _obtendoLocalizacao
                            ? "Obtendo localização..."
                            : _latitude != null
                            ? "Localização marcada no mapa"
                            : "Marcar localização no mapa",
                        style: Tipografia.rotulo(
                          cor: Cores.flare500,
                          tamanho: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCampoTexto(
                    controller: _cepControlador,
                    rotulo: "CEP",
                    icone: Icons.markunread_mailbox_outlined,
                    tipoTeclado: TextInputType.number,
                    validador: (v) => validarCep(v ?? "")
                        ? null
                        : "Informe um CEP válido (8 dígitos)",
                  ),
                  const SizedBox(height: 14),
                  AppCampoTexto(
                    controller: _telefoneControlador,
                    rotulo: "Telefone",
                    icone: Icons.phone_outlined,
                    tipoTeclado: TextInputType.phone,
                    validador: (v) => validarTelefone(v ?? "")
                        ? null
                        : "Informe um telefone válido, com DDD",
                  ),
                  const SizedBox(height: 14),
                  AppCampoTexto(
                    controller: _capacidadeControlador,
                    rotulo: "Capacidade total",
                    icone: Icons.groups_outlined,
                    tipoTeclado: TextInputType.number,
                    validador: (v) {
                      final n = int.tryParse(v?.trim() ?? "");
                      if (n == null || n <= 0) {
                        return "Informe uma capacidade válida";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  AppBotaoPrimario(
                    texto: _salvando
                        ? "Salvando..."
                        : _editando
                        ? "Salvar alterações"
                        : "Salvar abrigo",
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
