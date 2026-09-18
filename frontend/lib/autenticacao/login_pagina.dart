import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../componentes/app_botao.dart";
import "../componentes/app_callout.dart";
import "../componentes/app_campo_texto.dart";
import "../componentes/app_card.dart";
import "../dados/funcoes_repositorio.dart";
import "../equipe/equipe_pagina.dart";
import "../mapa/abrigos_lista_pagina.dart";
import "../portal/portal_pagina.dart";
import "../portal/solicitar_resgate_pagina.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Domínio interno usado para contas da equipe sem e-mail próprio — mesma
/// convenção do sistema web (ex: admin@radian.local).
const _dominioInterno = "radian.local";

/// Resolve um usuário digitado sem "@" para o e-mail interno correspondente.
String _resolverEmail(String usuarioOuEmail) {
  final valor = usuarioOuEmail.trim();
  if (valor.contains("@")) return valor;
  return "$valor@$_dominioInterno";
}

/// Tela inicial do app. Abre com o dado real do rio (o motivo do app
/// existir), depois os dois caminhos do público (sem login) e só por
/// último, recolhido, o acesso da equipe — antes o login da equipe e os
/// atalhos públicos disputavam o mesmo espaço com o mesmo peso visual.
class LoginPagina extends StatefulWidget {
  const LoginPagina({super.key});

  @override
  State<LoginPagina> createState() => _LoginPaginaState();
}

class _LoginPaginaState extends State<LoginPagina> {
  final _formKey = GlobalKey<FormState>();
  final _emailControlador = TextEditingController();
  final _senhaControlador = TextEditingController();
  bool _entrando = false;
  bool _mostrarLoginEquipe = false;
  String? _erro;
  late final Future<Map<String, dynamic>> _futuroRio;

  @override
  void initState() {
    super.initState();
    _futuroRio = FuncoesRepositorio().buscarRio();
  }

  @override
  void dispose() {
    _emailControlador.dispose();
    _senhaControlador.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _entrando = true;
      _erro = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _resolverEmail(_emailControlador.text),
        password: _senhaControlador.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EquipePagina()),
        );
      }
    } on FirebaseAuthException {
      setState(() => _erro = "Usuário ou senha inválidos.");
    } catch (_) {
      setState(() => _erro = "Não foi possível entrar agora. Tente novamente.");
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "PETGUIA ENCHENTES",
                    style: Tipografia.rotulo(cor: Cores.flare500, tamanho: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Como podemos ajudar?",
                    style: Tipografia.tema.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _CartaoRio(futuro: _futuroRio),
                  const SizedBox(height: 20),
                  _TilePublico(
                    icone: Icons.search,
                    titulo: "Buscar meu animal",
                    subtitulo: "Consulta pública, sem login",
                    aoTocar: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PortalPagina()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TilePublico(
                    icone: Icons.home_outlined,
                    titulo: "Ver abrigos",
                    subtitulo: "Endereço e ocupação",
                    aoTocar: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AbrigosListaPagina(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SolicitarResgatePagina(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Cores.alerta500,
                      side: const BorderSide(color: Cores.alerta500),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const BeveledRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: Text(
                      "Pedir resgate urgente",
                      style: Tipografia.tema.bodyMedium?.copyWith(
                        color: Cores.alerta500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Cores.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "ACESSO DA EQUIPE",
                          style: Tipografia.rotulo(
                            cor: Cores.textoBaixo,
                            tamanho: 10,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Cores.line)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!_mostrarLoginEquipe)
                    AppBotaoSecundario(
                      texto: "Entrar como Defesa Civil / CBMSC / APAD",
                      aoPressionar: () =>
                          setState(() => _mostrarLoginEquipe = true),
                    )
                  else
                    AppCard(
                      child: Form(
                        key: _formKey,
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
                              controller: _emailControlador,
                              rotulo: "Usuário ou e-mail",
                              icone: Icons.person_outline,
                              validador: (v) => (v == null || v.isEmpty)
                                  ? "Informe o usuário ou e-mail"
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            AppCampoTexto(
                              controller: _senhaControlador,
                              rotulo: "Senha",
                              icone: Icons.lock_outline,
                              senha: true,
                              validador: (v) => (v == null || v.isEmpty)
                                  ? "Informe a senha"
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            AppBotaoPrimario(
                              texto: _entrando ? "Entrando..." : "Entrar",
                              carregando: _entrando,
                              aoPressionar: _entrando ? null : _entrar,
                            ),
                          ],
                        ),
                      ),
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

/// Cartão com a cota atual do rio — não é decoração, é o dado real de
/// `GET /rio` (mesmo dado que a equipe vê na aba Rio), porque essa é a
/// razão do app existir e deve ser a primeira coisa que qualquer pessoa
/// (pública ou equipe) vê ao abrir o link.
class _CartaoRio extends StatelessWidget {
  final Future<Map<String, dynamic>> futuro;

  const _CartaoRio({required this.futuro});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: futuro,
      builder: (context, snap) {
        final nivel = snap.data?["nivelAtual"] as num?;
        final classificacao = snap.data?["classificacao"] as String?;
        final cor = classificacaoRioCor[classificacao] ?? Cores.textoMedio;
        final rotulo = classificacaoRioLabel[classificacao] ?? "Sem leitura";

        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            children: [
              Text(
                "RIO ITAJAÍ-SUL AGORA",
                style: Tipografia.rotulo(cor: Cores.textoBaixo, tamanho: 10),
              ),
              const SizedBox(height: 6),
              snap.connectionState != ConnectionState.done
                  ? const SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Cores.flare500,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        text: nivel?.toStringAsFixed(2).replaceAll(".", ",") ??
                            "—",
                        style: Tipografia.tema.displayMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        children: [
                          if (nivel != null)
                            TextSpan(
                              text: " m",
                              style: Tipografia.tema.bodyLarge?.copyWith(
                                color: Cores.textoMedio,
                              ),
                            ),
                        ],
                      ),
                    ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  rotulo.toUpperCase(),
                  style: Tipografia.rotulo(cor: cor, tamanho: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TilePublico extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback aoTocar;

  const _TilePublico({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      onTap: aoTocar,
      child: AppCard(
        child: Row(
          children: [
            Icon(icone, color: Cores.flare500, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Tipografia.tema.titleMedium),
                  Text(
                    subtitulo,
                    style: Tipografia.tema.bodySmall?.copyWith(
                      color: Cores.textoBaixo,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Cores.textoBaixo),
          ],
        ),
      ),
    );
  }
}
