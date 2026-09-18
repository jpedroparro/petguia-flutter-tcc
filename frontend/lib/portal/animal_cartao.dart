import "package:flutter/material.dart";

import "../componentes/app_card.dart";
import "../dados/maps_utils.dart";
import "../dados/modelos/animal.dart";
import "../tema/cores.dart";
import "../tema/tipografia.dart";
import "foto_tela_cheia_pagina.dart";

const _rotuloStatus = {
  StatusAnimal.resgatado: "Resgatado",
  StatusAnimal.emAbrigo: "Em abrigo",
  StatusAnimal.comTutor: "Com tutor",
  StatusAnimal.reunificado: "Reunificado",
};

const _iconeStatus = {
  StatusAnimal.resgatado: "🆘",
  StatusAnimal.emAbrigo: "🏠",
  StatusAnimal.comTutor: "🏡",
  StatusAnimal.reunificado: "💚",
};

/// Cor semântica por status: flare (urgente/aguardando), water
/// (estável/informativo), safe (resolvido).
const _corStatus = {
  StatusAnimal.resgatado: Cores.flare500,
  StatusAnimal.emAbrigo: Cores.water500,
  StatusAnimal.comTutor: Cores.safe500,
  StatusAnimal.reunificado: Cores.safe500,
};

/// Status em que ainda faz sentido o público solicitar tutoria ou
/// reunificação — depois de resolvido (com tutor/reunificado) não há mais
/// o que solicitar.
const _statusSolicitavel = {StatusAnimal.resgatado, StatusAnimal.emAbrigo};

/// Card de um animal no portal — equivalente ao AnimalCard.tsx do sistema
/// web (mesmos badges de status, mesma ideia de ações por card). Passe
/// [aoSolicitar] só na visão pública (portal); a equipe usa suas próprias
/// ações no painel interno.
class AnimalCartao extends StatelessWidget {
  final Animal animal;
  final VoidCallback? aoSolicitar;
  final ({double latitude, double longitude})? destino;

  const AnimalCartao({
    super.key,
    required this.animal,
    this.aoSolicitar,
    this.destino,
  });

  Future<void> _abrirRota() async {
    final d = destino;
    if (d == null) return;
    await abrirRotaAte(d.latitude, d.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final cor = _corStatus[animal.status]!;
    final podeSolicitar =
        aoSolicitar != null && _statusSolicitavel.contains(animal.status);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: animal.fotoUrl == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FotoTelaCheiaPagina(fotoUrl: animal.fotoUrl!),
                        ),
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: animal.fotoUrl != null
                      ? Image.network(
                          animal.fotoUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: Cores.ink700,
                          alignment: Alignment.center,
                          child: const Text(
                            "🐾",
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.nomeIdentificacao?.isNotEmpty == true
                          ? "${animal.nomeIdentificacao} · ${animal.especie}"
                          : "${animal.especie} · ${animal.raca}",
                      style: Tipografia.tema.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      animal.nomeIdentificacao?.isNotEmpty == true
                          ? "${animal.raca} · porte ${animal.porte}"
                          : "porte ${animal.porte}",
                      style: Tipografia.tema.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            animal.localizacaoResgate,
                            style: Tipografia.tema.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (animal.comColeira) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: "Estava com coleira",
                            child: Icon(
                              Icons.pets,
                              size: 14,
                              color: Cores.textoMedio,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "${_iconeStatus[animal.status]} ${_rotuloStatus[animal.status]}",
                        style: Tipografia.rotulo(
                          cor: Colors.white,
                          tamanho: 11,
                          peso: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (podeSolicitar || destino != null) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (destino != null)
                  TextButton.icon(
                    onPressed: _abrirRota,
                    icon: const Icon(
                      Icons.directions,
                      size: 16,
                      color: Cores.flare500,
                    ),
                    label: Text(
                      "Como chegar",
                      style: Tipografia.rotulo(
                        cor: Cores.flare500,
                        tamanho: 12,
                      ),
                    ),
                  ),
                if (podeSolicitar)
                  TextButton.icon(
                    onPressed: aoSolicitar,
                    icon: const Icon(
                      Icons.pets,
                      size: 16,
                      color: Cores.water500,
                    ),
                    label: Text(
                      "Reconhece este animal?",
                      style: Tipografia.rotulo(
                        cor: Cores.water500,
                        tamanho: 12,
                      ),
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
