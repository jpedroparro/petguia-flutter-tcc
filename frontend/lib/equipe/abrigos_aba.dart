import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/portal_repositorio.dart";
import "../dados/whatsapp_utils.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "criar_abrigo_pagina.dart";

/// Criar/editar abrigo é ação só de admin no backend (`exigirAdmin` em
/// `POST /abrigos` e `PUT /abrigos/:id`) — checa a custom claim antes de
/// oferecer os botões, pra um operador não bater num 403 sem explicação.
Future<bool> _souAdmin() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
  return token?.claims?["role"] == "admin";
}

/// Lista de abrigos com ocupação — Módulo de Planejamento da Execução.
class AbrigosAba extends StatefulWidget {
  const AbrigosAba({super.key});

  @override
  State<AbrigosAba> createState() => _AbrigosAbaState();
}

class _AbrigosAbaState extends State<AbrigosAba> {
  late final Future<bool> _souAdminFuturo = _souAdmin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Abrigo>>(
        stream: PortalRepositorio().abrigos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EstadoTela(
              icone: Icons.error_outline,
              cor: Cores.alerta500,
              texto: "Não foi possível carregar os abrigos.",
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Cores.flare500),
            );
          }
          final abrigos = snap.data!;
          if (abrigos.isEmpty) {
            return const EstadoTela(
              icone: Icons.home_outlined,
              cor: Cores.textoMedio,
              texto: "Nenhum abrigo cadastrado ainda.",
            );
          }

          return FutureBuilder<bool>(
            future: _souAdminFuturo,
            builder: (context, adminSnap) {
              final souAdmin = adminSnap.data ?? false;
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: abrigos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _AbrigoCartao(abrigo: abrigos[i], podeEditar: souAdmin),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _souAdminFuturo,
        builder: (context, snap) {
          if (snap.data != true) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: Cores.flare500,
            icon: const Icon(Icons.add),
            label: const Text("Novo abrigo"),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CriarAbrigoPagina()),
            ),
          );
        },
      ),
    );
  }

}

class _AbrigoCartao extends StatelessWidget {
  final Abrigo abrigo;
  final bool podeEditar;

  const _AbrigoCartao({required this.abrigo, required this.podeEditar});

  Color get _corOcupacao => corOcupacao(abrigo.percentualOcupacao);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(abrigo.nome, style: Tipografia.tema.titleMedium),
                    const SizedBox(height: 2),
                    Text(abrigo.endereco, style: Tipografia.tema.bodySmall),
                  ],
                ),
              ),
              if (podeEditar)
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Cores.textoMedio,
                    size: 20,
                  ),
                  tooltip: "Editar abrigo",
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CriarAbrigoPagina(abrigoExistente: abrigo),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: abrigo.percentualOcupacao.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Cores.ink700,
              valueColor: AlwaysStoppedAnimation(_corOcupacao),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${abrigo.capacidadeOcupada}/${abrigo.capacidadeTotal} ocupado",
            style: Tipografia.rotulo(cor: _corOcupacao, tamanho: 11),
          ),
          if (abrigo.telefone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: Cores.textoMedio,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    abrigo.telefone,
                    style: Tipografia.tema.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => abrirWhatsApp(
                    abrigo.telefone,
                    mensagem:
                        "Olá! Aqui é da equipe do PetGuia Enchentes 🐾. "
                        "Estamos entrando em contato sobre o abrigo "
                        "${abrigo.nome}.",
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.chat_outlined,
                    size: 16,
                    color: Cores.safe500,
                  ),
                  label: Text(
                    "WhatsApp",
                    style: Tipografia.rotulo(cor: Cores.safe500, tamanho: 11),
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
