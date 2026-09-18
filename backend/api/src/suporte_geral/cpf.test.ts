import {validarCPF} from "./cpf";

describe("validarCPF", () => {
  it("aceita um CPF válido com dígitos verificadores corretos", () => {
    expect(validarCPF("111.444.777-35")).toBe(true);
    expect(validarCPF("11144477735")).toBe(true);
  });

  it("rejeita um CPF com dígito verificador errado", () => {
    expect(validarCPF("111.444.777-36")).toBe(false);
  });

  it("rejeita CPFs com todos os dígitos iguais", () => {
    expect(validarCPF("111.111.111-11")).toBe(false);
    expect(validarCPF("00000000000")).toBe(false);
  });

  it("rejeita string com número errado de dígitos", () => {
    expect(validarCPF("123.456.789")).toBe(false);
    expect(validarCPF("")).toBe(false);
  });
});
