import {GestaoDadosRepositorio} from "./repositorio";
import {iniciarBancoTeste, limparBancoTeste} from "./test_db";

describe("GestaoDadosRepositorio", () => {
  const db = iniciarBancoTeste();
  const repositorio = new GestaoDadosRepositorio(db);

  beforeEach(async () => {
    await limparBancoTeste(db);
  });

  describe("listarRuasCota", () => {
    // `listarRuasCota` cacheia o resultado em memória por instância (ver
    // comentário em `repositorio.ts`) — cada teste usa seu próprio
    // repositório pra não herdar o cache "sujo" de um teste anterior, já
    // que `ruas_cota` real nunca muda em runtime (só um reseed manual).
    it("lista as ruas cadastradas", async () => {
      await db.collection("ruas_cota").doc("rua-1").set({
        id: "rua-1", nome: "Rua Centro", cotaMinima: 8, cotaMaxima: 11,
        latitude: -27.2145, longitude: -49.6431,
      });

      const ruas = await new GestaoDadosRepositorio(db).listarRuasCota();
      expect(ruas).toHaveLength(1);
      expect(ruas[0].nome).toBe("Rua Centro");
    });

    it("retorna lista vazia sem ruas cadastradas", async () => {
      expect(await new GestaoDadosRepositorio(db).listarRuasCota())
        .toEqual([]);
    });

    it("reaproveita o cache em vez de reler o Firestore", async () => {
      const repo = new GestaoDadosRepositorio(db);
      await db.collection("ruas_cota").doc("rua-1").set({
        id: "rua-1", nome: "Rua Centro", cotaMinima: 8, cotaMaxima: 11,
        latitude: -27.2145, longitude: -49.6431,
      });
      expect(await repo.listarRuasCota()).toHaveLength(1);

      await db.collection("ruas_cota").doc("rua-1").delete();
      expect(await repo.listarRuasCota()).toHaveLength(1);
    });
  });

  describe("listarLeiturasRio", () => {
    it("lista as leituras da mais recente para a mais antiga", async () => {
      await db.collection("leituras_rio").doc("l1").set({
        id: "l1", nivel: 8, fonte: "asthon",
        coletadoEm: "2026-01-01T00:00:00.000Z",
      });
      await db.collection("leituras_rio").doc("l2").set({
        id: "l2", nivel: 10, fonte: "asthon",
        coletadoEm: "2026-01-01T02:00:00.000Z",
      });

      const leituras = await repositorio.listarLeiturasRio();
      expect(leituras.map((l) => l.id)).toEqual(["l2", "l1"]);
    });

    it("respeita o limite informado", async () => {
      for (let i = 0; i < 5; i++) {
        await db.collection("leituras_rio").doc(`l${i}`).set({
          id: `l${i}`, nivel: i, fonte: "asthon",
          coletadoEm: new Date(2026, 0, 1, i).toISOString(),
        });
      }

      expect(await repositorio.listarLeiturasRio(2)).toHaveLength(2);
    });
  });

  describe("registrarLeituraSeNecessaria", () => {
    it("grava quando não existe nenhuma leitura ainda", async () => {
      await repositorio.registrarLeituraSeNecessaria(7.5, "asthon");

      const leituras = await repositorio.listarLeiturasRio();
      expect(leituras).toHaveLength(1);
      expect(leituras[0].nivel).toBe(7.5);
    });

    it("não grava de novo se a última leitura é recente", async () => {
      await db.collection("leituras_rio").doc("recente").set({
        id: "recente", nivel: 5, fonte: "asthon",
        coletadoEm: new Date().toISOString(),
      });

      await repositorio.registrarLeituraSeNecessaria(8, "asthon", 15);

      const leituras = await repositorio.listarLeiturasRio();
      expect(leituras).toHaveLength(1);
      expect(leituras[0].nivel).toBe(5);
    });

    it("grava de novo se a última leitura já passou do intervalo", async () => {
      const vinteMinutosAtras = new Date(
        Date.now() - 20 * 60 * 1000
      ).toISOString();
      await db.collection("leituras_rio").doc("antiga").set({
        id: "antiga", nivel: 5, fonte: "asthon", coletadoEm: vinteMinutosAtras,
      });

      await repositorio.registrarLeituraSeNecessaria(8, "asthon", 15);

      const leituras = await repositorio.listarLeiturasRio();
      expect(leituras).toHaveLength(2);
    });
  });
});
