import "package:flutter/material.dart";

/// Mostra a foto do animal em tamanho normal, com zoom — pra quem está
/// procurando o próprio bichinho conseguir reconhecer de verdade, não só
/// pela miniatura pequena do card.
class FotoTelaCheiaPagina extends StatelessWidget {
  final String fotoUrl;

  const FotoTelaCheiaPagina({super.key, required this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            fotoUrl,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white54);
            },
          ),
        ),
      ),
    );
  }
}
