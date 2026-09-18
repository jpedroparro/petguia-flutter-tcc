import "package:flutter/material.dart";

import "cores.dart";

/// Rótulos/cores de classificação do rio e das ruas — Módulo de Análise e
/// Decisão. Um único ponto de verdade: antes reimplementado em paralelo em
/// `rio_pagina.dart`, `painel_operador_pagina.dart` e `animais_aba.dart`,
/// com risco de as cores divergirem entre telas que mostram o mesmo dado.

const classificacaoRioLabel = {
  "normal": "Normal",
  "atencao": "Atenção",
  "alerta": "Alerta",
  "emergencia": "Emergência",
};

const classificacaoRioCor = {
  "normal": Cores.safe500,
  "atencao": Cores.lama500,
  "alerta": Cores.flare500,
  "emergencia": Cores.alerta500,
};

const classificacaoRuaLabel = {
  "livre": "Livre",
  "parcial": "Parcialmente alagada",
  "interditada": "Interditada",
  "desconhecida": "Risco desconhecido",
};

const classificacaoRuaCor = {
  "livre": Cores.safe500,
  "parcial": Cores.flare500,
  "interditada": Cores.alerta500,
  "desconhecida": Cores.textoMedio,
};

/// Cor de aviso pela ocupação de um abrigo — lotado (vermelho), quase
/// lotado (âmbar) ou com folga (verde). Antes duplicada entre
/// `abrigos_aba.dart` e `mapa/abrigos_lista_pagina.dart`.
Color corOcupacao(double percentual) {
  if (percentual >= 1) return Cores.alerta500;
  if (percentual >= 0.75) return Cores.flare500;
  return Cores.safe500;
}
