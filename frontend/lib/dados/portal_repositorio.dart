import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'modelos/abrigo.dart';
import 'modelos/animal.dart';

/// Leitura pública dos dados do portal — corresponde ao que o Módulo de
/// Gestão de Dados expõe sem exigir autenticação (mesmas regras do
/// firestore.rules: animais e abrigos têm leitura pública).
///
/// `animais()`/`abrigos()` são chamados dentro de `build()` em várias telas
/// (Portal, Mapa, várias abas da equipe) — sem cache, cada chamada criaria
/// um `Stream` novo, e como `StreamBuilder` compara por identidade, toda
/// reconstrução do widget fecharia o listener do Firestore e abriria outro
/// do zero, relendo a coleção inteira como se fosse a primeira vez.
/// Cacheando aqui, todo chamador recebe o mesmo `Stream` (compartilhando um
/// único listener por coleção, não um por tela) e reconstruções não custam
/// leitura nenhuma.
///
/// [_comReplay] existe porque alguns assinantes chegam bem depois da
/// primeira emissão (ex: `TutoriaAba` só assina `animais()` depois que sua
/// própria chamada HTTP termina) — um `Stream` broadcast comum não repete
/// pra quem assina atrasado, e como os dados não emitem de novo sozinhos,
/// esse assinante ficava esperando pra sempre (`StreamBuilder` preso em
/// "carregando"). Com replay, todo novo ouvinte recebe o último valor na
/// hora, além das emissões futuras.
class PortalRepositorio {
  final FirebaseFirestore _db;

  PortalRepositorio({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static Stream<List<Animal>>? _animaisCache;
  static Stream<List<Abrigo>>? _abrigosCache;

  Stream<List<Animal>> animais() {
    return _animaisCache ??= _comReplay(
      _db
          .collection('animais')
          .orderBy('criadoEm', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(Animal.doFirestore).toList()),
    );
  }

  Stream<List<Abrigo>> abrigos() {
    return _abrigosCache ??= _comReplay(
      _db
          .collection('abrigos')
          .where('ativo', isEqualTo: true)
          .snapshots()
          .map((snap) => snap.docs.map(Abrigo.doFirestore).toList()),
    );
  }

  static Stream<T> _comReplay<T>(Stream<T> origem) {
    T? ultimoValor;
    var temValor = false;
    final controlador = StreamController<T>.broadcast();
    origem.listen(
      (valor) {
        ultimoValor = valor;
        temValor = true;
        controlador.add(valor);
      },
      onError: controlador.addError,
    );

    return Stream<T>.multi((novoOuvinte) {
      if (temValor) novoOuvinte.add(ultimoValor as T);
      final assinatura = controlador.stream.listen(
        novoOuvinte.add,
        onError: novoOuvinte.addError,
        onDone: novoOuvinte.close,
      );
      novoOuvinte.onCancel = assinatura.cancel;
    });
  }
}
