import type {Firestore} from "firebase-admin/firestore";
import {
  EnderecoForaDeRioDoSulError,
  NominatimClient,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import type {SolicitacaoResgate, StatusResgate} from "../gestao_dados/types";
import {ErroDominio} from "../suporte_geral/erro_dominio";
import {validarTelefone} from "../suporte_geral/validacao";

const COLECAO = "solicitacoes_resgate";

/** Erro lançado quando o telefone de contato informado é inválido. */
export class TelefoneContatoInvalidoError extends ErroDominio {
  /** Constrói o erro de telefone de contato inválido. */
  constructor() {
    super("Informe um telefone válido (10 ou 11 dígitos, com DDD)", 400);
    this.name = "TelefoneContatoInvalidoError";
  }
}

/** Erro lançado quando o alerta de resgate não existe. */
export class SolicitacaoResgateNaoEncontradaError extends ErroDominio {
  /**
   * @param {string} id Id do alerta.
   */
  constructor(id: string) {
    super(`Alerta de resgate ${id} não encontrado`, 404);
    this.name = "SolicitacaoResgateNaoEncontradaError";
  }
}

/** Erro lançado ao tentar mudar o status de um alerta já concluído. */
export class SolicitacaoResgateJaConcluidaError extends ErroDominio {
  /**
   * @param {string} id Id do alerta.
   */
  constructor(id: string) {
    super(`Alerta de resgate ${id} já foi concluído`, 409);
    this.name = "SolicitacaoResgateJaConcluidaError";
  }
}

export interface NovaSolicitacaoResgateInput {
  descricaoSituacao: string;
  rua: string;
  bairro: string;
  nomeContato: string;
  telefoneContato: string;
  latitude?: number | null;
  longitude?: number | null;
  fotoUrl?: string | null;
}

/**
 * Módulo de Planejamento da Execução — alertas de resgate urgente: casos em
 * que o animal está ilhado/preso (árvore, telhado) e a equipe precisa de
 * equipamento especial (barco) para buscar. Público reporta, Defesa
 * Civil/bombeiros logados veem e atendem (ver README.md da pasta).
 */
export class ResgateService {
  private db: Firestore;
  private validadorEndereco: ValidadorEndereco;

  /**
   * @param {Firestore} db Instância do Firestore (produção ou emulador).
   * @param {ValidadorEndereco} validadorEndereco Validador de endereço
   *   contra Rio do Sul (padrão: Nominatim real).
   */
  constructor(
    db: Firestore, validadorEndereco: ValidadorEndereco = new NominatimClient()
  ) {
    this.db = db;
    this.validadorEndereco = validadorEndereco;
  }

  /**
   * Registra um alerta de resgate pendente.
   * @param {NovaSolicitacaoResgateInput} input Dados do alerta.
   * @return {Promise<SolicitacaoResgate>} O alerta criado.
   */
  async solicitar(
    input: NovaSolicitacaoResgateInput
  ): Promise<SolicitacaoResgate> {
    if (!validarTelefone(input.telefoneContato)) {
      throw new TelefoneContatoInvalidoError();
    }
    const enderecoValido = await this.validadorEndereco.existeEmRioDoSul(
      input.rua, input.bairro
    );
    if (!enderecoValido) {
      throw new EnderecoForaDeRioDoSulError();
    }

    const ref = this.db.collection(COLECAO).doc();
    const solicitacao: SolicitacaoResgate = {
      id: ref.id,
      descricaoSituacao: input.descricaoSituacao,
      rua: input.rua,
      bairro: input.bairro,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      nomeContato: input.nomeContato,
      telefoneContato: input.telefoneContato,
      fotoUrl: input.fotoUrl ?? null,
      status: "pendente",
      criadoEm: new Date().toISOString(),
    };
    await ref.set(solicitacao);
    return solicitacao;
  }

  /**
   * Lista todos os alertas de resgate registrados.
   * @return {Promise<SolicitacaoResgate[]>} Lista de alertas.
   */
  async listar(): Promise<SolicitacaoResgate[]> {
    const snap = await this.db.collection(COLECAO).get();
    return snap.docs.map((doc) => doc.data() as SolicitacaoResgate);
  }

  /**
   * Busca um alerta não concluído pelo id, ou lança erro apropriado.
   * @param {string} id Id do alerta.
   * @return {Promise<SolicitacaoResgate>} O alerta encontrado.
   */
  private async buscarNaoConcluido(id: string): Promise<SolicitacaoResgate> {
    const doc = await this.db.collection(COLECAO).doc(id).get();
    if (!doc.exists) throw new SolicitacaoResgateNaoEncontradaError(id);
    const solicitacao = doc.data() as SolicitacaoResgate;
    if (solicitacao.status === "concluido") {
      throw new SolicitacaoResgateJaConcluidaError(id);
    }
    return solicitacao;
  }

  /**
   * Marca o alerta como em atendimento pela equipe.
   * @param {string} id Id do alerta.
   * @return {Promise<void>} Nada.
   */
  async atender(id: string): Promise<void> {
    await this.buscarNaoConcluido(id);
    await this.atualizarStatus(id, "em_atendimento");
  }

  /**
   * Marca o alerta como concluído (resgate realizado).
   * @param {string} id Id do alerta.
   * @return {Promise<void>} Nada.
   */
  async concluir(id: string): Promise<void> {
    await this.buscarNaoConcluido(id);
    await this.atualizarStatus(id, "concluido");
  }

  /**
   * Atualiza o status de um alerta.
   * @param {string} id Id do alerta.
   * @param {StatusResgate} status Novo status.
   * @return {Promise<void>} Nada.
   */
  private async atualizarStatus(
    id: string, status: StatusResgate
  ): Promise<void> {
    await this.db.collection(COLECAO).doc(id).update({status});
  }
}
