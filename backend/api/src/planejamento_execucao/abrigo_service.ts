import type {Firestore} from "firebase-admin/firestore";
import {
  EnderecoForaDeRioDoSulError,
  NominatimClient,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import type {Abrigo} from "../gestao_dados/types";
import {ErroDominio} from "../suporte_geral/erro_dominio";
import {validarCep, validarTelefone} from "../suporte_geral/validacao";

const COLECAO = "abrigos";

export interface NovoAbrigoInput {
  nome: string;
  endereco: string;
  cep: string;
  telefone: string;
  capacidadeTotal: number;
  latitude?: number | null;
  longitude?: number | null;
}

export interface AtualizarAbrigoInput {
  nome?: string;
  endereco?: string;
  cep?: string;
  telefone?: string;
  capacidadeTotal?: number;
  latitude?: number | null;
  longitude?: number | null;
}

/** Erro lançado ao tentar criar um abrigo com capacidade inválida. */
export class CapacidadeInvalidaError extends ErroDominio {
  /** Constrói o erro de capacidade inválida. */
  constructor() {
    super("A capacidade total do abrigo deve ser maior que zero", 400);
    this.name = "CapacidadeInvalidaError";
  }
}

/** Erro lançado ao editar a capacidade total abaixo da ocupação atual. */
export class CapacidadeMenorQueOcupacaoError extends ErroDominio {
  /** Constrói o erro de capacidade menor que a ocupação atual. */
  constructor() {
    super(
      "A capacidade total não pode ficar menor que a ocupação atual", 400
    );
    this.name = "CapacidadeMenorQueOcupacaoError";
  }
}

/** Erro lançado ao tentar criar um abrigo com CEP inválido. */
export class CepInvalidoError extends ErroDominio {
  /** Constrói o erro de CEP inválido. */
  constructor() {
    super("Informe um CEP válido (8 dígitos)", 400);
    this.name = "CepInvalidoError";
  }
}

/** Erro lançado ao tentar criar um abrigo com telefone inválido. */
export class TelefoneInvalidoError extends ErroDominio {
  /** Constrói o erro de telefone inválido. */
  constructor() {
    super("Informe um telefone válido (10 ou 11 dígitos, com DDD)", 400);
    this.name = "TelefoneInvalidoError";
  }
}

/** Erro lançado ao tentar alocar um animal em um abrigo sem vagas. */
export class AbrigoLotadoError extends ErroDominio {
  /**
   * @param {string} abrigoId Id do abrigo lotado.
   */
  constructor(abrigoId: string) {
    super(`Abrigo ${abrigoId} está com capacidade lotada`, 409);
    this.name = "AbrigoLotadoError";
  }
}

/** Erro lançado quando o abrigo referenciado não existe. */
export class AbrigoNaoEncontradoError extends ErroDominio {
  /**
   * @param {string} abrigoId Id do abrigo.
   */
  constructor(abrigoId: string) {
    super(`Abrigo ${abrigoId} não encontrado`, 404);
    this.name = "AbrigoNaoEncontradoError";
  }
}

/**
 * Módulo de Planejamento da Execução — gerenciamento de abrigos (ver
 * README.md da pasta para a citação do TCC).
 */
export class AbrigoService {
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
   * Cria um novo abrigo com ocupação zerada.
   * @param {NovoAbrigoInput} input Dados do abrigo.
   * @return {Promise<Abrigo>} O abrigo criado.
   */
  async criar(input: NovoAbrigoInput): Promise<Abrigo> {
    if (input.capacidadeTotal <= 0) {
      throw new CapacidadeInvalidaError();
    }
    if (!validarCep(input.cep)) {
      throw new CepInvalidoError();
    }
    if (!validarTelefone(input.telefone)) {
      throw new TelefoneInvalidoError();
    }
    const enderecoValido = await this.validadorEndereco.existeEmRioDoSul(
      input.endereco
    );
    if (!enderecoValido) {
      throw new EnderecoForaDeRioDoSulError();
    }

    const ref = this.db.collection(COLECAO).doc();
    const abrigo: Abrigo = {
      id: ref.id,
      nome: input.nome,
      endereco: input.endereco,
      cep: input.cep,
      telefone: input.telefone,
      capacidadeTotal: input.capacidadeTotal,
      capacidadeOcupada: 0,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      ativo: true,
      criadoEm: new Date().toISOString(),
    };
    await ref.set(abrigo);
    return abrigo;
  }

  /**
   * Lista todos os abrigos cadastrados.
   * @return {Promise<Abrigo[]>} Lista de abrigos.
   */
  async listar(): Promise<Abrigo[]> {
    const snap = await this.db.collection(COLECAO).get();
    return snap.docs.map((doc) => doc.data() as Abrigo);
  }

  /**
   * Busca um abrigo pelo id.
   * @param {string} id Id do abrigo.
   * @return {Promise<Abrigo | null>} O abrigo, ou null se não encontrado.
   */
  async buscarPorId(id: string): Promise<Abrigo | null> {
    const doc = await this.db.collection(COLECAO).doc(id).get();
    return doc.exists ? (doc.data() as Abrigo) : null;
  }

  /**
   * Atualiza os dados cadastrais de um abrigo (nome, endereço, contato,
   * capacidade, localização). Nunca mexe em `capacidadeOcupada` — essa só
   * muda via `incrementarOcupacao`/`atualizarOcupacao`, chamada pelas
   * transições de status do animal.
   * @param {string} id Id do abrigo.
   * @param {AtualizarAbrigoInput} input Campos a atualizar (parcial).
   * @return {Promise<Abrigo>} O abrigo atualizado.
   */
  async atualizar(id: string, input: AtualizarAbrigoInput): Promise<Abrigo> {
    const abrigo = await this.buscarPorId(id);
    if (!abrigo) {
      throw new AbrigoNaoEncontradoError(id);
    }
    if (input.capacidadeTotal !== undefined) {
      if (input.capacidadeTotal <= 0) {
        throw new CapacidadeInvalidaError();
      }
      if (input.capacidadeTotal < abrigo.capacidadeOcupada) {
        throw new CapacidadeMenorQueOcupacaoError();
      }
    }
    if (input.cep !== undefined && !validarCep(input.cep)) {
      throw new CepInvalidoError();
    }
    if (input.telefone !== undefined && !validarTelefone(input.telefone)) {
      throw new TelefoneInvalidoError();
    }
    if (input.endereco !== undefined) {
      const enderecoValido = await this.validadorEndereco.existeEmRioDoSul(
        input.endereco
      );
      if (!enderecoValido) {
        throw new EnderecoForaDeRioDoSulError();
      }
    }

    const campos: Partial<Abrigo> = {};
    if (input.nome !== undefined) campos.nome = input.nome;
    if (input.endereco !== undefined) campos.endereco = input.endereco;
    if (input.cep !== undefined) campos.cep = input.cep;
    if (input.telefone !== undefined) campos.telefone = input.telefone;
    if (input.capacidadeTotal !== undefined) {
      campos.capacidadeTotal = input.capacidadeTotal;
    }
    if (input.latitude !== undefined) campos.latitude = input.latitude;
    if (input.longitude !== undefined) campos.longitude = input.longitude;

    await this.db.collection(COLECAO).doc(id).update(campos);
    return {...abrigo, ...campos};
  }

  /**
   * Define a capacidade ocupada de um abrigo diretamente, sem transação e
   * sem checar o teto de `capacidadeTotal` — setter cru só para preparar
   * estado em teste (ver `abrigo_service.test.ts`/`animal_service.test.ts`).
   * Nenhuma rota expõe isso; a mutação real de ocupação em produção é
   * sempre via `incrementarOcupacao`, que é transacional e reforça o teto.
   * @param {string} id Id do abrigo.
   * @param {number} capacidadeOcupada Nova ocupação.
   * @return {Promise<void>} Nada.
   */
  async atualizarOcupacao(
    id: string, capacidadeOcupada: number
  ): Promise<void> {
    await this.db.collection(COLECAO).doc(id).update({capacidadeOcupada});
  }

  /**
   * Incrementa (ou decrementa, com valor negativo) a ocupação de um abrigo
   * de forma atômica, sem nunca deixá-la abaixo de zero nem acima da
   * capacidade total — a checagem de lotação roda dentro da própria
   * transação (não antes dela) justamente para fechar a condição de
   * corrida entre dois cadastros/realocações concorrentes pro mesmo
   * abrigo: qualquer checagem feita fora da transação pode ler "ainda tem
   * vaga" antes de a outra commitar.
   * @param {string} id Id do abrigo.
   * @param {number} delta Variação da ocupação (ex: 1 ou -1).
   * @return {Promise<void>} Nada.
   */
  async incrementarOcupacao(id: string, delta: number): Promise<void> {
    await this.db.runTransaction(async (tx) => {
      const ref = this.db.collection(COLECAO).doc(id);
      const doc = await tx.get(ref);
      const abrigo = doc.data() as Abrigo | undefined;
      if (abrigo == null) {
        throw new AbrigoNaoEncontradoError(id);
      }
      const novo = Math.max(0, abrigo.capacidadeOcupada + delta);
      if (delta > 0 && novo > abrigo.capacidadeTotal) {
        throw new AbrigoLotadoError(id);
      }
      tx.update(ref, {capacidadeOcupada: novo});
    });
  }
}
