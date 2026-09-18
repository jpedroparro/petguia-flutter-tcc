import type {
  Animal,
  LeituraRio,
  RuaCota,
  SolicitacaoResgate,
} from "../gestao_dados/types";

export type ClassificacaoRua =
  | "livre"
  | "parcial"
  | "interditada"
  | "desconhecida";

export interface AnimalRankeado {
  animal: Animal;
  ruaMaisProxima: RuaCota | null;
  classificacaoRua: ClassificacaoRua;
  horasAteInterditar: number | null;
  pontuacaoUrgencia: number;
  motivo: string;
}

/**
 * Mesma ideia do ranking de animais, pros alertas de resgate urgente
 * (`SolicitacaoResgate`) — animal que ainda nem foi capturado. Além do
 * risco da rua, carrega a distância até quem está consultando (o
 * operador em campo), usada como critério de desempate.
 */
export interface AlertaRankeado {
  alerta: SolicitacaoResgate;
  ruaMaisProxima: RuaCota | null;
  classificacaoRua: ClassificacaoRua;
  horasAteInterditar: number | null;
  distanciaKm: number | null;
  pontuacaoUrgencia: number;
  motivo: string;
}

/** Avaliação de risco de um ponto qualquer — usada tanto pra ranquear
 * animais/alertas quanto pra avisar o próprio operador se ele estiver
 * numa área que pode alagar. */
export interface RiscoPonto {
  ruaMaisProxima: RuaCota | null;
  classificacaoRua: ClassificacaoRua;
  horasAteInterditar: number | null;
  motivo: string;
}

const PESO_RISCO: Record<ClassificacaoRua, number> = {
  interditada: 100,
  parcial: 50,
  livre: 10,
  desconhecida: 0,
};

/**
 * Distância aproximada entre duas coordenadas (fórmula de haversine).
 * @param {number} lat1 Latitude do primeiro ponto.
 * @param {number} lon1 Longitude do primeiro ponto.
 * @param {number} lat2 Latitude do segundo ponto.
 * @param {number} lon2 Longitude do segundo ponto.
 * @return {number} Distância em quilômetros.
 */
export function distanciaKm(
  lat1: number, lon1: number, lat2: number, lon2: number
): number {
  const raioTerraKm = 6371;
  const radLat1 = (lat1 * Math.PI) / 180;
  const radLat2 = (lat2 * Math.PI) / 180;
  const deltaLat = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(radLat1) * Math.cos(radLat2) * Math.sin(deltaLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return raioTerraKm * c;
}

/**
 * Encontra a rua com cota cadastrada mais próxima de um ponto qualquer.
 * Núcleo compartilhado por `encontrarRuaMaisProxima` (animal),
 * `UrgenciaService.ranquearAlertas` e `UrgenciaService.avaliarRiscoDoPonto`.
 * @param {number} latitude Latitude do ponto.
 * @param {number} longitude Longitude do ponto.
 * @param {RuaCota[]} ruas Ruas com cota cadastrada.
 * @return {RuaCota | null} A rua mais próxima, ou null se nenhuma rua tem
 *   coordenada cadastrada.
 */
export function encontrarRuaMaisProximaDoPonto(
  latitude: number, longitude: number, ruas: RuaCota[]
): RuaCota | null {
  const ruasComCoordenada = ruas.filter(
    (r) => r.latitude != null && r.longitude != null
  );
  if (ruasComCoordenada.length === 0) return null;

  return ruasComCoordenada.reduce((maisProxima, atual) => {
    const distAtual = distanciaKm(
      latitude, longitude, atual.latitude!, atual.longitude!
    );
    const distMaisProxima = distanciaKm(
      latitude, longitude, maisProxima.latitude!, maisProxima.longitude!
    );
    return distAtual < distMaisProxima ? atual : maisProxima;
  });
}

/**
 * Encontra a rua com cota cadastrada mais próxima do ponto de resgate do
 * animal. Retorna null se o animal não tem coordenadas ou nenhuma rua tem
 * coordenadas cadastradas — não há como estimar nesse caso.
 * @param {Animal} animal Animal resgatado.
 * @param {RuaCota[]} ruas Ruas com cota cadastrada.
 * @return {RuaCota | null} A rua mais próxima, ou null.
 */
export function encontrarRuaMaisProxima(
  animal: Animal, ruas: RuaCota[]
): RuaCota | null {
  if (animal.latitudeResgate == null || animal.longitudeResgate == null) {
    return null;
  }
  return encontrarRuaMaisProximaDoPonto(
    animal.latitudeResgate, animal.longitudeResgate, ruas
  );
}

/**
 * Classifica a transitabilidade de uma rua a partir do nível atual do rio
 * e da cota mínima/máxima cadastrada para ela.
 * @param {number} nivelAtual Nível atual do rio (mesma unidade da cota).
 * @param {RuaCota} rua Rua com cota cadastrada.
 * @return {ClassificacaoRua} livre, parcial ou interditada.
 */
export function classificarRua(
  nivelAtual: number, rua: RuaCota
): ClassificacaoRua {
  if (nivelAtual < rua.cotaMinima) return "livre";
  if (rua.cotaMaxima != null && nivelAtual >= rua.cotaMaxima) {
    return "interditada";
  }
  return "parcial";
}

/**
 * Calcula a tendência de subida do rio (cm por hora) a partir das duas
 * leituras mais recentes. Retorna 0 se houver menos de duas leituras.
 * @param {LeituraRio[]} leituras Leituras do nível do rio, em qualquer ordem.
 * @return {number} Variação por hora (positiva = subindo).
 */
export function calcularTendencia(leituras: LeituraRio[]): number {
  if (leituras.length < 2) return 0;

  const ordenadas = [...leituras].sort(
    (a, b) =>
      new Date(a.coletadoEm).getTime() - new Date(b.coletadoEm).getTime()
  );
  const anterior = ordenadas[ordenadas.length - 2];
  const recente = ordenadas[ordenadas.length - 1];

  const horas =
    (new Date(recente.coletadoEm).getTime() -
      new Date(anterior.coletadoEm).getTime()) /
    (1000 * 60 * 60);
  if (horas <= 0) return 0;

  return (recente.nivel - anterior.nivel) / horas;
}

/**
 * Estima quantas horas faltam até a rua ficar intransitável (nível atingir
 * a cota máxima), dada a tendência atual. Retorna null quando não há como
 * estimar: rua sem cota máxima definida, ou rio estável/baixando.
 * @param {number} nivelAtual Nível atual do rio.
 * @param {number} tendenciaMetrosPorHora Variação por hora (mesma unidade
 *   de `nivelAtual`/cota — metros, não centímetros; ver `calcularTendencia`).
 * @param {RuaCota} rua Rua com cota cadastrada.
 * @return {number | null} Horas estimadas, ou null se não aplicável.
 */
export function estimarHorasAteInterditar(
  nivelAtual: number, tendenciaMetrosPorHora: number, rua: RuaCota
): number | null {
  if (rua.cotaMaxima == null) return null;
  if (nivelAtual >= rua.cotaMaxima) return 0;
  if (tendenciaMetrosPorHora <= 0) return null;

  return (rua.cotaMaxima - nivelAtual) / tendenciaMetrosPorHora;
}

/**
 * Módulo de Análise e Tomada de Decisão — ranking de urgência de resgate
 * (ver README.md da pasta para a citação do TCC). Combina o risco da rua
 * onde o animal/alerta está com o tempo estimado até ela ficar
 * intransitável, para que a equipe atenda primeiro quem está em maior
 * risco, não quem foi cadastrado primeiro. A mesma avaliação de risco
 * também serve pra avisar o próprio operador se a posição dele estiver
 * numa área que pode alagar em breve.
 */
export class UrgenciaService {
  /**
   * Bônus de urgência por proximidade temporal da interdição — quanto
   * menos horas faltam, maior o bônus (assíntota em 50 quando faltam ~0h).
   * Extraído porque `ranquear` e `ranquearAlertas` calculavam exatamente a
   * mesma fórmula em paralelo.
   * @param {number | null} horasAteInterditar Horas estimadas até a rua
   *   ficar intransitável, ou null se não aplicável.
   * @return {number} Bônus de pontuação (0 quando não aplicável).
   */
  private calcularBonusTempo(horasAteInterditar: number | null): number {
    return horasAteInterditar == null ?
      0 :
      50 / (1 + Math.max(0, horasAteInterditar));
  }

  /**
   * Avalia o risco de um ponto qualquer (rua mais próxima, classificação
   * e horas estimadas até intransitável) — núcleo compartilhado por todo
   * o resto da classe. O nível atual vem sempre da leitura ao vivo (Asthon),
   * nunca de `leituras` — essa coleção serve só pra calcular a tendência de
   * subida, que depende de histórico.
   * @param {number} latitude Latitude do ponto.
   * @param {number} longitude Longitude do ponto.
   * @param {number | null} nivelAtual Nível atual do rio, direto da
   *   telemetria ao vivo (não de `leituras`).
   * @param {LeituraRio[]} leituras Histórico de leituras — usado só pra
   *   calcular a tendência de subida (`calcularTendencia`).
   * @param {RuaCota[]} ruas Ruas com cota cadastrada.
   * @return {RiscoPonto} Avaliação de risco do ponto.
   */
  avaliarRiscoDoPonto(
    latitude: number, longitude: number, nivelAtual: number | null,
    leituras: LeituraRio[], ruas: RuaCota[]
  ): RiscoPonto {
    const tendencia = calcularTendencia(leituras);
    const rua = encontrarRuaMaisProximaDoPonto(latitude, longitude, ruas);
    if (rua == null || nivelAtual == null) {
      return {
        ruaMaisProxima: null,
        classificacaoRua: "desconhecida",
        horasAteInterditar: null,
        motivo:
          "Sem rua cadastrada próxima ou sem leitura do rio — risco não " +
          "calculado.",
      };
    }

    const classificacaoRua = classificarRua(nivelAtual, rua);
    const horasAteInterditar = estimarHorasAteInterditar(
      nivelAtual, tendencia, rua
    );
    return {
      ruaMaisProxima: rua,
      classificacaoRua,
      horasAteInterditar,
      motivo: `Rua "${rua.nome}" (${classificacaoRua})` +
        (horasAteInterditar == null ?
          "." :
          `, intransitável em ~${horasAteInterditar.toFixed(1)}h.`) +
        (rua.cotaMaximaEstimada ? " (cota máxima estimada, não oficial)" : ""),
    };
  }

  /**
   * Ordena animais com status "resgatado" por urgência de atendimento,
   * do mais urgente para o menos urgente.
   * @param {Animal[]} animais Animais (qualquer status; só "resgatado"
   *   entra no ranking).
   * @param {RuaCota[]} ruas Ruas com cota cadastrada.
   * @param {number | null} nivelAtual Nível atual do rio, ao vivo.
   * @param {LeituraRio[]} leituras Histórico de leituras — só pra tendência.
   * @return {AnimalRankeado[]} Animais resgatados, ordenados por urgência.
   */
  ranquear(
    animais: Animal[], ruas: RuaCota[], nivelAtual: number | null,
    leituras: LeituraRio[]
  ): AnimalRankeado[] {
    const ranking = animais
      .filter((a) => a.status === "resgatado")
      .map((animal): AnimalRankeado => {
        if (animal.latitudeResgate == null || animal.longitudeResgate == null) {
          return {
            animal,
            ruaMaisProxima: null,
            classificacaoRua: "desconhecida",
            horasAteInterditar: null,
            pontuacaoUrgencia: PESO_RISCO.desconhecida,
            motivo:
              "Sem localização ou sem leitura do rio — risco não calculado.",
          };
        }

        const risco = this.avaliarRiscoDoPonto(
          animal.latitudeResgate, animal.longitudeResgate, nivelAtual,
          leituras, ruas
        );
        const bonusTempo = this.calcularBonusTempo(risco.horasAteInterditar);

        return {
          animal,
          ruaMaisProxima: risco.ruaMaisProxima,
          classificacaoRua: risco.classificacaoRua,
          horasAteInterditar: risco.horasAteInterditar,
          pontuacaoUrgencia: PESO_RISCO[risco.classificacaoRua] + bonusTempo,
          motivo: risco.motivo,
        };
      });

    return ranking.sort((a, b) => b.pontuacaoUrgencia - a.pontuacaoUrgencia);
  }

  /**
   * Ordena alertas de resgate urgente (`SolicitacaoResgate`, animal ainda
   * não capturado) por urgência — mesmo critério de risco de `ranquear`,
   * com a distância até o operador como desempate.
   * @param {SolicitacaoResgate[]} alertas Alertas (qualquer status; só
   *   "pendente" e "em_atendimento" entram no ranking).
   * @param {RuaCota[]} ruas Ruas com cota cadastrada.
   * @param {number | null} nivelAtual Nível atual do rio, ao vivo.
   * @param {LeituraRio[]} leituras Histórico de leituras — só pra tendência.
   * @param {{latitude: number, longitude: number} | null} origemOperador
   *   Posição atual do operador, pra calcular distância — se omitida, o
   *   ranking usa só a urgência, sem desempate por proximidade.
   * @return {AlertaRankeado[]} Alertas ativos, ordenados por urgência.
   */
  ranquearAlertas(
    alertas: SolicitacaoResgate[], ruas: RuaCota[], nivelAtual: number | null,
    leituras: LeituraRio[],
    origemOperador: {latitude: number; longitude: number} | null = null
  ): AlertaRankeado[] {
    const ranking = alertas
      .filter((a) => a.status === "pendente" || a.status === "em_atendimento")
      .map((alerta): AlertaRankeado => {
        const dist = (alerta.latitude == null || alerta.longitude == null ||
            origemOperador == null) ?
          null :
          distanciaKm(
            origemOperador.latitude, origemOperador.longitude,
            alerta.latitude, alerta.longitude
          );

        if (alerta.latitude == null || alerta.longitude == null) {
          return {
            alerta,
            ruaMaisProxima: null,
            classificacaoRua: "desconhecida",
            horasAteInterditar: null,
            distanciaKm: dist,
            pontuacaoUrgencia: PESO_RISCO.desconhecida,
            motivo: "Sem localização registrada — risco não calculado.",
          };
        }

        const risco = this.avaliarRiscoDoPonto(
          alerta.latitude, alerta.longitude, nivelAtual, leituras, ruas
        );
        const bonusTempo = this.calcularBonusTempo(risco.horasAteInterditar);

        return {
          alerta,
          ruaMaisProxima: risco.ruaMaisProxima,
          classificacaoRua: risco.classificacaoRua,
          horasAteInterditar: risco.horasAteInterditar,
          distanciaKm: dist,
          pontuacaoUrgencia: PESO_RISCO[risco.classificacaoRua] + bonusTempo,
          motivo: risco.motivo,
        };
      });

    return ranking.sort((a, b) => {
      if (b.pontuacaoUrgencia !== a.pontuacaoUrgencia) {
        return b.pontuacaoUrgencia - a.pontuacaoUrgencia;
      }
      if (a.distanciaKm == null) return 1;
      if (b.distanciaKm == null) return -1;
      return a.distanciaKm - b.distanciaKm;
    });
  }
}
