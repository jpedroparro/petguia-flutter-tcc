import type {ValidadorEndereco} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {AbrigoService} from "./abrigo_service";
import {AnimalService} from "./animal_service";
import {
  ReunificacaoService,
  SolicitacaoReunificacaoJaProcessadaError,
  SolicitacaoReunificacaoNaoEncontradaError,
  TelefoneTutorInvalidoError,
} from "./reunificacao_service";
import type {Firestore} from "firebase-admin/firestore";

let db: Firestore;
const VALIDADOR_OK: ValidadorEndereco = {existeEmRioDoSul: async () => true};

beforeAll(() => {
  db = iniciarBancoTeste();
});

afterEach(async () => {
  await limparBancoTeste(db);
});

/**
 * @return {{
 *   reunificacaoService: ReunificacaoService,
 *   animalService: AnimalService,
 *   abrigoService: AbrigoService,
 * }} Serviços configurados para o banco de teste.
 */
function buildServices() {
  return {
    reunificacaoService: new ReunificacaoService(db),
    animalService: new AnimalService(db, VALIDADOR_OK),
    abrigoService: new AbrigoService(db, VALIDADOR_OK),
  };
}

describe("ReunificacaoService", () => {
  it("registra uma solicitação pendente para um animal existente", async () => {
    const {reunificacaoService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    const solicitacao = await reunificacaoService.solicitar({
      animalId: animal.id,
      nomeTutor: "João",
      telefoneTutor: "47988887777",
    });

    expect(solicitacao.status).toBe("pendente");
  });

  it("rejeita telefone do tutor com quantidade inválida de dígitos", async () => {
    const {reunificacaoService, animalService} = buildServices();
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
      reunificacaoService.solicitar({
        animalId: animal.id,
        nomeTutor: "João",
        telefoneTutor: "123",
      })
    ).rejects.toThrow(TelefoneTutorInvalidoError);
  });

  it("confirmar reunifica o animal e libera a vaga do abrigo", async () => {
    const {reunificacaoService, animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo R",
      endereco: "Rua R",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 2,
    });
    const animal = await animalService.cadastrar({
      especie: "gato",
      raca: "SRD",
      porte: "pequeno",
      estadoSaude: "estável",
      rua: "Rua R",
      bairro: "Centro",
      registradoPor: "uid-operador",
      abrigoId: abrigo.id,
    });
    const solicitacao = await reunificacaoService.solicitar({
      animalId: animal.id,
      nomeTutor: "João",
      telefoneTutor: "47988887777",
    });

    await reunificacaoService.confirmar(solicitacao.id);

    const animalAtualizado = await animalService.buscarPorId(animal.id);
    expect(animalAtualizado?.status).toBe("reunificado");
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(0);
  });

  it("recusar recusa sem alterar o status do animal", async () => {
    const {reunificacaoService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });
    const solicitacao = await reunificacaoService.solicitar({
      animalId: animal.id,
      nomeTutor: "João",
      telefoneTutor: "47988887777",
    });

    await reunificacaoService.recusar(solicitacao.id);

    const animalAtualizado = await animalService.buscarPorId(animal.id);
    expect(animalAtualizado?.status).toBe("resgatado");
  });

  it("lança erro ao confirmar solicitação inexistente", async () => {
    const {reunificacaoService} = buildServices();
    await expect(
      reunificacaoService.confirmar("id-invalido")
    ).rejects.toThrow(SolicitacaoReunificacaoNaoEncontradaError);
  });

  it("lança erro ao confirmar solicitação já processada", async () => {
    const {reunificacaoService, animalService} = buildServices();
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });
    const solicitacao = await reunificacaoService.solicitar({
      animalId: animal.id,
      nomeTutor: "João",
      telefoneTutor: "47988887777",
    });
    await reunificacaoService.confirmar(solicitacao.id);

    await expect(
      reunificacaoService.confirmar(solicitacao.id)
    ).rejects.toThrow(SolicitacaoReunificacaoJaProcessadaError);
  });
});
