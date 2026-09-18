import "package:flutter/material.dart";

import "../componentes/app_card.dart";
import "../componentes/estado_tela.dart";
import "../dados/maps_utils.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/portal_repositorio.dart";
import "../tema/classificacoes.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Lista simples de abrigos (sem precisar tocar em pino de mapa) — pública,
/// sem login, com botão direto pra abrir a rota no Google Maps.
class AbrigosListaPagina extends StatelessWidget {
  const AbrigosListaPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Abrigos", style: Tipografia.tema.titleLarge)),
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: abrigos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _AbrigoCartao(abrigo: abrigos[i]),
          );
        },
      ),
    );
  }

}

class _AbrigoCartao extends StatelessWidget {
  final Abrigo abrigo;

  const _AbrigoCartao({required this.abrigo});

  Color get _corOcupacao => corOcupacao(abrigo.percentualOcupacao);

  bool get _temLocalizacao =>
      abrigo.latitude != null && abrigo.longitude != null;

  Future<void> _abrirRota() async {
    if (!_temLocalizacao) return;
    await abrirRotaAte(abrigo.latitude!, abrigo.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(abrigo.nome, style: Tipografia.tema.titleMedium),
          const SizedBox(height: 2),
          Text(abrigo.endereco, style: Tipografia.tema.bodySmall),
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
          if (_temLocalizacao) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
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
            ),
          ],
        ],
      ),
    );
  }
}
