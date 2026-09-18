import {ErroDominio} from "../suporte_geral/erro_dominio";

const USER_AGENT = "PetGuiaEnchentesTCC/1.0 (github.com/jpedroparro)";
const TIMEOUT_MS = 6000;
const CIDADE_ALVO = "Rio do Sul";
const ESTADO_ALVO = "Santa Catarina";

export interface EnderecoGeocodificado {
  rua: string | null;
  bairro: string | null;
  cep: string | null;
}

/** Porta para validação de endereço — implementada pelo NominatimClient. */
export interface ValidadorEndereco {
  existeEmRioDoSul(rua: string, bairro?: string | null): Promise<boolean>;
}

export interface Coordenadas {
  latitude: number;
  longitude: number;
}

/**
 * Porta para geocodificação direta (endereço -> coordenadas) —
 * implementada pelo NominatimClient. Usada pela busca por região do
 * portal: o tutor digita CEP/rua, viramos coordenadas pra filtrar
 * animais num raio.
 */
export interface GeocodificadorEndereco {
  geocodificar(endereco: string): Promise<Coordenadas | null>;
}

/**
 * Erro lançado quando um endereço (rua/bairro) não é encontrado em Rio do
 * Sul — usado tanto pelo cadastro de animal quanto de abrigo, já que os
 * dois validam contra o mesmo `ValidadorEndereco`.
 */
export class EnderecoForaDeRioDoSulError extends ErroDominio {
  /** Constrói o erro de endereço fora de Rio do Sul. */
  constructor() {
    super(
      "Não encontramos essa rua/bairro em Rio do Sul. Confira o endereço.",
      400
    );
    this.name = "EnderecoForaDeRioDoSulError";
  }
}

interface RespostaNominatim {
  address?: Record<string, string>;
}

/**
 * Remove acentos e normaliza caixa para comparação tolerante de texto.
 * @param {string} texto Texto a normalizar.
 * @return {string} Texto normalizado.
 */
function normalizar(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}

/**
 * Cliente do Nominatim (OpenStreetMap) — Módulo de Comunicação com Sistemas
 * Externos (TCC, seção 2.3.1). Só busca e normaliza dados geográficos;
 * nenhuma regra de negócio vive aqui.
 */
export class NominatimClient implements ValidadorEndereco, GeocodificadorEndereco {
  private base: string;

  /**
   * @param {string} base URL base do serviço Nominatim.
   */
  constructor(base = "https://nominatim.openstreetmap.org") {
    this.base = base;
  }

  /**
   * Geocodificação reversa: lat/lon -> rua, bairro e CEP aproximados.
   * @param {number} latitude Latitude.
   * @param {number} longitude Longitude.
   * @return {Promise<EnderecoGeocodificado | null>} Endereço encontrado, ou
   *   null se o serviço não respondeu ou não tem dados para o ponto.
   */
  async reverso(
    latitude: number, longitude: number
  ): Promise<EnderecoGeocodificado | null> {
    const url = `${this.base}/reverse?format=jsonv2&lat=${latitude}` +
      `&lon=${longitude}&addressdetails=1`;
    try {
      const resposta = await fetch(url, {
        headers: {"User-Agent": USER_AGENT},
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!resposta.ok) return null;
      const corpo = await resposta.json() as RespostaNominatim;
      if (!corpo.address) return null;
      return {
        rua: corpo.address.road ?? null,
        bairro: corpo.address.suburb ?? corpo.address.neighbourhood ??
          corpo.address.borough ?? null,
        cep: corpo.address.postcode ?? null,
      };
    } catch {
      return null;
    }
  }

  /**
   * Confirma se a rua (e, se informado, o bairro) existe em Rio do Sul/SC.
   * Um resgate de animal em andamento não pode travar por uma API de
   * terceiros fora do ar — por isso só bloqueia quando o Nominatim responde
   * com confiança que a rua não existe na cidade; qualquer falha de rede ou
   * indisponibilidade libera o cadastro.
   * @param {string} rua Nome da rua informada.
   * @param {string | null} bairro Bairro informado, se houver.
   * @return {Promise<boolean>} Verdadeiro se a rua existe (ou não foi
   *   possível confirmar o contrário).
   */
  async existeEmRioDoSul(rua: string, bairro?: string | null): Promise<boolean> {
    const params = new URLSearchParams({
      format: "jsonv2",
      street: rua,
      city: CIDADE_ALVO,
      state: ESTADO_ALVO,
      country: "Brazil",
      addressdetails: "1",
      limit: "5",
    });
    try {
      const resposta = await fetch(`${this.base}/search?${params.toString()}`, {
        headers: {"User-Agent": USER_AGENT},
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!resposta.ok) {
        // Fail-open deliberado (ver docstring) — logado pra dar visibilidade
        // se isso passar a acontecer com frequência (ex: rate limit sob uso
        // concorrente real), já que o efeito é desligar esta validação.
        console.warn(
          `Nominatim respondeu ${resposta.status} em existeEmRioDoSul — ` +
          "validação de endereço liberada por fail-open."
        );
        return true;
      }
      const resultados = await resposta.json() as RespostaNominatim[];
      if (resultados.length === 0) return false;
      if (!bairro) return true;

      const alvo = normalizar(bairro);
      return resultados.some((r) => {
        const b = r.address?.suburb ?? r.address?.neighbourhood ??
          r.address?.borough ?? "";
        const bNormalizado = normalizar(b);
        return bNormalizado.length > 0 &&
          (bNormalizado.includes(alvo) || alvo.includes(bNormalizado));
      });
    } catch (erro) {
      console.warn(
        "Nominatim inacessível em existeEmRioDoSul — validação de " +
        "endereço liberada por fail-open.", erro
      );
      return true;
    }
  }

  /**
   * Geocodificação direta: endereço (rua, CEP, etc.) -> coordenadas, restrito
   * a Rio do Sul/SC. Usada pela busca por região do portal público.
   * @param {string} endereco Rua, CEP ou endereço livre digitado pelo tutor.
   * @return {Promise<Coordenadas | null>} Coordenadas do primeiro resultado,
   *   ou null se não encontrado ou o serviço estiver indisponível.
   */
  async geocodificar(endereco: string): Promise<Coordenadas | null> {
    const params = new URLSearchParams({
      format: "jsonv2",
      q: `${endereco}, ${CIDADE_ALVO}, ${ESTADO_ALVO}, Brazil`,
      limit: "1",
    });
    try {
      const resposta = await fetch(`${this.base}/search?${params.toString()}`, {
        headers: {"User-Agent": USER_AGENT},
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!resposta.ok) return null;
      const resultados = await resposta.json() as Array<{lat: string; lon: string}>;
      if (resultados.length === 0) return null;
      return {
        latitude: Number.parseFloat(resultados[0].lat),
        longitude: Number.parseFloat(resultados[0].lon),
      };
    } catch {
      return null;
    }
  }
}
