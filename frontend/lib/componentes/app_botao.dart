import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Botão primário — gradiente flare-500 → flare-600, usado pra ações
/// principais (entrar, confirmar, enviar).
class AppBotaoPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? aoPressionar;
  final bool carregando;

  const AppBotaoPrimario({
    super.key,
    required this.texto,
    required this.aoPressionar,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    final desabilitado = aoPressionar == null || carregando;
    const forma = BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: forma,
        gradient: desabilitado
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Cores.flare500, Cores.flare600],
              ),
        color: desabilitado ? Cores.ink700 : null,
        shadows: desabilitado
            ? null
            : const [
                BoxShadow(
                  color: Cores.flareGlow,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: desabilitado ? null : aoPressionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: carregando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      texto.toUpperCase(),
                      style: Tipografia.tema.labelLarge?.copyWith(
                        color: desabilitado ? Cores.textoBaixo : Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão secundário — fundo ink-800, borda line-strong, usado pra ações
/// alternativas (cancelar, voltar, ação de menor prioridade).
class AppBotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? aoPressionar;

  const AppBotaoSecundario({
    super.key,
    required this.texto,
    required this.aoPressionar,
  });

  @override
  Widget build(BuildContext context) {
    const forma = BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      side: BorderSide(color: Cores.lineForte),
    );
    return DecoratedBox(
      decoration: const ShapeDecoration(color: Cores.ink800, shape: forma),
      child: Material(
        color: Colors.transparent,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: aoPressionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                texto.toUpperCase(),
                style: Tipografia.tema.labelLarge?.copyWith(
                  color: Cores.textoAlto,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
