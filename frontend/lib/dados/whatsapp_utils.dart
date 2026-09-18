import "package:url_launcher/url_launcher.dart";

/// Abre o WhatsApp com um número de telefone brasileiro — aceita número já
/// formatado ("(47) 99999-0000") ou só dígitos, sempre com DDI 55. Se
/// [mensagem] for informada, já vem preenchida (o usuário ainda confirma
/// o envio manualmente). Nunca lança: se não houver app/navegador capaz de
/// abrir o link, retorna `false` em vez de jogar uma exceção não tratada.
Future<bool> abrirWhatsApp(String telefone, {String? mensagem}) async {
  var digitos = telefone.replaceAll(RegExp(r"\D"), "");
  if (!digitos.startsWith("55")) digitos = "55$digitos";
  final uri = Uri.https(
    "wa.me",
    "/$digitos",
    mensagem == null ? null : {"text": mensagem},
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
