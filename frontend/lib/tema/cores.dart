import "package:flutter/material.dart";

/// Tokens de cor do PetGuia Enchentes — tema "console de operação de
/// campo": base verde-escura para uso noturno, acento laranja-sinalizador
/// (flare, ação/urgência) e acento teal (água, informação).
abstract final class Cores {
  static const ink950 = Color(0xFF000000);
  static const ink900 = Color(0xFF0A1613);
  static const ink800 = Color(0xFF11241F);
  static const ink700 = Color(0xFF17322B);

  static const line = Color(0x17FFFFFF);
  static const lineForte = Color(0x2EFFFFFF);

  /// Neutros puxados pro verde, não pro azul: cinza azulado sobre base
  /// verde lê como cor errada, não como neutro.
  static const textoAlto = Color(0xFFEDF3EE);
  static const textoMedio = Color(0xFF9FB3AB);
  static const textoBaixo = Color(0xFF5C736A);

  static const flare500 = Color(0xFFEA6C30);
  static const flare600 = Color(0xFFC5501C);

  static const water500 = Color(0xFF3FA79C);
  static const safe500 = Color(0xFF6FB07A);
  static const alerta500 = Color(0xFFE5504F);

  /// Ocre de água de enchente — o rio real é barrento, não azul. Usado no
  /// nível "atenção" (entre normal e alerta) para dar aos quatro estágios
  /// da cota do rio quatro cores distintas em vez de dividir em só duas.
  static const lama500 = Color(0xFFC4923F);

  /// Brilho sutil atrás de elementos em foco/ação (botão primário, input
  /// focado) — mesma cor do flare, com transparência.
  static const flareGlow = Color(0x59EA6C30);
}
