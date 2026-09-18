import "package:flutter/material.dart";

import "cores.dart";

const _display = "Big Shoulders Display";
const _corpo = "IBM Plex Sans";
const _mono = "IBM Plex Mono";

/// Tipografia do PetGuia Enchentes: títulos condensados fortes (Big
/// Shoulders Display) para transmitir urgência/oficialidade, corpo limpo
/// e legível (IBM Plex Sans), e um estilo utilitário em mono maiúsculo
/// para rótulos/badges/timestamps — usado fora do TextTheme padrão.
abstract final class Tipografia {
  static const TextTheme tema = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w800,
      fontSize: 40,
      height: 1.05,
      color: Cores.textoAlto,
    ),
    displayMedium: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w800,
      fontSize: 32,
      height: 1.08,
      color: Cores.textoAlto,
    ),
    headlineLarge: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w700,
      fontSize: 26,
      height: 1.1,
      color: Cores.textoAlto,
    ),
    headlineMedium: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w700,
      fontSize: 22,
      height: 1.15,
      color: Cores.textoAlto,
    ),
    titleLarge: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.2,
      color: Cores.textoAlto,
    ),
    titleMedium: TextStyle(
      fontFamily: _corpo,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: Cores.textoAlto,
    ),
    bodyLarge: TextStyle(
      fontFamily: _corpo,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.4,
      color: Cores.textoAlto,
    ),
    bodyMedium: TextStyle(
      fontFamily: _corpo,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.4,
      color: Cores.textoMedio,
    ),
    bodySmall: TextStyle(
      fontFamily: _corpo,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.35,
      color: Cores.textoBaixo,
    ),
    labelLarge: TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w700,
      fontSize: 15,
      letterSpacing: 0.02,
      color: Cores.textoAlto,
    ),
  );

  /// Rótulo utilitário em mono maiúsculo — "eyebrow", IDs, tags de
  /// status, timestamps. Não faz parte do [TextTheme] padrão do
  /// Material porque não corresponde a nenhum papel semântico dele.
  static TextStyle rotulo({
    double tamanho = 12,
    double espacamento = 0.14,
    Color cor = Cores.textoMedio,
    FontWeight peso = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: _mono,
      fontSize: tamanho,
      fontWeight: peso,
      letterSpacing: tamanho * espacamento,
      color: cor,
    );
  }
}
