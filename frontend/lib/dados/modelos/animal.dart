import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusAnimal { resgatado, emAbrigo, comTutor, reunificado }

StatusAnimal statusAnimalDe(String valor) {
  switch (valor) {
    case 'em_abrigo':
      return StatusAnimal.emAbrigo;
    case 'com_tutor':
      return StatusAnimal.comTutor;
    case 'reunificado':
      return StatusAnimal.reunificado;
    default:
      return StatusAnimal.resgatado;
  }
}

class Animal {
  final String id;
  final String especie;
  final String raca;
  final String porte;
  final String? fotoUrl;
  final StatusAnimal status;
  final String localizacaoResgate;
  final double? latitudeResgate;
  final double? longitudeResgate;
  final String? abrigoId;
  final bool comColeira;
  final String? nomeIdentificacao;

  const Animal({
    required this.id,
    required this.especie,
    required this.raca,
    required this.porte,
    required this.fotoUrl,
    required this.status,
    required this.localizacaoResgate,
    required this.latitudeResgate,
    required this.longitudeResgate,
    required this.abrigoId,
    required this.comColeira,
    required this.nomeIdentificacao,
  });

  factory Animal.doFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data()!;
    return Animal(
      id: doc.id,
      especie: dados['especie'] as String,
      raca: dados['raca'] as String? ?? "SRD (Vira-lata)",
      porte: dados['porte'] as String,
      fotoUrl: dados['fotoUrl'] as String?,
      status: statusAnimalDe(dados['status'] as String),
      localizacaoResgate: dados['localizacaoResgate'] as String,
      latitudeResgate: (dados['latitudeResgate'] as num?)?.toDouble(),
      longitudeResgate: (dados['longitudeResgate'] as num?)?.toDouble(),
      abrigoId: dados['abrigoId'] as String?,
      comColeira: dados['comColeira'] as bool? ?? false,
      nomeIdentificacao: dados['nomeIdentificacao'] as String?,
    );
  }
}
