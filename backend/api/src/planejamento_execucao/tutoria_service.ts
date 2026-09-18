import type {Firestore} from "firebase-admin/firestore";
import {validarCPF} from "../suporte_geral/cpf";
import {ErroDominio} from "../suporte_geral/erro_dominio";
import {validarTelefone} from "../suporte_geral/validacao";
import type {
  SolicitacaoTutoria,
  StatusSolicitacao,
} from "../gestao_dados/types";
import {AnimalNaoEncontradoError, AnimalService} from "./animal_service";

const COLECAO = "solicitacoes_tutoria";

/** Erro lançado quando o telefone do tutor informado é inválido. */
export class TelefoneTutorInvalidoError extends ErroDominio {
  /** Constrói o erro de telefone do tutor inválido. */
  constructor() {
    super("Informe um telefone válido (10 ou 11 dígitos, com DDD)", 400);
    this.name = "TelefoneTutorInvalidoError";
  }
}

/** Erro lançado quando o CPF informado não é estruturalmente válido. */
export class CpfInvalidoError extends ErroDominio {
  /** Constrói o erro de CPF inválido. */
  constructor() {
    super("CPF inválido", 400);
    this.name = "CpfInvalidoError";
  }
}

/** Erro lançado quando a idade informada do tutor é inválida. */
export class IdadeInvalidaError extends ErroDominio {
  /** Constrói o erro de idade inválida. */
  constructor() {
    super("O tutor precisa ser maior de idade (18 a 120 anos)", 400);
    this.name = "IdadeInvalidaError";
  }
}

/** Erro lançado quando a solicitação de tutoria não existe. */
export class SolicitacaoTutoriaNaoEncontradaError extends ErroDominio {
  /**
   * @param {string} id Id da solicitação.
   */
  constructor(id: string) {
    super(`Solicitação de tutoria ${id} não encontrada`, 404);
    this.name = "SolicitacaoTutoriaNaoEncontradaError";
  }
}

/** Erro lançado quando a solicitação de tutoria já foi processada. */
export class SolicitacaoTutoriaJaProcessadaError extends ErroDominio {
  /**
   * @param {string} id Id da solicitação.
   */
  constructor(id: string) {
    super(`Solicitação de tutoria ${id} já foi processada`, 409);
    this.name = "SolicitacaoTutoriaJaProcessadaError";
  }
}

export interface NovaSolicitacaoTutoriaInput {
  animalId: string;
  nomeTutor: string;
  dataNascimentoTutor: string;
  cpfTutor: string;
  telefoneTutor: string;
}

/**
 * Calcula a idade em anos completos a partir de uma data de nascimento ISO.
 * @param {string} dataNascimentoIso Data de nascimento no formato ISO.
 * @return {number} Idade em anos completos (NaN se a data for inválida).
 */
function calcularIdade(dataNascimentoIso: string): number {
  const nascimento = new Date(dataNascimentoIso);
  if (Number.isNaN(nascimento.getTime())) return NaN;

  const hoje = new Date();
  let idade = hoje.getFullYear() - nascimento.getFullYear();
  const aindaNaoFezAniversario =
    hoje.getMonth() < nascimento.getMonth() ||
    (hoje.getMonth() === nascimento.getMonth() &&
      hoje.getDate() < nascimento.getDate());
  if (aindaNaoFezAniversario) idade -= 1;
  return idade;
}

/**
 * Módulo de Planejamento da Execução — fluxo de tutoria temporária (ver
 * README.md da pasta para a citação do TCC).
 */
export class TutoriaService {
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
   * Registra um pedido de tutoria pendente para um animal.
   * @param {NovaSolicitacaoTutoriaInput} input Dados do pedido.
   * @return {Promise<SolicitacaoTutoria>} A solicitação criada.
   */
  async solicitar(
    input: NovaSolicitacaoTutoriaInput
  ): Promise<SolicitacaoTutoria> {
    if (!validarCPF(input.cpfTutor)) {
      throw new CpfInvalidoError();
    }
    if (!validarTelefone(input.telefoneTutor)) {
      throw new TelefoneTutorInvalidoError();
    }
    const idade = calcularIdade(input.dataNascimentoTutor);
    if (Number.isNaN(idade) || idade < 18 || idade > 120) {
      throw new IdadeInvalidaError();
    }

    const animal = await this.animalService.buscarPorId(input.animalId);
    if (!animal) {
      throw new AnimalNaoEncontradoError(input.animalId);
    }

    const ref = this.db.collection(COLECAO).doc();
    const solicitacao: SolicitacaoTutoria = {
      id: ref.id,
      animalId: input.animalId,
      nomeTutor: input.nomeTutor,
      dataNascimentoTutor: input.dataNascimentoTutor,
      cpfTutor: input.cpfTutor,
      telefoneTutor: input.telefoneTutor,
      status: "pendente",
      criadoEm: new Date().toISOString(),
    };
    await ref.set(solicitacao);
    return solicitacao;
  }

  /**
   * Lista todas as solicitações de tutoria.
   * @return {Promise<SolicitacaoTutoria[]>} Lista de solicitações.
   */
  async listar(): Promise<SolicitacaoTutoria[]> {
    const snap = await this.db.collection(COLECAO).get();
    return snap.docs.map((doc) => doc.data() as SolicitacaoTutoria);
  }

  /**
   * Busca uma solicitação pendente pelo id, ou lança erro apropriado.
   * @param {string} id Id da solicitação.
   * @return {Promise<SolicitacaoTutoria>} A solicitação pendente.
   */
  private async buscarPendente(id: string): Promise<SolicitacaoTutoria> {
    const doc = await this.db.collection(COLECAO).doc(id).get();
    if (!doc.exists) throw new SolicitacaoTutoriaNaoEncontradaError(id);
    const solicitacao = doc.data() as SolicitacaoTutoria;
    if (solicitacao.status !== "pendente") {
      throw new SolicitacaoTutoriaJaProcessadaError(id);
    }
    return solicitacao;
  }

  /**
   * Confirma a tutoria: marca o animal como com_tutor e libera o abrigo.
   * @param {string} id Id da solicitação.
   * @return {Promise<void>} Nada.
   */
  async confirmar(id: string): Promise<void> {
    const solicitacao = await this.buscarPendente(id);
    await this.animalService.marcarComoComTutor(solicitacao.animalId);
    await this.atualizarStatus(id, "confirmada");
  }

  /**
   * Recusa o pedido de tutoria, sem alterar o animal.
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
