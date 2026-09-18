/// Idade em anos completos na data de hoje, a partir da data de nascimento.
int idadeEm(DateTime nascimento) {
  final hoje = DateTime.now();
  var idade = hoje.year - nascimento.year;
  final aindaNaoFezAniversario =
      hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day);
  if (aindaNaoFezAniversario) idade -= 1;
  return idade;
}

/// Data de nascimento no formato ISO (yyyy-MM-dd) esperado pelo backend.
String dataNascimentoIso(DateTime nascimento) {
  return "${nascimento.year.toString().padLeft(4, '0')}-"
      "${nascimento.month.toString().padLeft(2, '0')}-"
      "${nascimento.day.toString().padLeft(2, '0')}";
}
