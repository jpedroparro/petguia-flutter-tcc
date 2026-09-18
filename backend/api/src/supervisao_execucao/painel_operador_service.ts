import type {ProvedorTelemetriaRio} from "../comunicacao_externa/asthon_client";
import {
  montarEstadoRio,
  type EstadoRio,
} from "../analise_decisao/rio_classificacao";
import {
  UrgenciaService,
  type AlertaRankeado,
  type RiscoPonto,
} from "../analise_decisao/urgencia_service";
import type {GestaoDadosRepositorio} from "../gestao_dados/repositorio";
import type {ResgateService} from "../planejamento_execucao/resgate_service";

export interface PainelOperador {
  rio: EstadoRio;
  riscoOperador: RiscoPonto | null;
  alertasProximos: AlertaRankeado[];
}

/**
 * Módulo de Supervisão da Execução — painel único do operador de campo
 * (ver README.md da pasta para a citação do TCC). Junta, numa só
 * chamada, tudo que o operador precisa enquanto está em deslocamento:
 * nível do rio, ruas bloqueadas, se a posição atual dele está em risco, e
 * os alertas de resgate mais urgentes/próximos — a mesma lógica de
 * priorização do Módulo de Análise e Decisão, sem duplicar nada.
 */
export class PainelOperadorService {
  private asthonClient: ProvedorTelemetriaRio;
  private resgateService: ResgateService;
  private gestaoDadosRepositorio: GestaoDadosRepositorio;
  private urgenciaService: UrgenciaService;

  /**
   * @param {ProvedorTelemetriaRio} asthonClient Fonte do nível do rio.
   * @param {ResgateService} resgateService Alertas de resgate urgente.
   * @param {GestaoDadosRepositorio} gestaoDadosRepositorio Ruas/leituras.
   * @param {UrgenciaService} urgenciaService Ranking/avaliação de risco.
   */
  constructor(
    asthonClient: ProvedorTelemetriaRio,
    resgateService: ResgateService,
    gestaoDadosRepositorio: GestaoDadosRepositorio,
    urgenciaService: UrgenciaService = new UrgenciaService()
  ) {
    this.asthonClient = asthonClient;
    this.resgateService = resgateService;
    this.gestaoDadosRepositorio = gestaoDadosRepositorio;
    this.urgenciaService = urgenciaService;
  }

  /**
   * Monta o painel completo pro operador.
   * @param {{latitude: number, longitude: number} | null} origemOperador
   *   Posição atual do operador — se omitida, o painel vem sem avaliação
   *   de risco pessoal e sem ordenar alertas por proximidade.
   * @return {Promise<PainelOperador>} O painel montado.
   */
  async montar(
    origemOperador: {latitude: number; longitude: number} | null
  ): Promise<PainelOperador> {
    const [nivelAtual, ruas, leituras, alertas] = await Promise.all([
      this.asthonClient.buscarNivelAtual(),
      this.gestaoDadosRepositorio.listarRuasCota(),
      this.gestaoDadosRepositorio.listarLeiturasRio(),
      this.resgateService.listar(),
    ]);
    if (nivelAtual != null) {
      // Sem bloquear a resposta — mesma ideia da rota /rio: o próprio
      // tráfego do painel também alimenta o histórico de tendência.
      this.gestaoDadosRepositorio
        .registrarLeituraSeNecessaria(nivelAtual, "asthon")
        .catch((erro) =>
          console.error(
            "registrarLeituraSeNecessaria (painel-operador) falhou:", erro
          )
        );
    }

    const riscoOperador = origemOperador == null ? null : this
      .urgenciaService
      .avaliarRiscoDoPonto(
        origemOperador.latitude, origemOperador.longitude, nivelAtual,
        leituras, ruas
      );

    return {
      rio: montarEstadoRio(nivelAtual, ruas),
      riscoOperador,
      alertasProximos: this.urgenciaService.ranquearAlertas(
        alertas, ruas, nivelAtual, leituras, origemOperador
      ),
    };
  }
}
