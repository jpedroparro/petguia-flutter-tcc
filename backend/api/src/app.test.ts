import request from "supertest";
import {criarApp} from "./app";
import type {
  EstacaoMonitorada,
  ProvedorTelemetriaRio,
} from "./comunicacao_externa/asthon_client";
import type {
  Coordenadas,
  GeocodificadorEndereco,
  ValidadorEndereco,
} from "./comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "./gestao_dados/test_db";
import {AnimalService} from "./planejamento_execucao/animal_service";

const VALIDADOR_OK: ValidadorEndereco = {existeEmRioDoSul: async () => true};

const ESTACAO_FAKE: EstacaoMonitorada = {
  id: "estacao-1",
  nome: "Ponte Dom Tito Buss",
  nivelM: 5.8,
  cotaObservacao: 4,
  cotaAtencao: 4.5,
  bandLabel: "Alerta",
  bandColor: "#f59e0b",
  chuva1h: 0,
  chuva24h: 12,
  ultimaLeituraEm: "2026-01-01T00:00:00.000Z",
};

/** Provedor de telemetria do rio fake — nunca chama a API Asthon real. */
function buildProvedorRioFake(nivel: number | null = 5.8): ProvedorTelemetriaRio {
  return {
    buscarNivelAtual: async () => nivel,
    buscarEstacoes: async () => [ESTACAO_FAKE],
  };
}

const COORDENADAS_FAKE: Coordenadas = {latitude: -27.2145, longitude: -49.6431};

const GEOCODIFICADOR_FAKE: GeocodificadorEndereco = {
  geocodificar: async (endereco) =>
    endereco.includes("inexistente") ? null : COORDENADAS_FAKE,
};

describe("app HTTP", () => {
  const db = iniciarBancoTeste();
  const app = criarApp(db, buildProvedorRioFake(), GEOCODIFICADOR_FAKE);

  beforeEach(async () => {
    await limparBancoTeste(db);
  });

  it("GET /health responde 200 sem autenticação", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({data: {ok: true}, error: null});
  });

  describe("rotas protegidas — sem token", () => {
    it("nega POST /abrigos sem token (403)", async () => {
      const res = await request(app).post("/abrigos").send({
        nome: "Abrigo Central",
        endereco: "Rua X",
        capacidadeTotal: 10,
      });
      expect(res.status).toBe(403);
      expect(res.body.data).toBeNull();
      expect(res.body.error).toBeTruthy();
    });

    it("nega POST /animais com token inválido (403)", async () => {
      const res = await request(app)
        .post("/animais")
        .set("Authorization", "Bearer token-invalido")
        .send({especie: "cachorro", porte: "medio"});
      expect(res.status).toBe(403);
    });

    it("nega GET /tutorias sem token (403)", async () => {
      const res = await request(app).get("/tutorias");
      expect(res.status).toBe(403);
    });

    it("nega GET /reunificacoes sem token (403)", async () => {
      const res = await request(app).get("/reunificacoes");
      expect(res.status).toBe(403);
    });

    it("nega GET /resgates sem token (403)", async () => {
      const res = await request(app).get("/resgates");
      expect(res.status).toBe(403);
    });

    it("nega PUT /abrigos/:id sem token (403)", async () => {
      const res = await request(app)
        .put("/abrigos/id-qualquer")
        .send({nome: "X"});
      expect(res.status).toBe(403);
    });

    it("nega GET /painel-operador sem token (403)", async () => {
      const res = await request(app).get("/painel-operador");
      expect(res.status).toBe(403);
    });
  });

  describe("rotas públicas de negócio", () => {
    it("POST /reunificacoes cria solicitação p/ animal existente", async () => {
      const animal = await new AnimalService(db, VALIDADOR_OK).cadastrar({
        especie: "gato",
        raca: "SRD",
        porte: "pequeno",
        estadoSaude: "estável",
        rua: "Rua das Flores",
        bairro: "Centro",
        registradoPor: "uid-equipe",
      });

      const res = await request(app).post("/reunificacoes").send({
        animalId: animal.id,
        nomeTutor: "Maria",
        telefoneTutor: "47999990000",
      });

      expect(res.status).toBe(201);
      expect(res.body.error).toBeNull();
      expect(res.body.data.animalId).toBe(animal.id);
      expect(res.body.data.status).toBe("pendente");
    });

    it("POST /reunificacoes com animal inexistente responde 404", async () => {
      const res = await request(app).post("/reunificacoes").send({
        animalId: "id-que-nao-existe",
        nomeTutor: "Maria",
        telefoneTutor: "47999990000",
      });
      expect(res.status).toBe(404);
      expect(res.body.data).toBeNull();
    });

    it("POST /tutorias com CPF inválido responde 400", async () => {
      const animal = await new AnimalService(db, VALIDADOR_OK).cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "grande",
        estadoSaude: "estável",
        rua: "Av. Central",
        bairro: "Centro",
        registradoPor: "uid-equipe",
      });

      const res = await request(app).post("/tutorias").send({
        animalId: animal.id,
        nomeTutor: "João",
        dataNascimentoTutor: "1994-06-15",
        cpfTutor: "111.111.111-11",
        telefoneTutor: "47988887777",
      });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe("CPF inválido");
    });

    it("POST /resgates com telefone inválido responde 400", async () => {
      const res = await request(app).post("/resgates").send({
        descricaoSituacao: "Cachorro preso em cima de uma árvore",
        rua: "Rua X",
        bairro: "Centro",
        nomeContato: "Maria",
        telefoneContato: "123",
      });

      expect(res.status).toBe(400);
      expect(res.body.data).toBeNull();
    });
  });

  describe("GET /rio", () => {
    it("responde com nível, classificação e ruas afetadas, sem exigir login", async () => {
      await db.collection("ruas_cota").doc("rua-afetada").set({
        id: "rua-afetada", nome: "Rua Baixa", cotaMinima: 4, cotaMaxima: 6,
        latitude: null, longitude: null,
      });
      await db.collection("ruas_cota").doc("rua-livre").set({
        id: "rua-livre", nome: "Rua Alta", cotaMinima: 10, cotaMaxima: 12,
        latitude: null, longitude: null,
      });

      const res = await request(app).get("/rio");

      expect(res.status).toBe(200);
      expect(res.body.error).toBeNull();
      expect(res.body.data.nivelAtual).toBe(5.8);
      expect(res.body.data.classificacao).toBe("alerta");
      expect(res.body.data.ruasBloqueadas.map((r: {id: string}) => r.id)).toEqual([
        "rua-afetada",
      ]);
    });

    it(
      "responde com nível, classificação e ruas nulas/vazias quando a " +
      "Asthon está indisponível — nunca 'normal' sem dado real",
      async () => {
        // Regressão: `classificarNivelRio(nivelAtual ?? 0)` transformava
        // "sem dado" em "normal" (0 é o nível mais baixo possível).
        const appIndisponivel = criarApp(db, buildProvedorRioFake(null));
        const res = await request(appIndisponivel).get("/rio");

        expect(res.status).toBe(200);
        expect(res.body.data.nivelAtual).toBeNull();
        expect(res.body.data.classificacao).toBeNull();
        expect(res.body.data.ruasBloqueadas).toEqual([]);
      }
    );
  });

  describe("GET /rio/estacoes", () => {
    it("responde com as estações monitoradas, sem exigir login", async () => {
      const res = await request(app).get("/rio/estacoes");

      expect(res.status).toBe(200);
      expect(res.body.error).toBeNull();
      expect(res.body.data).toEqual([ESTACAO_FAKE]);
    });
  });

  describe("GET /geo/geocodificar", () => {
    it("responde com coordenadas, sem exigir login", async () => {
      const res = await request(app).get("/geo/geocodificar?endereco=Rua Central");

      expect(res.status).toBe(200);
      expect(res.body.error).toBeNull();
      expect(res.body.data).toEqual(COORDENADAS_FAKE);
    });

    it("responde com dado nulo quando o endereço não é encontrado", async () => {
      const res = await request(app).get("/geo/geocodificar?endereco=Rua inexistente");

      expect(res.status).toBe(200);
      expect(res.body.data).toBeNull();
    });

    it("rejeita requisição sem endereço", async () => {
      const res = await request(app).get("/geo/geocodificar");

      expect(res.status).toBe(400);
      expect(res.body.data).toBeNull();
    });
  });

  describe("GET /geo/reverso", () => {
    it("não exige login (usada pelo portal público, sem token)", async () => {
      // Só confere que a rota não bloqueia por falta de auth — não chama a
      // rede real do Nominatim (nominatimClient não é injetável aqui), por
      // isso testa com parâmetro inválido em vez de coordenada real.
      const res = await request(app).get("/geo/reverso");

      expect(res.status).toBe(400);
      expect(res.body.error).toBe("Informe lat e lon válidos");
    });
  });
});
