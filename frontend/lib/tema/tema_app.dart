import "package:flutter/material.dart";

import "cores.dart";
import "tipografia.dart";

/// Monta o [ThemeData] único do app — todas as telas devem usar os
/// componentes padrão (ver lib/componentes/) em vez de estilizar
/// widgets do zero, pra manter a consistência exigida pelo design
/// system do PetGuia Enchentes.
abstract final class TemaApp {
  static ThemeData get escuro {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: Cores.ink900,
      colorScheme: const ColorScheme.dark(
        surface: Cores.ink900,
        primary: Cores.flare500,
        secondary: Cores.water500,
        error: Cores.alerta500,
        onSurface: Cores.textoAlto,
        onPrimary: Colors.white,
      ),
      textTheme: Tipografia.tema,
      fontFamily: "IBM Plex Sans",
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Cores.ink900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: Tipografia.tema.headlineMedium,
        iconTheme: const IconThemeData(color: Cores.textoAlto),
      ),
      cardTheme: CardThemeData(
        color: Cores.ink800,
        elevation: 0,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Cores.line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Cores.ink800,
        hintStyle: Tipografia.tema.bodyMedium?.copyWith(
          color: Cores.textoBaixo,
        ),
        labelStyle: Tipografia.tema.bodyMedium,
        iconColor: Cores.textoBaixo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.flare500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.alerta500),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Cores.line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Cores.ink800,
        contentTextStyle: Tipografia.tema.bodyMedium?.copyWith(
          color: Cores.textoAlto,
        ),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Cores.lineForte),
        ),
      ),
    );
  }
}
