import "package:flutter/foundation.dart"
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// URL base da API auto-hospedada (módulo de Cognição do RADIAN).
/// 10.0.2.2 é o alias que o emulador Android usa para o localhost da
/// máquina host. Em dispositivo físico na mesma rede, passe o IP da
/// máquina que roda o backend via `--dart-define=API_HOST=192.168.x.x`.
/// Em produção (ex: Render), pode-se passar a URL pública completa via
/// `--dart-define=API_BASE_URL=https://...`, mas o build web usa por padrão
/// o serviço de produção no Render (nenhuma das duas dá pra detectar em
/// tempo de execução). Usa `defaultTargetPlatform`/`kIsWeb` (não
/// `dart:io`'s `Platform`), que quebra a compilação para Web — um dos
/// alvos suportados pelo app.
class ApiConfig {
  static const String _producaoWeb =
      "https://petguia-enchentes-mobile.onrender.com";

  static String get baseUrl {
    const baseUrl = String.fromEnvironment("API_BASE_URL");
    if (baseUrl.isNotEmpty) return baseUrl;
    const host = String.fromEnvironment("API_HOST");
    if (host.isNotEmpty) return "http://$host:8090";
    if (kIsWeb) return _producaoWeb;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8090";
    }
    return "http://localhost:8090";
  }
}
