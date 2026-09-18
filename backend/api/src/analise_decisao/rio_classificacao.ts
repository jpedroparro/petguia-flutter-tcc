import type {ClassificacaoRio, RuaCota} from "../gestao_dados/types";
import {classificarRua, type ClassificacaoRua} from "./urgencia_service";

/** Limiares oficiais da Defesa Civil de Rio do Sul — estação Ponte Dom Tito Buss (rio Itajaí-Açu). */
export const COTA_ATENCAO = 4.5;
export const COTA_ALERTA = 5.5;
export const COTA_EMERGENCIA = 6.5;

/**
 * Classifica o nível atual do rio segundo os limiares oficiais da Defesa
 * Civil de Rio do Sul (Módulo de Análise e Tomada de Decisão).
 * @param {number} nivel Nível atual do rio, em metros.
 * @return {ClassificacaoRio} normal, atenção, alerta ou emergência.
 */
export function classificarNivelRio(nivel: number): ClassificacaoRio {
  if (nivel >= COTA_EMERGENCIA) return "emergencia";
  if (nivel >= COTA_ALERTA) return "alerta";
  if (nivel >= COTA_ATENCAO) return "atencao";
  return "normal";
}

export interface RuaComStatus extends RuaCota {
  status: ClassificacaoRua;
}

/**
 * Filtra, dentre as ruas com cota cadastrada, as que estão parcial ou
 * totalmente afetadas pelo nível atual do rio.
 * @param {RuaCota[]} ruas Ruas com cota cadastrada.
 * @param {number} nivelAtual Nível atual do rio, em metros.
 * @return {RuaComStatus[]} Ruas afetadas (nunca inclui as "livre").
 */
export function ruasAfetadas(ruas: RuaCota[], nivelAtual: number): RuaComStatus[] {
  return ruas
    .map((rua) => ({...rua, status: classificarRua(nivelAtual, rua)}))
    .filter((rua) => rua.status !== "livre");
}

export interface EstadoRio {
  nivelAtual: number | null;
  classificacao: ClassificacaoRio | null;
  ruasBloqueadas: RuaComStatus[];
}

/**
 * Monta o estado do rio (nível, classificação, ruas bloqueadas) a partir do
 * nível ao vivo e das ruas com cota — único ponto de composição, usado tanto
 * por `GET /rio` quanto pelo painel do operador, pra nunca duplicar (nem
 * divergir) a regra de "sem dado": quando `nivelAtual` é null (telemetria
 * fora do ar), a classificação também vem null — nunca "normal", que seria
 * mentir sobre o rio estar de fato baixo.
 * @param {number | null} nivelAtual Nível atual do rio, ao vivo (Asthon).
 * @param {RuaCota[]} ruas Ruas com cota cadastrada.
 * @return {EstadoRio} Estado do rio montado.
 */
export function montarEstadoRio(
  nivelAtual: number | null, ruas: RuaCota[]
): EstadoRio {
  return {
    nivelAtual,
    classificacao:
      nivelAtual == null ? null : classificarNivelRio(nivelAtual),
    ruasBloqueadas: nivelAtual == null ? [] : ruasAfetadas(ruas, nivelAtual),
  };
}
