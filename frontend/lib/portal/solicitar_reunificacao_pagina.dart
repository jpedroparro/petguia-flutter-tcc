import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../componentes/app_confirmacao_envio.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/validacao_utils.dart";
import "../tema/tipografia.dart";

/// Formulário público (sem login) para o tutor original pedir a devolução
/// do animal — equipe confirma depois no painel interno.
class SolicitarReunificacaoPagina extends StatefulWidget {
  final String animalId;

  const SolicitarReunificacaoPagina({super.key, required this.animalId});

  @override
  State<SolicitarReunificacaoPagina> createState() =>
      _SolicitarReunificacaoPaginaState();
}

class _SolicitarReunificacaoPaginaState
    extends State<SolicitarReunificacaoPagina> {
  final _formKey = GlobalKey<FormState>();
  final _nomeControlador = TextEditingController();
  final _telefoneControlador = TextEditingController();
  final _mensagemControlador = TextEditingController();
  final _repositorio = FuncoesRepositorio();
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    _nomeControlador.dispose();
    _telefoneControlador.dispose();
    _mensagemControlador.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      await _repositorio.solicitarReunificacao({
        "animalId": widget.animalId,
        "nomeTutor": _nomeControlador.text.trim(),
        "telefoneTutor": _telefoneControlador.text.trim(),
        "mensagem": _mensagemControlador.text.trim().isEmpty
            ? null
            : _mensagemControlador.text.trim(),
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
        title: Text("Pedir devolução", style: Tipografia.tema.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _enviado
              ? const AppConfirmacaoEnvio(textoBotao: "Voltar ao portal")
              : _formulario(),
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
              texto: "A equipe vai confirmar seus dados antes da devolução.",
              tipo: TipoCallout.info,
              icone: Icons.info_outline,
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
              rotulo: "Telefone",
              icone: Icons.phone_outlined,
              tipoTeclado: TextInputType.phone,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return "Informe o telefone";
                return validarTelefone(v)
                    ? null
                    : "Informe um telefone válido, com DDD";
              },
            ),
            const SizedBox(height: 14),
            AppCampoTexto(
              controller: _mensagemControlador,
              rotulo: "Como identificar o animal (opcional)",
              icone: Icons.notes_outlined,
            ),
            const SizedBox(height: 22),
            AppBotaoPrimario(
              texto: _enviando ? "Enviando..." : "Enviar pedido",
              carregando: _enviando,
              aoPressionar: _enviando ? null : _enviar,
            ),
          ],
        ),
      ),
    );
  }
}
