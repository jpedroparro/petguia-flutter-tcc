import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";

import "autenticacao/login_pagina.dart";
import "firebase_options.dart";
import "tema/tema_app.dart";

/// Aponta Auth/Firestore pros emuladores locais em vez do projeto real —
/// `flutter run --dart-define=USE_EMULATOR=true`, com
/// `firebase emulators:start --only firestore,auth` rodando. Existe pra
/// testar (equipe, cadastro, ações) sem gastar a cota gratuita do
/// Firestore de produção — nunca ativado sem essa flag explícita, então o
/// build normal/publicado não é afetado.
const _usarEmulador = bool.fromEnvironment("USE_EMULATOR");

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmulador) {
    await FirebaseAuth.instance.useAuthEmulator("localhost", 9099);
    FirebaseFirestore.instance.useFirestoreEmulator("localhost", 8080);
  }
  runApp(const PetGuiaEnchentesApp());
}

class PetGuiaEnchentesApp extends StatelessWidget {
  const PetGuiaEnchentesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PetGuia Enchentes",
      theme: TemaApp.escuro,
      // A faixa "DEBUG" cobre o avatar da conta no canto superior direito e
      // suja capturas de tela usadas na documentação do TCC. O login da
      // equipe contra o emulador só funciona em build debug (o
      // firebase_auth_web só reaplica a config do emulador `if (kDebugMode)`),
      // então rodar em release não é alternativa.
      debugShowCheckedModeBanner: false,
      home: const LoginPagina(),
    );
  }
}
