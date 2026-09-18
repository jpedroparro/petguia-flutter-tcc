import type {Firestore} from "firebase-admin/firestore";
import type {
  SolicitacaoReunificacao,
  StatusSolicitacao,
} from "../gestao_dados/types";
import {ErroDominio} from "../suporte_geral/erro_dominio";
import {validarTelefone} from "../suporte_geral/validacao";
import {AnimalNaoEncontradoError, AnimalService} from "./animal_service";

const COLECAO = "solicitacoes_reunificacao";

/** Erro lançado quando o telefone do tutor informado é inválido. */
export class TelefoneTutorInvalidoError extends ErroDominio {
  /** Constrói o erro de telefone do tutor inválido. */
  constructor() {
    super("Informe um telefone válido (10 ou 11 dígitos, com DDD)", 400);
    this.name = "TelefoneTutorInvalidoError";
  }
}

/** Erro lançado quando a solicitação de reunificação não existe. */
export class SolicitacaoReunificacaoNaoEncontradaError extends ErroDominio {
  /**
   * @param {string} id Id da solicitação.
   */
  constructor(id: string) {
    super(`Solicitação de reunificação ${id} não encontrada`, 404);
    this.name = "SolicitacaoReunificacaoNaoEncontradaError";
  }
}

/** Erro lançado quando a solicitação de reunificação já foi processada. */
export class SolicitacaoReunificacaoJaProcessadaError extends ErroDominio {
  /**
   * @param {string} id Id da solicitação.
   */
  constructor(id: string) {
    super(`Solicitação de reunificação ${id} já foi processada`, 409);
    this.name = "SolicitacaoReunificacaoJaProcessadaError";
  }
}

export interface NovaSolicitacaoReunificacaoInput {
  animalId: string;
  nomeTutor: string;
  telefoneTutor: string;
  mensagem?: string | null;
}

/**
 * Módulo de Planejamento da Execução — fluxo de reunificação com o tutor
 * original (ver README.md da pasta para a citação do TCC).
 */
export class ReunificacaoService {
  private db: Firestore;
  private animalService: AnimalService;

  /**
   * @param {Firestore} db Instância do Firestore (produção ou emulador).
   */
  constructor(db: Firestore) {
    this.db = db;
    this.animalService = new AnimalService(db);
  }

  /**
   * Registra um pedido de reunificação pendente para um animal.
   * @param {NovaSolicitacaoReunificacaoInput} input Dados do pedido.
   * @return {Promise<SolicitacaoReunificacao>} A solicitação criada.
   */
  async solicitar(
    input: NovaSolicitacaoReunificacaoInput
  ): Promise<SolicitacaoReunificacao> {
    if (!validarTelefone(input.telefoneTutor)) {
      throw new TelefoneTutorInvalidoError();
    }
    const animal = await this.animalService.buscarPorId(input.animalId);
    if (!animal) {
      throw new AnimalNaoEncontradoError(input.animalId);
    }

    const ref = this.db.collection(COLECAO).doc();
    const solicitacao: SolicitacaoReunificacao = {
      id: ref.id,
      animalId: input.animalId,
      nomeTutor: input.nomeTutor,
      telefoneTutor: input.telefoneTutor,
      mensagem: input.mensagem ?? null,
      status: "pendente",
      criadoEm: new Date().toISOString(),
    };
    await ref.set(solicitacao);
    return solicitacao;
  }

  /**
   * Lista todas as solicitações de reunificação.
   * @return {Promise<SolicitacaoReunificacao[]>} Lista de solicitações.
   */
  async listar(): Promise<SolicitacaoReunificacao[]> {
    const snap = await this.db.collection(COLECAO).get();
    return snap.docs.map((doc) => doc.data() as SolicitacaoReunificacao);
  }

  /**
   * Busca uma solicitação pendente pelo id, ou lança erro apropriado.
   * @param {string} id Id da solicitação.
   * @return {Promise<SolicitacaoReunificacao>} A solicitação pendente.
   */
  private async buscarPendente(id: string): Promise<SolicitacaoReunificacao> {
    const doc = await this.db.collection(COLECAO).doc(id).get();
    if (!doc.exists) throw new SolicitacaoReunificacaoNaoEncontradaError(id);
    const solicitacao = doc.data() as SolicitacaoReunificacao;
    if (solicitacao.status !== "pendente") {
      throw new SolicitacaoReunificacaoJaProcessadaError(id);
    }
    return solicitacao;
  }

  /**
   * Confirma a reunificação: marca o animal como reunificado e libera o
   * abrigo.
   * @param {string} id Id da solicitação.
   * @return {Promise<void>} Nada.
   */
  async confirmar(id: string): Promise<void> {
    const solicitacao = await this.buscarPendente(id);
    await this.animalService.marcarComoReunificado(solicitacao.animalId);
    await this.atualizarStatus(id, "confirmada");
  }

  /**
   * Recusa o pedido de reunificação, sem alterar o animal.
   * @param {string} id Id da solicitação.
   * @return {Promise<void>} Nada.
   */
  async recusar(id: string): Promise<void> {
    await this.buscarPendente(id);
    await this.atualizarStatus(id, "recusada");
  }

  /**
   * Atualiza o status de uma solicitação.
   * @param {string} id Id da solicitação.
   * @param {StatusSolicitacao} status Novo status.
   * @return {Promise<void>} Nada.
   */
  private async atualizarStatus(
    id: string, status: StatusSolicitacao
  ): Promise<void> {
    await this.db.collection(COLECAO).doc(id).update({status});
  }
}
