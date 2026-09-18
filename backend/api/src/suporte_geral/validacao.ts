/**
 * Valida um telefone de contato brasileiro (10 ou 11 dígitos, com DDD) —
 * mesma regra usada por todo fluxo que coleta telefone de contato
 * (abrigo, resgate, reunificação, tutoria), antes espalhada e duplicada
 * em cada service.
 * @param {string} telefone Telefone em qualquer formato.
 * @return {boolean} Verdadeiro se tem 10 ou 11 dígitos.
 */
export function validarTelefone(telefone: string): boolean {
  const digitos = telefone.replace(/\D/g, "").length;
  return digitos === 10 || digitos === 11;
}

/**
 * Valida um CEP brasileiro (8 dígitos).
 * @param {string} cep CEP em qualquer formato.
 * @return {boolean} Verdadeiro se tem 8 dígitos.
 */
export function validarCep(cep: string): boolean {
  return cep.replace(/\D/g, "").length === 8;
}
