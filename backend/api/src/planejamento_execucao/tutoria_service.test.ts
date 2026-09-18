import type {ValidadorEndereco} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {AbrigoService} from "./abrigo_service";
import {AnimalService} from "./animal_service";
import {
  CpfInvalidoError,
  IdadeInvalidaError,
  SolicitacaoTutoriaJaProcessadaError,
  SolicitacaoTutoriaNaoEncontradaError,
  TelefoneTutorInvalidoError,
  TutoriaService,
} from "./tutoria_service";
import type {Firestore} from "firebase-admin/firestore";

let db: Firestore;
const CPF_VALIDO = "111.444.777-35";
const VALIDADOR_OK: ValidadorEndereco = {existeEmRioDoSul: async () => true};

beforeAll(() => {
  db = iniciarBancoTeste();
});

afterEach(async () => {
  await limparBancoTeste(db);
});

/**
 * @return {{
 *   tutoriaService: TutoriaService,
 *   animalService: AnimalService,
 *   abrigoService: AbrigoService,
 * }} Serviços configurados para o banco de teste.
 */
function buildServices() {
  return {
    tutoriaService: new TutoriaService(db),
    animalService: new AnimalService(db, VALIDADOR_OK),
    abrigoService: new AbrigoService(db, VALIDADOR_OK),
  };
}

describe("TutoriaService", () => {
  it("registra uma solicitação pendente para um animal existente", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    const solicitacao = await tutoriaService.solicitar({
      animalId: animal.id,
      nomeTutor: "Maria",
      dataNascimentoTutor: "1994-06-15",
      cpfTutor: CPF_VALIDO,
      telefoneTutor: "47999999999",
    });

    expect(solicitacao.status).toBe("pendente");
  });

  it("rejeita CPF inválido", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    await expect(
      tutoriaService.solicitar({
        animalId: animal.id,
        nomeTutor: "Maria",
        dataNascimentoTutor: "1994-06-15",
        cpfTutor: "123",
        telefoneTutor: "1",
      })
    ).rejects.toThrow(CpfInvalidoError);
  });

  it("rejeita telefone do tutor com quantidade inválida de dígitos", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    await expect(
      tutoriaService.solicitar({
        animalId: animal.id,
        nomeTutor: "Maria",
        dataNascimentoTutor: "1994-06-15",
        cpfTutor: CPF_VALIDO,
        telefoneTutor: "123",
      })
    ).rejects.toThrow(TelefoneTutorInvalidoError);
  });

  it("rejeita tutor menor de idade", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    await expect(
      tutoriaService.solicitar({
        animalId: animal.id,
        nomeTutor: "Maria",
        dataNascimentoTutor: "2015-06-15",
        cpfTutor: CPF_VALIDO,
        telefoneTutor: "47999999999",
      })
    ).rejects.toThrow(IdadeInvalidaError);
  });

  it("confirmar dá tutoria ao animal e libera a vaga do abrigo", async () => {
    const {tutoriaService, animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo T",
      endereco: "Rua T",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 2,
    });
    const animal = await animalService.cadastrar({
      especie: "gato",
      raca: "SRD",
      porte: "pequeno",
      estadoSaude: "estável",
      rua: "Rua T",
      bairro: "Centro",
      registradoPor: "uid-operador",
      abrigoId: abrigo.id,
    });
    const solicitacao = await tutoriaService.solicitar({
      animalId: animal.id,
      nomeTutor: "Maria",
      dataNascimentoTutor: "1994-06-15",
      cpfTutor: CPF_VALIDO,
      telefoneTutor: "47999999999",
    });

    await tutoriaService.confirmar(solicitacao.id);

    const animalAtualizado = await animalService.buscarPorId(animal.id);
    expect(animalAtualizado?.status).toBe("com_tutor");
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(0);
  });

  it("recusar recusa sem alterar o status do animal", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });
    const solicitacao = await tutoriaService.solicitar({
      animalId: animal.id,
      nomeTutor: "Maria",
      dataNascimentoTutor: "1994-06-15",
      cpfTutor: CPF_VALIDO,
      telefoneTutor: "47999999999",
    });

    await tutoriaService.recusar(solicitacao.id);

    const animalAtualizado = await animalService.buscarPorId(animal.id);
    expect(animalAtualizado?.status).toBe("resgatado");
  });

  it("lança erro ao confirmar solicitação inexistente", async () => {
    const {tutoriaService} = buildServices();
    await expect(
      tutoriaService.confirmar("id-invalido")
    ).rejects.toThrow(SolicitacaoTutoriaNaoEncontradaError);
  });

  it("lança erro ao confirmar solicitação já processada", async () => {
    const {tutoriaService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });
    const solicitacao = await tutoriaService.solicitar({
      animalId: animal.id,
      nomeTutor: "Maria",
      dataNascimentoTutor: "1994-06-15",
      cpfTutor: CPF_VALIDO,
      telefoneTutor: "47999999999",
    });
    await tutoriaService.confirmar(solicitacao.id);

    await expect(
      tutoriaService.confirmar(solicitacao.id)
    ).rejects.toThrow(SolicitacaoTutoriaJaProcessadaError);
  });
});
