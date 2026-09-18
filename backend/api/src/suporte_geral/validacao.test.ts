import {validarCep, validarTelefone} from "./validacao";

describe("validarTelefone", () => {
  it("aceita telefone com 10 dígitos (fixo, com DDD)", () => {
    expect(validarTelefone("4732221100")).toBe(true);
  });

  it("aceita telefone com 11 dígitos (celular, com DDD)", () => {
    expect(validarTelefone("47988887777")).toBe(true);
  });

  it("aceita telefone formatado, contando só os dígitos", () => {
    expect(validarTelefone("(47) 98888-7777")).toBe(true);
  });

  it("rejeita telefone com menos ou mais dígitos que o esperado", () => {
    expect(validarTelefone("123")).toBe(false);
    expect(validarTelefone("479888877771")).toBe(false);
    expect(validarTelefone("")).toBe(false);
  });
});

describe("validarCep", () => {
  it("aceita CEP com 8 dígitos, formatado ou não", () => {
    expect(validarCep("89160-000")).toBe(true);
    expect(validarCep("89160000")).toBe(true);
  });

  it("rejeita CEP com quantidade errada de dígitos", () => {
    expect(validarCep("123")).toBe(false);
    expect(validarCep("")).toBe(false);
  });
});
