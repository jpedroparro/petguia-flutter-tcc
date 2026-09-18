import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../componentes/estado_tela.dart";
import "../dados/maps_utils.dart";
import "../dados/modelos/abrigo.dart";
import "../dados/portal_repositorio.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";

Future<void> _abrirRotaAte(Abrigo abrigo) async {
  await abrirRotaAte(abrigo.latitude!, abrigo.longitude!);
}

/// Mapa com os abrigos que já têm localização marcada — versão inicial;
/// cálculo de rota até um abrigo específico é uma tela à parte (Rota).
class MapaPagina extends StatelessWidget {
  const MapaPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapa", style: Tipografia.tema.titleLarge)),
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

          final comLocalizacao = snap.data!
              .where((a) => a.latitude != null && a.longitude != null)
              .toList();

          if (comLocalizacao.isEmpty) {
            return const EstadoTela(
              icone: Icons.map_outlined,
              cor: Cores.textoMedio,
              texto: "Nenhum abrigo com localização marcada ainda.",
            );
          }

          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                comLocalizacao.first.latitude!,
                comLocalizacao.first.longitude!,
              ),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "br.com.jpedroparro.petguia_enchentes",
              ),
              MarkerLayer(
                markers: [
                  for (final abrigo in comLocalizacao)
                    Marker(
                      point: LatLng(abrigo.latitude!, abrigo.longitude!),
                      width: 160,
                      height: 60,
                      child: _MarcadorAbrigo(abrigo: abrigo),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

}

class _MarcadorAbrigo extends StatelessWidget {
  final Abrigo abrigo;

  const _MarcadorAbrigo({required this.abrigo});

  void _abrirDetalhes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Cores.ink800,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(abrigo.nome, style: Tipografia.tema.titleLarge),
              const SizedBox(height: 4),
              Text(abrigo.endereco, style: Tipografia.tema.bodyMedium),
              const SizedBox(height: 4),
              Text(
                "${abrigo.capacidadeOcupada}/${abrigo.capacidadeTotal} ocupado",
                style: Tipografia.tema.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _abrirRotaAte(abrigo);
                },
                style: FilledButton.styleFrom(backgroundColor: Cores.flare500),
                icon: const Icon(Icons.directions),
                label: const Text("Como chegar"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirDetalhes(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Cores.ink900,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Cores.line),
            ),
            child: Text(
              abrigo.nome,
              style: Tipografia.rotulo(cor: Cores.textoAlto, tamanho: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.location_on, color: Cores.flare500, size: 30),
        ],
      ),
    );
  }
}
