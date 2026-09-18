/**
 * Remove tudo que não for dígito.
 * @param {string} cpf CPF em qualquer formato.
 * @return {string} Apenas os dígitos.
 */
export function apenasDigitos(cpf: string): string {
  return cpf.replace(/\D/g, "");
}

/**
 * Calcula um dígito verificador de CPF pelo algoritmo padrão.
 * @param {string} base Dígitos base para o cálculo.
 * @return {number} Dígito verificador calculado.
 */
function calcularDigitoVerificador(base: string): number {
  let soma = 0;
  let peso = base.length + 1;
  for (const char of base) {
    soma += Number(char) * peso;
    peso -= 1;
  }
  const resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

/**
 * Valida um CPF pelo formato e pelos dígitos verificadores.
 * @param {string} cpf CPF em qualquer formato.
 * @return {boolean} Verdadeiro se o CPF é estruturalmente válido.
 */
export function validarCPF(cpf: string): boolean {
  const digitos = apenasDigitos(cpf);
  if (digitos.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(digitos)) return false;

  const base = digitos.slice(0, 9);
  const primeiroDigito = calcularDigitoVerificador(base);
  const segundoDigito = calcularDigitoVerificador(base + primeiroDigito);

  return digitos === base + String(primeiroDigito) + String(segundoDigito);
}
