import type {NextFunction, Request, Response} from "express";
import {ErroDominio} from "./erro_dominio";

/**
 * Middleware central de tratamento de erros — todo erro lançado (ou
 * encaminhado via `next(err)`) por uma rota passa por aqui antes de virar
 * resposta HTTP. Mantém o formato `{ data, error }` (mesmo shape do
 * sistema web). Só erros que estendem `ErroDominio` (validação,
 * autorização, não encontrado, conflito — sempre escritos à mão no
 * service layer, com mensagem pensada para o usuário final) têm a
 * mensagem exposta ao cliente; qualquer outro erro (bug, falha do
 * Firestore, etc.) vira 500 genérico, com o detalhe completo só no log do
 * servidor — nunca stack trace pro cliente.
 * @param {unknown} err Erro lançado por uma rota ou middleware.
 * @param {Request} req Requisição HTTP.
 * @param {Response} res Resposta HTTP.
 * @param {NextFunction} next Próximo middleware (não usado; assinatura
 *   de 4 argumentos é exigida pelo Express para reconhecer error handlers).
 * @return {void} Nada.
 */
export function tratadorDeErros(
  err: unknown,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  next: NextFunction
): void {
  if (err instanceof ErroDominio) {
    res.status(err.httpStatus).json({data: null, error: err.message});
    return;
  }

  console.error("Erro inesperado:", err);
  res.status(500).json({data: null, error: "Internal server error"});
}

type HandlerAssincrono = (req: Request, res: Response) => Promise<unknown>;
type HandlerExpress =
  (req: Request, res: Response, next: NextFunction) => void;

/**
 * Envolve um handler assíncrono para encaminhar rejeições ao
 * `tratadorDeErros` — Express 4 não faz isso sozinho.
 * @param {HandlerAssincrono} fn Handler da rota.
 * @return {HandlerExpress} O handler encapsulado.
 */
export function assincrono(fn: HandlerAssincrono): HandlerExpress {
  return (req, res, next) => {
    fn(req, res).catch(next);
  };
}
