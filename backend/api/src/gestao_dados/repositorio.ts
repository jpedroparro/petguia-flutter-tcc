import type {Firestore} from "firebase-admin/firestore";
import type {LeituraRio, RuaCota} from "./types";

/**
 * Módulo de Gestão de Dados e Conhecimento — leitura das coleções de
 * referência (cotas de rua, leituras do rio) usadas pelo Módulo de
 * Análise e Decisão (ver README.md da pasta para a citação do TCC).
 */
export class GestaoDadosRepositorio {
  private db: Firestore;

  /** Cache em memória de `ruas_cota` — ver [[listarRuasCota]]. */
  private ruasCotaCache: {dados: RuaCota[]; expiraEm: number} | null = null;

  /**
   * `ruas_cota` tem 545 documentos e é lida em toda chamada a `/rio`,
   * `/painel-operador` e `/animais/urgencia` — sem cache, um único login
   * (que carrega as 7 abas da equipe de uma vez) já dispara ~1.600
   * leituras do Firestore, suficiente pra estourar a cota gratuita diária
   * (Spark) em poucos usos. O dado é estático (seedado uma vez por
   * `scripts/seed_ruas_cota.mjs`, nunca escrito em runtime), então cachear
   * por alguns minutos é seguro — na pior hipótese, uma nova rua fica
   * "invisível" por até `RUAS_COTA_TTL_MS` depois de um reseed manual.
   */
  private static readonly RUAS_COTA_TTL_MS = 5 * 60 * 1000;

  /**
   * @param {Firestore} db Instância do Firestore (produção ou emulador).
   */
  constructor(db: Firestore) {
    this.db = db;
  }

  /**
   * Lista todas as ruas com cota de inundação cadastrada.
   * @return {Promise<RuaCota[]>} Lista de ruas.
   */
  async listarRuasCota(): Promise<RuaCota[]> {
    const agora = Date.now();
    if (this.ruasCotaCache != null && this.ruasCotaCache.expiraEm > agora) {
      return this.ruasCotaCache.dados;
    }
    const snap = await this.db.collection("ruas_cota").get();
    const dados = snap.docs.map((doc) => doc.data() as RuaCota);
    this.ruasCotaCache = {
      dados, expiraEm: agora + GestaoDadosRepositorio.RUAS_COTA_TTL_MS,
    };
    return dados;
  }

  /**
   * Lista as leituras mais recentes do nível do rio.
   * @param {number} limite Máximo de leituras a retornar.
   * @return {Promise<LeituraRio[]>} Leituras, da mais recente para a mais
   *   antiga.
   */
  async listarLeiturasRio(limite = 10): Promise<LeituraRio[]> {
    const snap = await this.db
      .collection("leituras_rio")
      .orderBy("coletadoEm", "desc")
      .limit(limite)
      .get();
    return snap.docs.map((doc) => doc.data() as LeituraRio);
  }

  /**
   * Registra uma leitura do nível do rio, mas só se a última registrada
   * tiver pelo menos `intervaloMinutos` de idade (ou não existir nenhuma
   * ainda) — evita gravar uma leitura nova a cada requisição só porque a
   * API não tem um job de captura periódica dedicado; o próprio tráfego
   * normal (abrir a aba Rio, o painel do operador) vai construindo o
   * histórico usado por `calcularTendencia`/`estimarHorasAteInterditar`.
   * @param {number} nivel Nível atual do rio.
   * @param {string} fonte Fonte da leitura (ex: "asthon").
   * @param {number} intervaloMinutos Intervalo mínimo entre leituras.
   * @return {Promise<void>} Nada.
   */
  async registrarLeituraSeNecessaria(
    nivel: number, fonte: string, intervaloMinutos = 15
  ): Promise<void> {
    const [ultima] = await this.listarLeiturasRio(1);
    if (ultima != null) {
      const minutosDesdeUltima =
        (Date.now() - new Date(ultima.coletadoEm).getTime()) / (1000 * 60);
      if (minutosDesdeUltima < intervaloMinutos) return;
    }

    const ref = this.db.collection("leituras_rio").doc();
    const leitura: LeituraRio = {
      id: ref.id,
      nivel,
      fonte,
      coletadoEm: new Date().toISOString(),
    };
    await ref.set(leitura);
  }
}
