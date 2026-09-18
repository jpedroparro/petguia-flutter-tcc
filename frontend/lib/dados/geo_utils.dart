import "dart:math";

import "package:geolocator/geolocator.dart";

/// Pede a posição atual do aparelho — checa se o serviço de localização
/// está ligado e se há permissão, pedindo-a se necessário. Nunca lança:
/// qualquer falha (serviço desligado, permissão negada, timeout) vira
/// null, e quem chama decide como avisar o usuário. Consolida o mesmo
/// bloco antes copiado em cada tela que usa "minha localização".
Future<Position?> obterPosicaoAtual() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Distância aproximada entre duas coordenadas (fórmula de haversine), em
/// quilômetros — mesma fórmula usada no backend
/// (analise_decisao/urgencia_service.ts), pra manter a mesma noção de
/// "perto"/"longe" nos dois lados.
double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
  const raioTerraKm = 6371.0;
  final radLat1 = lat1 * pi / 180;
  final radLat2 = lat2 * pi / 180;
  final deltaLat = (lat2 - lat1) * pi / 180;
  final deltaLon = (lon2 - lon1) * pi / 180;

  final a =
      sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(radLat1) * cos(radLat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return raioTerraKm * c;
}
