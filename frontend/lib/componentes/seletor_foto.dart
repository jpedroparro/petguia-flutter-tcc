import "dart:typed_data";

import "package:flutter/material.dart";

import "../tema/cores.dart";
import "../tema/tipografia.dart";

/// Card tocável pra escolher/trocar uma foto — mostra a prévia em memória
/// quando já há uma, ou um placeholder "Adicionar foto" quando vazio.
class SeletorFoto extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback aoTocar;

  const SeletorFoto({super.key, required this.bytes, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Cores.line),
          color: Cores.ink800,
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Cores.ink900,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Cores.textoAlto,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: Cores.textoBaixo,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text("Adicionar foto", style: Tipografia.tema.bodyMedium),
                ],
              ),
      ),
    );
  }
}
