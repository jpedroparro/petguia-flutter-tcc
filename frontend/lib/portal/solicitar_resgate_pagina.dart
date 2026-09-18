import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../componentes/app_confirmacao_envio.dart";
import "../componentes/seletor_foto.dart";
import "../dados/cloudinary_config.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/geo_utils.dart";
import "../dados/validacao_utils.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Formulário público (sem login) pra pedir resgate urgente — o caso do
/// animal que não dá pra simplesmente ir buscar: preso em árvore, telhado,
/// ilhado pela enchente, precisa de barco ou equipamento especial. Aparece
/// como alerta pra Defesa Civil/bombeiros logados atenderem.
class SolicitarResgatePagina extends StatefulWidget {
  const SolicitarResgatePagina({super.key});

  @override
  State<SolicitarResgatePagina> createState() => _SolicitarResgatePaginaState();
}

class _SolicitarResgatePaginaState extends State<SolicitarResgatePagina> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoControlador = TextEditingController();
  final _ruaControlador = TextEditingController();
  final _bairroControlador = TextEditingController();
  final _nomeControlador = TextEditingController();
  final _telefoneControlador = TextEditingController();
  final _repositorio = FuncoesRepositorio();
  final _picker = ImagePicker();

  double? _latitude;
  double? _longitude;
  Uint8List? _fotoBytes;
  bool _obtendoLocalizacao = false;
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    _descricaoControlador.dispose();
    _ruaControlador.dispose();
    _bairroControlador.dispose();
    _nomeControlador.dispose();
    _telefoneControlador.dispose();
    super.dispose();
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
        if (rua != null) _ruaControlador.text = rua;
        if (bairro != null) _bairroControlador.text = bairro;
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

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      String? fotoUrl;
      if (_fotoBytes != null) {
        fotoUrl = await enviarFotoParaCloudinary(_fotoBytes!);
      }

      await _repositorio.solicitarResgate({
        "descricaoSituacao": _descricaoControlador.text.trim(),
        "rua": _ruaControlador.text.trim(),
        "bairro": _bairroControlador.text.trim(),
        "nomeContato": _nomeControlador.text.trim(),
        "telefoneContato": _telefoneControlador.text.trim(),
        "latitude": _latitude,
        "longitude": _longitude,
        "fotoUrl": fotoUrl,
      });
      if (mounted) setState(() => _enviado = true);
    } on FuncaoRepositorioException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = "Não foi possível enviar agora. Tente novamente.",
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pedir resgate urgente", style: Tipografia.tema.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _enviado ? const AppConfirmacaoEnvio() : _formulario(),
        ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCallout(
              texto:
                  "Use isso quando o animal não pode ser simplesmente "
                  "buscado a pé: preso em árvore, telhado, ilhado pela "
                  "enchente. Vira um alerta pra Defesa Civil/bombeiros.",
              tipo: TipoCallout.urgente,
              icone: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 16),
            if (_erro != null) ...[
              AppCallout(
                texto: _erro!,
                tipo: TipoCallout.urgente,
                icone: Icons.error_outline,
              ),
              const SizedBox(height: 16),
            ],
            SeletorFoto(bytes: _fotoBytes, aoTocar: _abrirEscolhaDeFoto),
            const SizedBox(height: 4),
            Text(
              "Uma foto ajuda a equipe a identificar o animal e o local.",
              style: Tipografia.tema.bodySmall,
            ),
            const SizedBox(height: 14),
            AppCampoTexto(
              controller: _descricaoControlador,
              rotulo: "O que está acontecendo?",
              icone: Icons.info_outline,
              validador: (v) => (v == null || v.trim().isEmpty)
                  ? "Descreva a situação"
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              "Ex: cachorro preso em cima de uma árvore, precisa de barco.",
              style: Tipografia.tema.bodySmall,
            ),
            const SizedBox(height: 14),
            AppCampoTexto(
              controller: _ruaControlador,
              rotulo: "Rua",
              icone: Icons.location_on_outlined,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? "Informe a rua" : null,
            ),
            const SizedBox(height: 14),
            AppCampoTexto(
              controller: _bairroControlador,
              rotulo: "Bairro",
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? "Informe o bairro" : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _obtendoLocalizacao ? null : _usarMinhaLocalizacao,
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
                  style: Tipografia.rotulo(cor: Cores.flare500, tamanho: 12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AppCampoTexto(
              controller: _nomeControlador,
              rotulo: "Seu nome",
              icone: Icons.person_outline,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? "Informe seu nome" : null,
            ),
            const SizedBox(height: 14),
            AppCampoTexto(
              controller: _telefoneControlador,
              rotulo: "Seu telefone",
              icone: Icons.phone_outlined,
              tipoTeclado: TextInputType.phone,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return "Informe o telefone";
                return validarTelefone(v)
                    ? null
                    : "Informe um telefone válido, com DDD";
              },
            ),
            const SizedBox(height: 22),
            AppBotaoPrimario(
              texto: _enviando ? "Enviando..." : "Enviar alerta",
              carregando: _enviando,
              aoPressionar: _enviando ? null : _enviar,
            ),
          ],
        ),
      ),
    );
  }
}
