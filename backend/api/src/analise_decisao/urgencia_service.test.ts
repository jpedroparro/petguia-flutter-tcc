import type {Animal, LeituraRio, RuaCota} from "../gestao_dados/types";
import {
  calcularTendencia,
  classificarRua,
  distanciaKm,
  encontrarRuaMaisProxima,
  estimarHorasAteInterditar,
  UrgenciaService,
} from "./urgencia_service";

/**
 * @param {Partial<Animal>} sobrescritas Campos a sobrescrever no fixture.
 * @return {Animal} Um animal resgatado de teste, em Rio do Sul-SC.
 */
function animal(sobrescritas: Partial<Animal> = {}): Animal {
  return {
    id: "animal-1",
    especie: "cachorro",
    raca: "SRD",
    porte: "medio",
    estadoSaude: "estável",
    localizacaoResgate: "Rua Teste, 100",
    cepResgate: "89160-000",
    latitudeResgate: -27.2145,
    longitudeResgate: -49.6431,
    comColeira: false,
    nomeIdentificacao: null,
    telefoneContato: null,
    fotoUrl: null,
    abrigoId: null,
    status: "resgatado",
    registradoPor: "uid-equipe",
    criadoEm: new Date().toISOString(),
    ...sobrescritas,
  };
}

/**
 * @param {Partial<RuaCota>} sobrescritas Campos a sobrescrever no fixture.
 * @return {RuaCota} Uma rua de teste com cota mínima/máxima cadastrada.
 */
function rua(sobrescritas: Partial<RuaCota> = {}): RuaCota {
  return {
    id: "rua-1",
    nome: "Rua Centro",
    cotaMinima: 8,
    cotaMaxima: 11,
    latitude: -27.2145,
    longitude: -49.6431,
    ...sobrescritas,
  };
}

const PESO_RISCO_PARCIAL = 50;

/**
 * @param {Partial<LeituraRio>} sobrescritas Campos a sobrescrever no fixture.
 * @return {LeituraRio} Uma leitura de nível do rio de teste.
 */
function leitura(sobrescritas: Partial<LeituraRio> = {}): LeituraRio {
  return {
    id: "leitura-1",
    nivel: 9,
    fonte: "asthon",
    coletadoEm: new Date().toISOString(),
    ...sobrescritas,
  };
}

describe("distanciaKm", () => {
  it("retorna ~0 para o mesmo ponto", () => {
    const dist = distanciaKm(-27.2145, -49.6431, -27.2145, -49.6431);
    expect(dist).toBeCloseTo(0, 5);
  });

  it("retorna uma distância positiva para pontos diferentes", () => {
    const dist = distanciaKm(-27.2145, -49.6431, -27.22, -49.65);
    expect(dist).toBeGreaterThan(0);
  });
});

describe("encontrarRuaMaisProxima", () => {
  it("retorna a rua com menor distância", () => {
    const perto = rua({
      id: "perto", latitude: -27.2145, longitude: -49.6431,
    });
    const longe = rua({id: "longe", latitude: -27.5, longitude: -50});
    const resultado = encontrarRuaMaisProxima(
      animal({latitudeResgate: -27.2146, longitudeResgate: -49.6432}),
      [longe, perto]
    );
    expect(resultado?.id).toBe("perto");
  });

  it("retorna null se o animal não tem coordenadas", () => {
    const resultado = encontrarRuaMaisProxima(
      animal({latitudeResgate: null, longitudeResgate: null}),
      [rua()]
    );
    expect(resultado).toBeNull();
  });

  it("retorna null se nenhuma rua tem coordenadas", () => {
    const resultado = encontrarRuaMaisProxima(
      animal(),
      [rua({latitude: null, longitude: null})]
    );
    expect(resultado).toBeNull();
  });
});

describe("classificarRua", () => {
  it("classifica como livre abaixo da cota mínima", () => {
    const r = rua({cotaMinima: 8, cotaMaxima: 11});
    expect(classificarRua(7, r)).toBe("livre");
  });

  it("classifica como parcial entre a cota mínima e a máxima", () => {
    const r = rua({cotaMinima: 8, cotaMaxima: 11});
    expect(classificarRua(9, r)).toBe("parcial");
  });

  it("classifica como interditada na cota máxima ou acima", () => {
    const r = rua({cotaMinima: 8, cotaMaxima: 11});
    expect(classificarRua(11, r)).toBe("interditada");
    expect(classificarRua(15, r)).toBe("interditada");
  });

  it("nunca classifica como interditada quando não há cota máxima", () => {
    const r = rua({cotaMinima: 8, cotaMaxima: null});
    expect(classificarRua(999, r)).toBe("parcial");
  });
});

describe("calcularTendencia", () => {
  it("retorna 0 com menos de duas leituras", () => {
    expect(calcularTendencia([leitura()])).toBe(0);
    expect(calcularTendencia([])).toBe(0);
  });

  it("calcula cm/h positivo quando o rio está subindo", () => {
    const agora = Date.now();
    const duasHorasAtras = new Date(agora - 2 * 3600 * 1000).toISOString();
    const tendencia = calcularTendencia([
      leitura({nivel: 8, coletadoEm: duasHorasAtras}),
      leitura({nivel: 10, coletadoEm: new Date(agora).toISOString()}),
    ]);
    expect(tendencia).toBeCloseTo(1, 5);
  });

  it("calcula cm/h negativo quando o rio está baixando", () => {
    const agora = Date.now();
    const umaHoraAtras = new Date(agora - 1 * 3600 * 1000).toISOString();
    const tendencia = calcularTendencia([
      leitura({nivel: 10, coletadoEm: umaHoraAtras}),
      leitura({nivel: 9, coletadoEm: new Date(agora).toISOString()}),
    ]);
    expect(tendencia).toBeCloseTo(-1, 5);
  });

  it("ignora a ordem de entrada das leituras", () => {
    const agora = Date.now();
    const umaHoraAtras = new Date(agora - 3600 * 1000).toISOString();
    const recente = leitura({
      nivel: 10, coletadoEm: new Date(agora).toISOString(),
    });
    const antiga = leitura({nivel: 8, coletadoEm: umaHoraAtras});
    expect(calcularTendencia([recente, antiga])).toBeCloseTo(2, 5);
  });
});

describe("estimarHorasAteInterditar", () => {
  it("retorna null sem cota máxima definida", () => {
    const r = rua({cotaMaxima: null});
    expect(estimarHorasAteInterditar(9, 1, r)).toBeNull();
  });

  it("retorna 0 quando já atingiu ou passou a cota máxima", () => {
    const r = rua({cotaMaxima: 11});
    expect(estimarHorasAteInterditar(11, 1, r)).toBe(0);
  });

  it("retorna null quando o rio não está subindo", () => {
    const r = rua({cotaMaxima: 11});
    expect(estimarHorasAteInterditar(9, 0, r)).toBeNull();
    expect(estimarHorasAteInterditar(9, -1, r)).toBeNull();
  });

  it("estima horas proporcional à distância até a cota máxima", () => {
    const r = rua({cotaMaxima: 11});
    expect(estimarHorasAteInterditar(9, 1, r)).toBeCloseTo(2, 5);
    expect(estimarHorasAteInterditar(9, 0.5, r)).toBeCloseTo(4, 5);
  });
});

describe("UrgenciaService.ranquear", () => {
  const service = new UrgenciaService();

  it("classifica pelo nível ao vivo mesmo sem histórico de leituras", () => {
    // Regressão: `leituras_rio` pode estar vazia (sem job de captura
    // periódica) — o nível atual tem que vir de `nivelAtual` (telemetria ao
    // vivo), nunca só de `leituras`, senão o ranking trava em "desconhecida"
    // pra sempre.
    const ruaInterditada = rua({cotaMinima: 5, cotaMaxima: 8});
    const resultado = service.ranquear(
      [animal()], [ruaInterditada], 9, []
    );
    expect(resultado[0].classificacaoRua).toBe("interditada");
  });

  it("ordena animais interditados antes de animais livres", () => {
    const ruaInterditada = rua({
      id: "interditada", nome: "Rua Baixa",
      cotaMinima: 5, cotaMaxima: 8,
      latitude: -27.30, longitude: -49.70,
    });
    const ruaLivre = rua({
      id: "livre", nome: "Rua Alta",
      cotaMinima: 20, cotaMaxima: 30,
      latitude: -27.00, longitude: -49.30,
    });

    const animalEmRisco = animal({
      id: "em-risco",
      latitudeResgate: -27.30, longitudeResgate: -49.70,
    });
    const animalSeguro = animal({
      id: "seguro",
      latitudeResgate: -27.00, longitudeResgate: -49.30,
    });

    const resultado = service.ranquear(
      [animalSeguro, animalEmRisco],
      [ruaInterditada, ruaLivre],
      9,
      [leitura({nivel: 9})]
    );

    expect(resultado.map((r) => r.animal.id)).toEqual(["em-risco", "seguro"]);
    expect(resultado[0].classificacaoRua).toBe("interditada");
    expect(resultado[1].classificacaoRua).toBe("livre");
  });

  it("ignora animais que não estão com status resgatado", () => {
    const resultado = service.ranquear(
      [animal({status: "em_abrigo"})],
      [rua()],
      9,
      [leitura()]
    );
    expect(resultado).toHaveLength(0);
  });

  it("classifica como desconhecida quando o animal não tem coordenadas", () => {
    const resultado = service.ranquear(
      [animal({latitudeResgate: null, longitudeResgate: null})],
      [rua()],
      9,
      [leitura()]
    );
    expect(resultado[0].classificacaoRua).toBe("desconhecida");
    expect(resultado[0].pontuacaoUrgencia).toBe(0);
    expect(resultado[0].motivo).toContain("Sem localização");
  });

  it("dá pontuação maior para quem tem menos horas até a rua fechar", () => {
    const ruaProxima = rua({
      id: "a", nome: "Rua A", cotaMinima: 8, cotaMaxima: 11,
      latitude: -27.30, longitude: -49.70,
    });

    const animalUrgente = animal({
      id: "urgente", latitudeResgate: -27.30, longitudeResgate: -49.70,
    });

    const agora = Date.now();
    const umaHoraAtras = new Date(agora - 3600 * 1000).toISOString();
    const leituras = [
      leitura({nivel: 8, coletadoEm: umaHoraAtras}),
      leitura({nivel: 10, coletadoEm: new Date(agora).toISOString()}),
    ];

    const resultado = service.ranquear(
      [animalUrgente], [ruaProxima], 10, leituras
    );
    expect(resultado[0].horasAteInterditar).toBeCloseTo(0.5, 5);
    expect(resultado[0].pontuacaoUrgencia).toBeGreaterThan(PESO_RISCO_PARCIAL);
  });
});
