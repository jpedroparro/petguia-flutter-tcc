/**
 * Base de todo erro de negócio esperado (validação, não encontrado,
 * conflito, autorização) — carrega o status HTTP certo junto com a
 * mensagem. Só erros que estendem esta classe têm a mensagem exposta ao
 * cliente pelo `tratadorDeErros`; qualquer outro erro (bug, falha do
 * Firestore, etc.) vira uma resposta 500 genérica, sem vazar detalhe
 * interno — módulo de Suporte Geral (segurança computacional).
 */
export class ErroDominio extends Error {
  readonly httpStatus: number;

  /**
   * @param {string} mensagem Mensagem segura para exibir ao cliente.
   * @param {number} httpStatus Status HTTP correspondente.
   */
  constructor(mensagem: string, httpStatus: number) {
    super(mensagem);
    this.httpStatus = httpStatus;
  }
}
