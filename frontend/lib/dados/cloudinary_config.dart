import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;

/// Configuração do Cloudinary — hospedagem de fotos dos animais.
/// Usa upload "unsigned" (preset configurado no painel do Cloudinary pra
/// aceitar upload direto do app, sem precisar de chave secreta no cliente).
/// Trocado pelo Firebase Storage porque este passou a exigir o plano pago
/// (Blaze) mesmo dentro do limite gratuito de uso.
class CloudinaryConfig {
  static const cloudName = "toy2zqcs";
  static const uploadPreset = "petguia_animais";

  static Uri get uploadUrl =>
      Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
}

/// Envia uma foto (bytes) pro Cloudinary e retorna a URL pública segura.
Future<String> enviarFotoParaCloudinary(Uint8List arquivo) async {
  final requisicao = http.MultipartRequest("POST", CloudinaryConfig.uploadUrl)
    ..fields["upload_preset"] = CloudinaryConfig.uploadPreset
    ..files.add(
      http.MultipartFile.fromBytes("file", arquivo, filename: "foto.jpg"),
    );
  final resposta = await requisicao.send().timeout(const Duration(seconds: 30));
  final corpo = await resposta.stream.bytesToString();
  if (resposta.statusCode != 200) {
    throw Exception("Falha ao enviar a foto (${resposta.statusCode})");
  }
  final dados = jsonDecode(corpo) as Map<String, dynamic>;
  return dados["secure_url"] as String;
}
