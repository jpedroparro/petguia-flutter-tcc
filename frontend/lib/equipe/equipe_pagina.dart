import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../autenticacao/login_pagina.dart";
import "../painel/painel_operador_pagina.dart";
import "../rio/rio_pagina.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "abrigos_aba.dart";
import "animais_aba.dart";
import "resgates_aba.dart";
import "reunificacao_aba.dart";
import "tutoria_aba.dart";

const _abas = [
  (
    titulo: "Painel do operador",
    rotuloMenu: "Painel",
    icone: Icons.dashboard_outlined,
    tela: PainelOperadorPagina(),
  ),
  (
    titulo: "Animais",
    rotuloMenu: "Animais",
    icone: Icons.pets,
    tela: AnimaisAba(),
  ),
  (
    titulo: "Abrigos",
    rotuloMenu: "Abrigos",
    icone: Icons.home_outlined,
    tela: AbrigosAba(),
  ),
  (
    titulo: "Rio",
    rotuloMenu: "Rio",
    icone: Icons.water_outlined,
    tela: RioPagina(),
  ),
  (
    titulo: "Alertas",
    rotuloMenu: "Alertas",
    icone: Icons.warning_amber_outlined,
    tela: ResgatesAba(),
  ),
  (
    titulo: "Tutoria",
    rotuloMenu: "Tutoria",
    icone: Icons.house_outlined,
    tela: TutoriaAba(),
  ),
  (
    titulo: "Reunificação",
    rotuloMenu: "Reunificação",
    icone: Icons.volunteer_activism_outlined,
    tela: ReunificacaoAba(),
  ),
];

/// Índice a partir do qual uma aba mora dentro do menu "Mais" em vez de
/// aparecer direto na barra inferior — ver comentário em [_BarraInferior].
const _primeiroIndiceNoMais = 4;

/// Painel da equipe — navegação entre os fluxos de negócio do Módulo de
/// Planejamento da Execução e o painel do operador (Defesa Civil/ONGs
/// autenticadas).
class EquipePagina extends StatefulWidget {
  const EquipePagina({super.key});

  @override
  State<EquipePagina> createState() => _EquipePaginaState();
}

class _EquipePaginaState extends State<EquipePagina> {
  int _abaAtual = 0;
  StreamSubscription<User?>? _authSub;
  String? _papel;

  // As abas Painel/Alertas/Tutoria/Reunificação buscam dado uma vez só (via
  // Future, não Stream) e o `IndexedStack` nunca as descarta ao trocar de
  // aba — então uma ação feita numa (ex: "Atender" no Painel) não reflete
  // na outra (Alertas), que continua mostrando a lista antiga até alguém
  // puxar pra atualizar manualmente. Trocar a `key` força recriar a tela
  // (e reexecutar a busca) toda vez que se entra nela.
  final _geracao = List<int>.filled(_abas.length, 0);

  void _selecionarAba(int i) {
    setState(() {
      if (i != _abaAtual) _geracao[i]++;
      _abaAtual = i;
    });
  }

  @override
  void initState() {
    super.initState();
    // Se a conta deslogar (aqui ou em outra aba/tela) enquanto o painel da
    // equipe está aberto, volta pro login em vez de deixar a tela logada
    // renderizada com um token que já não vale mais.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((usuario) {
      if (usuario == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPagina()),
          (rota) => false,
        );
      }
    });
    _carregarPapel();
  }

  Future<void> _carregarPapel() async {
    final resultado = await FirebaseAuth.instance.currentUser
        ?.getIdTokenResult();
    if (mounted) {
      setState(() => _papel = resultado?.claims?["role"] as String?);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _sair() async {
    Navigator.of(context).pop(); // fecha o menu de conta
    await FirebaseAuth.instance.signOut();
    // A navegação de volta pro login acontece sozinha via _authSub acima.
  }

  void _abrirMenuConta() {
    final usuario = FirebaseAuth.instance.currentUser;
    final email = usuario?.email ?? "";
    showMenu<void>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 62, 16, 0),
      color: Cores.ink700,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: Cores.lineForte),
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                email,
                style: Tipografia.tema.bodyMedium?.copyWith(
                  color: Cores.textoAlto,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_papel != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Cores.flare500.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _papel == "admin" ? "ADMINISTRADOR" : "OPERADOR",
                    style: Tipografia.rotulo(cor: Cores.flare500, tamanho: 9),
                  ),
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: _sair,
          child: Row(
            children: [
              const Icon(Icons.logout, color: Cores.alerta500, size: 18),
              const SizedBox(width: 8),
              Text(
                "Sair",
                style: Tipografia.tema.bodyMedium?.copyWith(
                  color: Cores.alerta500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _abrirMais() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Cores.ink800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "MAIS OPÇÕES",
                    style: Tipografia.rotulo(
                      cor: Cores.textoBaixo,
                      tamanho: 11,
                    ),
                  ),
                ),
              ),
              for (
                var i = _primeiroIndiceNoMais;
                i < _abas.length;
                i++
              )
                ListTile(
                  leading: Icon(_abas[i].icone, color: Cores.textoAlto),
                  title: Text(
                    _abas[i].titulo,
                    style: Tipografia.tema.bodyLarge,
                  ),
                  onTap: () {
                    _selecionarAba(i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final iniciais = _iniciaisDe(usuario?.email);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _abas[_abaAtual].titulo,
          style: Tipografia.tema.headlineMedium,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              customBorder: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              onTap: _abrirMenuConta,
              child: Container(
                width: 34,
                height: 34,
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Cores.flare500, Cores.flare600],
                  ),
                  shape: const BeveledRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  iniciais,
                  style: Tipografia.rotulo(cor: Colors.white, tamanho: 11),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _abaAtual,
        children: [
          for (var i = 0; i < _abas.length; i++)
            KeyedSubtree(
              key: ValueKey("aba-$i-${_geracao[i]}"),
              child: _abas[i].tela,
            ),
        ],
      ),
      bottomNavigationBar: _BarraInferior(
        indiceAtual: _abaAtual,
        aoSelecionar: _selecionarAba,
        aoAbrirMais: _abrirMais,
      ),
    );
  }
}

String _iniciaisDe(String? email) {
  if (email == null || email.isEmpty) return "?";
  final usuario = email.split("@").first;
  if (usuario.length == 1) return usuario.toUpperCase();
  return usuario.substring(0, 2).toUpperCase();
}

/// Barra inferior com no máximo 5 itens visíveis — os 4 primeiros (Painel,
/// Animais, Abrigos, Rio) mais um "Mais" que abre as demais abas (Alertas,
/// Tutoria, Reunificação) numa folha, em vez de espremer 7 rótulos numa
/// barra só. "Mais" fica destacado quando a aba atual é uma das que moram
/// nele, mesmo com a folha fechada.
class _BarraInferior extends StatelessWidget {
  final int indiceAtual;
  final ValueChanged<int> aoSelecionar;
  final VoidCallback aoAbrirMais;

  const _BarraInferior({
    required this.indiceAtual,
    required this.aoSelecionar,
    required this.aoAbrirMais,
  });

  @override
  Widget build(BuildContext context) {
    final noMais = indiceAtual >= _primeiroIndiceNoMais;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Cores.ink950,
        border: Border(top: BorderSide(color: Cores.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _primeiroIndiceNoMais; i++)
                _ItemBarra(
                  icone: _abas[i].icone,
                  rotulo: _abas[i].rotuloMenu,
                  ativo: !noMais && indiceAtual == i,
                  aoTocar: () => aoSelecionar(i),
                ),
              _ItemBarra(
                icone: Icons.more_horiz,
                rotulo: "Mais",
                ativo: noMais,
                aoTocar: aoAbrirMais,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback aoTocar;

  const _ItemBarra({
    required this.icone,
    required this.rotulo,
    required this.ativo,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? Cores.flare500 : Cores.textoBaixo;
    return Expanded(
      child: InkWell(
        onTap: aoTocar,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 2,
              child: ativo ? ColoredBox(color: cor) : null,
            ),
            const SizedBox(height: 5),
            Icon(icone, color: cor, size: 22),
            const SizedBox(height: 2),
            Text(rotulo, style: Tipografia.rotulo(cor: cor, tamanho: 10)),
          ],
        ),
      ),
    );
  }
}
