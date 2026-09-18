import type {ProvedorTelemetriaRio} from "../comunicacao_externa/asthon_client";
import type {ValidadorEndereco} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {GestaoDadosRepositorio} from "../gestao_dados/repositorio";
import {ResgateService} from "../planejamento_execucao/resgate_service";
import {PainelOperadorService} from "./painel_operador_service";
import type {Firestore} from "firebase-admin/firestore";

let db: Firestore;
const VALIDADOR_OK: ValidadorEndereco = {existeEmRioDoSul: async () => true};

beforeAll(() => {
  db = iniciarBancoTeste();
});

afterEach(async () => {
  await limparBancoTeste(db);
});

/**
 * @param {number | null} nivel Nível a devolver como leitura atual.
 * @return {ProvedorTelemetriaRio} Provedor fake, nunca chama a API real.
 */
function buildProvedorRioFake(nivel: number | null): ProvedorTelemetriaRio {
  return {
    buscarNivelAtual: async () => nivel,
    buscarEstacoes: async () => [],
  };
}

/**
 * @param {number} nivel Nível do rio a semear como leitura mais recente.
 * @return {Promise<void>} Nada.
 */
async function semearRuaERio(nivel: number) {
  await db.collection("ruas_cota").doc("rua-1").set({
    id: "rua-1",
    nome: "Rua Perto",
    cotaMinima: 4,
    cotaMaxima: 6,
    latitude: -27.21,
    longitude: -49.64,
  });
  await db.collection("leituras_rio").doc("leitura-1").set({
    id: "leitura-1",
    nivel,
    fonte: "TESTE",
    coletadoEm: new Date().toISOString(),
  });
}

describe("PainelOperadorService", () => {
  it("monta painel com rio, ruas bloqueadas e alertas ranqueados", async () => {
    await semearRuaERio(6.5);
    const resgateService = new ResgateService(db, VALIDADOR_OK);
    await resgateService.solicitar({
      descricaoSituacao: "Cachorro preso em cima de uma árvore",
      rua: "Rua X",
      bairro: "Centro",
      nomeContato: "Maria",
      telefoneContato: "47999999999",
      latitude: -27.2101,
      longitude: -49.6401,
    });

    const service = new PainelOperadorService(
      buildProvedorRioFake(6.5),
      resgateService,
      new GestaoDadosRepositorio(db)
    );

    const painel = await service.montar(
      {latitude: -27.211, longitude: -49.641}
    );

    expect(painel.rio.nivelAtual).toBe(6.5);
    expect(painel.rio.classificacao).toBe("emergencia");
    expect(painel.rio.ruasBloqueadas).toHaveLength(1);
    expect(painel.riscoOperador?.classificacaoRua).toBe("interditada");
    expect(painel.alertasProximos).toHaveLength(1);
    expect(painel.alertasProximos[0].distanciaKm).not.toBeNull();
  });

  it(
    "classificação do rio vem null (não 'normal') quando não há leitura",
    async () => {
      await semearRuaERio(3);
      const resgateService = new ResgateService(db, VALIDADOR_OK);
      const service = new PainelOperadorService(
        buildProvedorRioFake(null),
        resgateService,
        new GestaoDadosRepositorio(db)
      );

      const painel = await service.montar(null);

      expect(painel.rio.nivelAtual).toBeNull();
      expect(painel.rio.classificacao).toBeNull();
    }
  );

  it("vem sem risco pessoal quando a posição não é informada", async () => {
    await semearRuaERio(3);
    const resgateService = new ResgateService(db, VALIDADOR_OK);
    const service = new PainelOperadorService(
      buildProvedorRioFake(3),
      resgateService,
      new GestaoDadosRepositorio(db)
    );

    const painel = await service.montar(null);

    expect(painel.riscoOperador).toBeNull();
    expect(painel.rio.classificacao).toBe("normal");
  });

  it("ignora alertas já concluídos no ranking", async () => {
    await semearRuaERio(3);
    const resgateService = new ResgateService(db, VALIDADOR_OK);
    const alerta = await resgateService.solicitar({
      descricaoSituacao: "Gato ilhado",
      rua: "Rua X",
      bairro: "Centro",
      nomeContato: "João",
      telefoneContato: "47999998888",
      latitude: -27.21,
      longitude: -49.64,
    });
    await resgateService.concluir(alerta.id);

    const service = new PainelOperadorService(
      buildProvedorRioFake(3),
      resgateService,
      new GestaoDadosRepositorio(db)
    );

    const painel = await service.montar(null);

    expect(painel.alertasProximos).toHaveLength(0);
  });
});
