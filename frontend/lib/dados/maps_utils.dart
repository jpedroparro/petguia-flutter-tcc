import "package:url_launcher/url_launcher.dart";

/// Abre a rota até uma coordenada no Google Maps (app ou navegador,
/// dependendo do que o dispositivo tem disponível). Nunca lança: se nada no
/// aparelho conseguir abrir o link, retorna `false` em vez de jogar uma
/// exceção não tratada.
Future<bool> abrirRotaAte(double latitude, double longitude) async {
  final uri = Uri.parse(
    "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude",
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
