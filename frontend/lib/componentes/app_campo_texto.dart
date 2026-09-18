import "package:flutter/material.dart";

import "../tema/cores.dart";

/// Campo de texto padrão — mesma superfície dos cards, ícone à esquerda
/// em text-lo, foco com borda flare-500 + glow sutil.
class AppCampoTexto extends StatefulWidget {
  final TextEditingController? controller;
  final String rotulo;
  final IconData? icone;
  final bool senha;
  final TextInputType? tipoTeclado;
  final String? Function(String?)? validador;

  const AppCampoTexto({
    super.key,
    this.controller,
    required this.rotulo,
    this.icone,
    this.senha = false,
    this.tipoTeclado,
    this.validador,
  });

  @override
  State<AppCampoTexto> createState() => _AppCampoTextoState();
}

class _AppCampoTextoState extends State<AppCampoTexto> {
  final _foco = FocusNode();
  bool _emFoco = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() => _emFoco = _foco.hasFocus));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _emFoco
            ? const [
                BoxShadow(
                  color: Cores.flareGlow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _foco,
        obscureText: widget.senha,
        keyboardType: widget.tipoTeclado,
        validator: widget.validador,
        style: const TextStyle(color: Cores.textoAlto),
        decoration: InputDecoration(
          labelText: widget.rotulo,
          prefixIcon: widget.icone != null
              ? Icon(widget.icone, color: Cores.textoBaixo)
              : null,
        ),
      ),
    );
  }
}
