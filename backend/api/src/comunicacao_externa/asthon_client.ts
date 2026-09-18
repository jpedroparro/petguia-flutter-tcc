const ASTHON_BASE_URL = "https://public.asthon.com.br/public";
const CITY_ID_RIO_DO_SUL = 4214805;
const TIMEOUT_MS = 6000;

/** Estação "Ponte Dom Tito Buss" — referência oficial da Defesa Civil de Rio do Sul para a cota do rio Itajaí-Açu. */
const STATION_ID_PONTE_DOM_TITO_BUSS = "f6360951-219f-4859-935f-b2e2d13962f1";

/** As 3 estações exibidas publicamente pela Defesa Civil de Rio do Sul. */
const ESTACOES_MONITORADAS = [
  "f6360951-219f-4859-935f-b2e2d13962f1", // Ponte Dom Tito Buss
  "30475400-b7ba-4551-9646-19df0c3bfa38", // Ponte Ricardo Kanitz - Rio Itajaí do Sul
  "020084eb-1467-4bf6-8831-e4ed9baca7b5", // Ponte BR-470 – Rio Itajaí do Oeste
];

export interface EstacaoMonitorada {
  id: string;
  nome: string;
  nivelM: number | null;
  cotaObservacao: number | null;
  cotaAtencao: number | null;
  bandLabel: string;
  bandColor: string;
  chuva1h: number | null;
  chuva24h: number | null;
  ultimaLeituraEm: string | null;
}

/** Porta pra buscar a telemetria do rio — implementada pelo AsthonClient. */
export interface ProvedorTelemetriaRio {
  buscarNivelAtual(): Promise<number | null>;
  buscarEstacoes(): Promise<EstacaoMonitorada[]>;
}

interface AsthonStationLive {
  station_id: string;
  level_m: number | null;
}

interface AsthonPanelStation {
  station_id: string;
  name: string;
  level_m: number | null;
  observation_level: number | null;
  attention_level: number | null;
  band_label: string;
  band_color: string;
  rainfall_1h: number | null;
  rainfall_24h: number | null;
  last_reading_at: string | null;
}

interface AsthonPanelResponse {
  stations: AsthonPanelStation[];
}

/**
 * Cliente da API pública Asthon (Defesa Civil de Rio do Sul) — Módulo de
 * Comunicação com Sistemas Externos (TCC, seção 2.3.1). Nunca lança: uma
 * falha na API externa não pode travar a página do rio, só resulta em
 * dados nulos/vazios, que a UI trata como "indisponível".
 */
export class AsthonClient implements ProvedorTelemetriaRio {
  private base: string;

  /**
   * @param {string} base URL base da API Asthon.
   */
  constructor(base = ASTHON_BASE_URL) {
    this.base = base;
  }

  /**
   * Nível atual do rio na estação de referência (Ponte Dom Tito Buss).
   * @return {Promise<number | null>} Nível em metros, ou null se
   *   indisponível.
   */
  async buscarNivelAtual(): Promise<number | null> {
    try {
      const resposta = await fetch(
        `${this.base}/stations/live?city_id=${CITY_ID_RIO_DO_SUL}&_v=2`,
        {signal: AbortSignal.timeout(TIMEOUT_MS)}
      );
      if (!resposta.ok) return null;
      const estacoes = await resposta.json() as AsthonStationLive[];
      const estacao = estacoes.find(
        (e) => e.station_id === STATION_ID_PONTE_DOM_TITO_BUSS
      );
      return estacao?.level_m ?? null;
    } catch {
      return null;
    }
  }

  /**
   * As 3 estações monitoradas publicamente pela Defesa Civil de Rio do Sul.
   * @return {Promise<EstacaoMonitorada[]>} Estações — "Sem dados" pra
   *   qualquer uma que a API não retornar.
   */
  async buscarEstacoes(): Promise<EstacaoMonitorada[]> {
    try {
      const resposta = await fetch(
        `${this.base}/panel?city_id=${CITY_ID_RIO_DO_SUL}&include_geometry=false&_v=2`,
        {signal: AbortSignal.timeout(TIMEOUT_MS)}
      );
      if (!resposta.ok) return this.estacoesIndisponiveis();
      const dados = await resposta.json() as AsthonPanelResponse;

      return ESTACOES_MONITORADAS.map((id) => {
        const estacao = dados.stations.find((s) => s.station_id === id);
        if (!estacao) return this.estacaoIndisponivel(id);
        return {
          id: estacao.station_id,
          nome: estacao.name,
          nivelM: estacao.level_m,
          cotaObservacao: estacao.observation_level,
          cotaAtencao: estacao.attention_level,
          bandLabel: estacao.band_label,
          bandColor: estacao.band_color,
          chuva1h: estacao.rainfall_1h,
          chuva24h: estacao.rainfall_24h,
          ultimaLeituraEm: estacao.last_reading_at,
        };
      });
    } catch {
      return this.estacoesIndisponiveis();
    }
  }

  private estacoesIndisponiveis(): EstacaoMonitorada[] {
    return ESTACOES_MONITORADAS.map((id) => this.estacaoIndisponivel(id));
  }

  private estacaoIndisponivel(id: string): EstacaoMonitorada {
    return {
      id,
      nome: "Estação indisponível",
      nivelM: null,
      cotaObservacao: null,
      cotaAtencao: null,
      bandLabel: "Sem dados",
      bandColor: "#9ca3af",
      chuva1h: null,
      chuva24h: null,
      ultimaLeituraEm: null,
    };
  }
}
