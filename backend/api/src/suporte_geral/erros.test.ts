import type {Request, Response} from "express";
import {ErroDominio} from "./erro_dominio";
import {tratadorDeErros} from "./erros";

/**
 * @return {Response} Um mock mínimo de Response do Express, com `status`
 *   e `json` encadeáveis e espiáveis.
 */
function criarRespostaFalsa(): Response {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe("tratadorDeErros", () => {
  const req = {} as Request;
  const next = jest.fn();

  it("expõe a mensagem e o status de um ErroDominio", () => {
    const res = criarRespostaFalsa();
    const erro = new ErroDominio("Mensagem segura para o cliente", 409);

    tratadorDeErros(erro, req, res, next);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({
      data: null,
      error: "Mensagem segura para o cliente",
    });
  });

  it("nunca expõe a mensagem de um erro inesperado — 500 genérico", () => {
    const res = criarRespostaFalsa();
    const original = console.error;
    console.error = jest.fn();

    tratadorDeErros(
      new TypeError("Cannot read property 'x' of undefined"), req, res, next
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      data: null,
      error: "Internal server error",
    });
    console.error = original;
  });

  it("nunca expõe a mensagem de um valor lançado que não é Error", () => {
    const res = criarRespostaFalsa();
    const original = console.error;
    console.error = jest.fn();

    tratadorDeErros("string lançada diretamente", req, res, next);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      data: null,
      error: "Internal server error",
    });
    console.error = original;
  });
});
