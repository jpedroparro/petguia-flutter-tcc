import {
  classificarNivelRio,
  montarEstadoRio,
  ruasAfetadas,
} from "./rio_classificacao";
import type {RuaCota} from "../gestao_dados/types";

function rua(sobrescritas: Partial<RuaCota> = {}): RuaCota {
  return {
    id: "rua-1",
    nome: "Rua Teste",
    cotaMinima: 4,
    cotaMaxima: 6,
    latitude: null,
    longitude: null,
    ...sobrescritas,
  };
}

describe("classificarNivelRio", () => {
  it("classifica como normal abaixo de 4,5m", () => {
    expect(classificarNivelRio(0)).toBe("normal");
    expect(classificarNivelRio(4.49)).toBe("normal");
  });

  it("classifica como atenção a partir de 4,5m", () => {
    expect(classificarNivelRio(4.5)).toBe("atencao");
    expect(classificarNivelRio(5.49)).toBe("atencao");
  });

  it("classifica como alerta a partir de 5,5m", () => {
    expect(classificarNivelRio(5.5)).toBe("alerta");
    expect(classificarNivelRio(6.49)).toBe("alerta");
  });

  it("classifica como emergência a partir de 6,5m", () => {
    expect(classificarNivelRio(6.5)).toBe("emergencia");
    expect(classificarNivelRio(9)).toBe("emergencia");
  });
});

describe("ruasAfetadas", () => {
  it("não inclui ruas livres (nível abaixo da cota mínima)", () => {
    const resultado = ruasAfetadas([rua({cotaMinima: 4, cotaMaxima: 6})], 3);
    expect(resultado).toHaveLength(0);
  });

  it("inclui ruas parcialmente alagadas", () => {
    const resultado = ruasAfetadas([rua({cotaMinima: 4, cotaMaxima: 6})], 5);
    expect(resultado).toEqual([expect.objectContaining({status: "parcial"})]);
  });

  it("inclui ruas interditadas", () => {
    const resultado = ruasAfetadas([rua({cotaMinima: 4, cotaMaxima: 6})], 7);
    expect(resultado).toEqual([expect.objectContaining({status: "interditada"})]);
  });

  it("mistura ruas livres e afetadas, retornando só as afetadas", () => {
    const resultado = ruasAfetadas(
      [
        rua({id: "livre", cotaMinima: 10, cotaMaxima: 12}),
        rua({id: "afetada", cotaMinima: 4, cotaMaxima: 6}),
      ],
      5
    );
    expect(resultado.map((r) => r.id)).toEqual(["afetada"]);
  });
});

describe("montarEstadoRio", () => {
  it("classifica normalmente quando há leitura do nível", () => {
    const estado = montarEstadoRio(5, [rua({cotaMinima: 4, cotaMaxima: 6})]);
    expect(estado.nivelAtual).toBe(5);
    expect(estado.classificacao).toBe("atencao");
    expect(estado.ruasBloqueadas).toHaveLength(1);
  });

  it(
    "nunca reporta 'normal' quando não há leitura — classificação vem null",
    () => {
      // Regressão: a telemetria fora do ar (nivelAtual null) não pode virar
      // "normal" — 0 é literalmente o nível mais baixo possível, então
      // `classificarNivelRio(0)` sempre retornaria "normal", mentindo sobre
      // o rio estar de fato baixo quando na verdade não há dado nenhum.
      const estado = montarEstadoRio(null, [rua()]);
      expect(estado.nivelAtual).toBeNull();
      expect(estado.classificacao).toBeNull();
      expect(estado.ruasBloqueadas).toEqual([]);
    }
  );
});
