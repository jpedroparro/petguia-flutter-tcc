import 'package:cloud_firestore/cloud_firestore.dart';

class Abrigo {
  final String id;
  final String nome;
  final String endereco;
  final String cep;
  final String telefone;
  final int capacidadeTotal;
  final int capacidadeOcupada;
  final double? latitude;
  final double? longitude;

  const Abrigo({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.cep,
    required this.telefone,
    required this.capacidadeTotal,
    required this.capacidadeOcupada,
    this.latitude,
    this.longitude,
  });

  double get percentualOcupacao =>
      capacidadeTotal == 0 ? 0 : capacidadeOcupada / capacidadeTotal;

  factory Abrigo.doFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data()!;
    return Abrigo(
      id: doc.id,
      nome: dados['nome'] as String,
      endereco: dados['endereco'] as String,
      cep: dados['cep'] as String,
      telefone: dados['telefone'] as String,
      capacidadeTotal: dados['capacidadeTotal'] as int,
      capacidadeOcupada: dados['capacidadeOcupada'] as int,
      latitude: (dados['latitude'] as num?)?.toDouble(),
      longitude: (dados['longitude'] as num?)?.toDouble(),
    );
  }
}
