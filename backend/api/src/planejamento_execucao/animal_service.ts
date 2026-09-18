import type {Firestore} from "firebase-admin/firestore";
import {
  EnderecoForaDeRioDoSulError,
  NominatimClient,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import type {Animal, AnimalPorte, AnimalStatus} from "../gestao_dados/types";
import {ErroDominio} from "../suporte_geral/erro_dominio";
import {validarCep, validarTelefone} from "../suporte_geral/validacao";
import {
  AbrigoLotadoError,
  AbrigoNaoEncontradoError,
  AbrigoService,
} from "./abrigo_service";

export {AbrigoLotadoError, AbrigoNaoEncontradoError};

const COLECAO = "animais";

/** Erro lançado quando o animal referenciado não existe. */
export class AnimalNaoEncontradoError extends ErroDominio {
  /**
   * @param {string} animalId Id do animal.
   */
  constructor(animalId: string) {
    super(`Animal ${animalId} não encontrado`, 404);
    this.name = "AnimalNaoEncontradoError";
  }
}

/** Erro lançado quando o telefone de contato informado é inválido. */
export class TelefoneContatoInvalidoError extends ErroDominio {
  /** Constrói o erro de telefone de contato inválido. */
  constructor() {
    super("Informe um telefone válido (10 ou 11 dígitos, com DDD)", 400);
    this.name = "TelefoneContatoInvalidoError";
  }
}

/** Erro lançado quando o CEP do resgate informado é inválido. */
export class CepResgateInvalidoError extends ErroDominio {
  /** Constrói o erro de CEP inválido. */
  constructor() {
    super("Informe um CEP válido (8 dígitos)", 400);
    this.name = "CepResgateInvalidoError";
  }
}

export interface NovoAnimalInput {
  especie: string;
  raca: string;
  porte: AnimalPorte;
  estadoSaude: string;
  rua: string;
  bairro: string;
  cepResgate?: string | null;
  registradoPor: string;
  latitudeResgate?: number | null;
  longitudeResgate?: number | null;
  comColeira?: boolean;
  nomeIdentificacao?: string | null;
  telefoneContato?: string | null;
  fotoUrl?: string | null;
  abrigoId?: string | null;
}

/**
 * Módulo de Planejamento da Execução — cadastro e ciclo de vida dos
 * animais resgatados (ver README.md da pasta para a citação do TCC).
 */
export class AnimalService {
  private db: Firestore;
  private abrigoService: AbrigoService;
  private validadorEndereco: ValidadorEndereco;

  /**
   * @param {Firestore} db Instância do Firestore (produção ou emulador).
   * @param {ValidadorEndereco} validadorEndereco Validador de rua/bairro
   *   contra Rio do Sul (padrão: Nominatim real).
   */
  constructor(
    db: Firestore, validadorEndereco: ValidadorEndereco = new NominatimClient()
  ) {
    this.db = db;
    this.abrigoService = new AbrigoService(db);
    this.validadorEndereco = validadorEndereco;
  }

  /**
   * Cadastra um animal resgatado, alocando-o a um abrigo se informado.
   * @param {NovoAnimalInput} input Dados do animal.
   * @return {Promise<Animal>} O animal cadastrado.
   */
  async cadastrar(input: NovoAnimalInput): Promise<Animal> {
    const enderecoValido = await this.validadorEndereco.existeEmRioDoSul(
      input.rua, input.bairro
    );
    if (!enderecoValido) {
      throw new EnderecoForaDeRioDoSulError();
    }

    if (input.telefoneContato && !validarTelefone(input.telefoneContato)) {
      throw new TelefoneContatoInvalidoError();
    }
    if (input.cepResgate && !validarCep(input.cepResgate)) {
      throw new CepResgateInvalidoError();
    }

    let status: AnimalStatus = "resgatado";

    if (input.abrigoId) {
      const abrigo = await this.abrigoService.buscarPorId(input.abrigoId);
      if (!abrigo) {
        throw new AbrigoNaoEncontradoError(input.abrigoId);
      }
      if (abrigo.capacidadeOcupada >= abrigo.capacidadeTotal) {
        throw new AbrigoLotadoError(input.abrigoId);
      }
      status = "em_abrigo";
      // Reserva a vaga ANTES de escrever o animal: se estourar por
      // concorrência (checagem reforçada dentro da transação de
      // incrementarOcupacao), nada foi persistido ainda — sem isso, uma
      // corrida rara deixaria um animal "fantasma" já gravado com
      // abrigoId/status de em_abrigo mas sem a vaga contabilizada.
      await this.abrigoService.incrementarOcupacao(input.abrigoId, 1);
    }

    const ref = this.db.collection(COLECAO).doc();
    const localizacaoResgate = input.bairro
      ? `${input.rua}, ${input.bairro}`
      : input.rua;
    const animal: Animal = {
      id: ref.id,
      especie: input.especie,
      raca: input.raca,
      porte: input.porte,
      estadoSaude: input.estadoSaude,
      localizacaoResgate,
      cepResgate: input.cepResgate ?? null,
      latitudeResgate: input.latitudeResgate ?? null,
      longitudeResgate: input.longitudeResgate ?? null,
      comColeira: input.comColeira ?? false,
      nomeIdentificacao: input.nomeIdentificacao ?? null,
      telefoneContato: input.telefoneContato ?? null,
      fotoUrl: input.fotoUrl ?? null,
      abrigoId: input.abrigoId ?? null,
      status,
      registradoPor: input.registradoPor,
      criadoEm: new Date().toISOString(),
    };
    await ref.set(animal);

    return animal;
  }

  /**
   * Lista todos os animais cadastrados.
   * @return {Promise<Animal[]>} Lista de animais.
   */
  async listar(): Promise<Animal[]> {
    const snap = await this.db.collection(COLECAO).get();
    return snap.docs.map((doc) => doc.data() as Animal);
  }

  /**
   * Busca um animal pelo id.
   * @param {string} id Id do animal.
   * @return {Promise<Animal | null>} O animal, ou null se não encontrado.
   */
  async buscarPorId(id: string): Promise<Animal | null> {
    const doc = await this.db.collection(COLECAO).doc(id).get();
    return doc.exists ? (doc.data() as Animal) : null;
  }

  /**
   * Aloca um animal a um abrigo, incrementando a ocupação. Se o animal já
   * estava alocado em outro abrigo (realocação), libera a vaga de lá depois
   * — sem isso, a vaga anterior nunca é liberada e a ocupação diverge da
   * realidade. Se o animal já estava alocado NESSE MESMO abrigo (reenvio,
   * duplo toque), não mexe em ocupação nenhuma — é uma chamada idempotente,
   * não uma segunda alocação.
   * @param {string} animalId Id do animal.
   * @param {string} abrigoId Id do abrigo de destino.
   * @return {Promise<void>} Nada.
   */
  async marcarComoEmAbrigo(animalId: string, abrigoId: string): Promise<void> {
    const animal = await this.buscarPorId(animalId);
    if (!animal) {
      throw new AnimalNaoEncontradoError(animalId);
    }

    const abrigoAnteriorId = animal.abrigoId;
    if (abrigoAnteriorId === abrigoId) {
      if (animal.status !== "em_abrigo") {
        await this.db.collection(COLECAO).doc(animalId).update({
          status: "em_abrigo" as AnimalStatus,
        });
      }
      return;
    }

    const abrigo = await this.abrigoService.buscarPorId(abrigoId);
    if (!abrigo) {
      throw new AbrigoNaoEncontradoError(abrigoId);
    }
    if (abrigo.capacidadeOcupada >= abrigo.capacidadeTotal) {
      throw new AbrigoLotadoError(abrigoId);
    }

    // Reserva a vaga no destino ANTES de mudar o animal: se estourar por
    // concorrência (checagem reforçada dentro da transação), nada mais
    // muda — sem isso, uma corrida rara deixaria o animal apontando pro
    // novo abrigo sem a vaga de fato reservada.
    await this.abrigoService.incrementarOcupacao(abrigoId, 1);

    await this.db.collection(COLECAO).doc(animalId).update({
      abrigoId,
      status: "em_abrigo" as AnimalStatus,
    });

    if (abrigoAnteriorId) {
      await this.abrigoService.incrementarOcupacao(abrigoAnteriorId, -1);
    }
  }

  /**
   * Libera a vaga do abrigo do animal, se houver, e atualiza seu status.
   * @param {string} animalId Id do animal.
   * @param {AnimalStatus} novoStatus Novo status ("reunificado" ou
   *   "com_tutor").
   * @return {Promise<void>} Nada.
   */
  private async liberarAbrigoEAtualizarStatus(
    animalId: string, novoStatus: AnimalStatus
  ): Promise<void> {
    const animal = await this.buscarPorId(animalId);
    if (!animal) {
      throw new AnimalNaoEncontradoError(animalId);
    }

    if (animal.abrigoId) {
      await this.abrigoService.incrementarOcupacao(animal.abrigoId, -1);
    }

    await this.db
      .collection(COLECAO)
      .doc(animalId)
      .update({status: novoStatus, abrigoId: null});
  }

  /**
   * Marca o animal como reunificado com o tutor original.
   * @param {string} animalId Id do animal.
   * @return {Promise<void>} Nada.
   */
  async marcarComoReunificado(animalId: string): Promise<void> {
    await this.liberarAbrigoEAtualizarStatus(animalId, "reunificado");
  }

  /**
   * Marca o animal como sob cuidado de um tutor temporário.
   * @param {string} animalId Id do animal.
   * @return {Promise<void>} Nada.
   */
  async marcarComoComTutor(animalId: string): Promise<void> {
    await this.liberarAbrigoEAtualizarStatus(animalId, "com_tutor");
  }
}
