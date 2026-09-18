/// Valida um telefone de contato brasileiro (10 ou 11 dígitos, com DDD) —
/// mesma regra usada no backend (suporte_geral/validacao.ts).
bool validarTelefone(String telefone) {
  final digitos = telefone.replaceAll(RegExp(r"\D"), "").length;
  return digitos == 10 || digitos == 11;
}

/// Valida um CEP brasileiro (8 dígitos) — mesma regra do backend
/// (suporte_geral/validacao.ts).
bool validarCep(String cep) {
  return cep.replaceAll(RegExp(r"\D"), "").length == 8;
}

int _calcularDigitoVerificador(String base) {
  var soma = 0;
  var peso = base.length + 1;
  for (final char in base.split("")) {
    soma += int.parse(char) * peso;
    peso -= 1;
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

/// Valida um CPF pelo formato e pelos dígitos verificadores — mesmo
/// algoritmo do backend (suporte_geral/cpf.ts). Só confirma a estrutura do
/// número (dígitos verificadores corretos), não se o CPF existe de fato —
/// a validação de existência real fica com a Receita Federal, fora de
/// escopo aqui.
bool validarCPF(String cpf) {
  final digitos = cpf.replaceAll(RegExp(r"\D"), "");
  if (digitos.length != 11) return false;
  if (RegExp(r"^(\d)\1{10}$").hasMatch(digitos)) return false;

  final base = digitos.substring(0, 9);
  final primeiroDigito = _calcularDigitoVerificador(base);
  final segundoDigito = _calcularDigitoVerificador("$base$primeiroDigito");

  return digitos == "$base$primeiroDigito$segundoDigito";
}
