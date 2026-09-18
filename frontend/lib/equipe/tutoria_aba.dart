import "package:flutter/material.dart";

import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../dados/funcoes_repositorio.dart";
import "../dados/maps_utils.dart";
import "../dados/modelos/animal.dart";
import "../dados/portal_repositorio.dart";
import "../dados/whatsapp_utils.dart";
import "../portal/animal_cartao.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Lista de animais já com tutor temporário, com os dados de contato do
/// tutor (nome, CPF, telefone) que não aparecem na leitura pública — LGPD,
/// Módulo de Suporte Geral. A decisão de virar tutor é tomada no momento
/// do cadastro do animal (ver `cadastrar_animal_pagina.dart`), então não
/// existe mais fila de aprovação aqui: é só o registro do que já
/// aconteceu.
class TutoriaAba extends StatefulWidget {
  const TutoriaAba({super.key});

  @override
  State<TutoriaAba> createState() => _TutoriaAbaState();
}

class _TutoriaAbaState extends State<TutoriaAba> {
  final _repositorio = FuncoesRepositorio();
  late Future<List<Map<String, dynamic>>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _repositorio.listarSolicitacoesTutoria();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _futuro = _repositorio.listarSolicitacoesTutoria());
        await _futuro;
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, tutoriaSnap) {
          if (tutoriaSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Cores.flare500),
            );
          }
          if (tutoriaSnap.hasError) {
            return const EstadoTela(
              icone: Icons.error_outline,
              cor: Cores.alerta500,
              texto: "Não foi possível carregar as tutorias.",
            );
          }

          final tutoriaPorAnimal = <String, Map<String, dynamic>>{
            for (final t in tutoriaSnap.data ?? const [])
              if (t["status"] == "confirmada") t["animalId"] as String: t,
          };

          return StreamBuilder<List<Animal>>(
            stream: PortalRepositorio().animais(),
            builder: (context, animaisSnap) {
              if (animaisSnap.hasError) {
                return const EstadoTela(
                  icone: Icons.error_outline,
                  cor: Cores.alerta500,
                  texto: "Não foi possível carregar os animais.",
                );
              }
              if (!animaisSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Cores.flare500),
                );
              }
              final comTutor = animaisSnap.data!
                  .where((a) => a.status == StatusAnimal.comTutor)
                  .toList();

              if (comTutor.isEmpty) {
                return const EstadoTela(
                  icone: Icons.house_outlined,
                  cor: Cores.textoMedio,
                  texto: "Nenhum animal com tutor temporário ainda.",
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: comTutor.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final animal = comTutor[i];
                  final tutoria = tutoriaPorAnimal[animal.id];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimalCartao(animal: animal),
                      if (tutoria != null) ...[
                        const SizedBox(height: 8),
                        _CartaoTutor(tutoria: tutoria, animal: animal),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

}

class _CartaoTutor extends StatelessWidget {
  final Map<String, dynamic> tutoria;
  final Animal animal;

  const _CartaoTutor({required this.tutoria, required this.animal});

  bool get _temLocalizacao =>
      animal.latitudeResgate != null && animal.longitudeResgate != null;

  String? get _telefone {
    final valor = tutoria["telefoneTutor"] as String?;
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  Future<void> _abrirRota() async {
    if (!_temLocalizacao) return;
    await abrirRotaAte(animal.latitudeResgate!, animal.longitudeResgate!);
  }

  Future<void> _abrirWhats() async {
    final telefone = _telefone;
    if (telefone == null) return;
    await abrirWhatsApp(
      telefone,
      mensagem:
          "Olá! Aqui é da equipe do PetGuia Enchentes 🐾. Estamos "
          "fazendo o acompanhamento do(a) ${animal.especie.toLowerCase()} "
          "que ficou com você — pode nos dar notícias de como ele(a) está?",
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tutor: ${tutoria["nomeTutor"] ?? "—"}",
            style: Tipografia.tema.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            "CPF: ${tutoria["cpfTutor"] ?? "—"}",
            style: Tipografia.tema.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            "Telefone: ${_telefone ?? "—"}",
            style: Tipografia.tema.bodySmall,
          ),
          if (_temLocalizacao) ...[
            const SizedBox(height: 2),
            Text(
              "\"Como chegar\" leva ao local do resgate, não à casa do tutor "
              "(endereço não é coletado)",
              style: Tipografia.tema.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (_temLocalizacao)
                TextButton.icon(
                  onPressed: _abrirRota,
                  icon: const Icon(
                    Icons.directions,
                    size: 16,
                    color: Cores.flare500,
                  ),
                  label: Text(
                    "Como chegar",
                    style: Tipografia.rotulo(cor: Cores.flare500, tamanho: 12),
                  ),
                ),
              if (_telefone != null)
                TextButton.icon(
                  onPressed: _abrirWhats,
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
        ],
      ),
    );
  }
}
