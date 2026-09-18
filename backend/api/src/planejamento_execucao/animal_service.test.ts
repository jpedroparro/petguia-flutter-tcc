import {
  EnderecoForaDeRioDoSulError,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {AbrigoService} from "./abrigo_service";
import {
  AbrigoLotadoError,
  AnimalNaoEncontradoError,
  AnimalService,
  CepResgateInvalidoError,
  TelefoneContatoInvalidoError,
} from "./animal_service";
import type {Firestore} from "firebase-admin/firestore";

let db: Firestore;

/** Validador de endereço fake — sempre aceita, sem chamar rede nenhuma. */
const VALIDADOR_OK: ValidadorEndereco = {
  existeEmRioDoSul: async () => true,
};

beforeAll(() => {
  db = iniciarBancoTeste();
});

afterEach(async () => {
  await limparBancoTeste(db);
});

/**
 * @param {ValidadorEndereco} validadorEndereco Validador a injetar no
 *   AnimalService (padrão: sempre aceita).
 * @return {{
 *   animalService: AnimalService,
 *   abrigoService: AbrigoService,
 * }} Serviços configurados para o banco de teste.
 */
function buildServices(validadorEndereco: ValidadorEndereco = VALIDADOR_OK) {
  return {
    animalService: new AnimalService(db, validadorEndereco),
    abrigoService: new AbrigoService(db, VALIDADOR_OK),
  };
}

describe("AnimalService", () => {
  it("cadastra com status resgatado quando não informa abrigo", async () => {
    const {animalService} = buildServices();

    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua X",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    expect(animal.status).toBe("resgatado");
    expect(animal.abrigoId).toBeNull();
  });

  it("rejeita rua/bairro que não existe em Rio do Sul", async () => {
    const {animalService} = buildServices({existeEmRioDoSul: async () => false});

    await expect(
      animalService.cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "medio",
        estadoSaude: "estável",
        rua: "Rua Que Não Existe",
        bairro: "Bairro Fantasma",
        registradoPor: "uid-operador",
      })
    ).rejects.toThrow(EnderecoForaDeRioDoSulError);
  });

  it(
    "rejeita telefone de contato com quantidade inválida de dígitos",
    async () => {
      const {animalService} = buildServices();
      await expect(
        animalService.cadastrar({
          especie: "cachorro",
          raca: "SRD",
          porte: "medio",
          estadoSaude: "estável",
          rua: "Rua X",
          bairro: "Centro",
          registradoPor: "uid-operador",
          telefoneContato: "123",
        })
      ).rejects.toThrow(TelefoneContatoInvalidoError);
    }
  );

  it("rejeita CEP de resgate com quantidade inválida de dígitos", async () => {
    const {animalService} = buildServices();
    await expect(
      animalService.cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "medio",
        estadoSaude: "estável",
        rua: "Rua X",
        bairro: "Centro",
        registradoPor: "uid-operador",
        cepResgate: "123",
      })
    ).rejects.toThrow(CepResgateInvalidoError);
  });

  it("cadastra já alocado a um abrigo, incrementando ocupação", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo X",
      endereco: "Rua X",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 2,
    });

    const animal = await animalService.cadastrar({
      especie: "gato",
      raca: "SRD",
      porte: "pequeno",
      estadoSaude: "estável",
      rua: "Rua Y",
      bairro: "Centro",
      registradoPor: "uid-operador",
      abrigoId: abrigo.id,
    });

    expect(animal.status).toBe("em_abrigo");
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(1);
  });

  it("rejeita cadastro em abrigo lotado", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo Cheio",
      endereco: "Rua Z",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 1,
    });
    await abrigoService.atualizarOcupacao(abrigo.id, 1);

    await expect(
      animalService.cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "grande",
        estadoSaude: "estável",
        rua: "Rua Z",
        bairro: "Centro",
        registradoPor: "uid-operador",
        abrigoId: abrigo.id,
      })
    ).rejects.toThrow(AbrigoLotadoError);
  });

  it("marcarComoEmAbrigo aloca o animal e incrementa a ocupação", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo A",
      endereco: "Rua A",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 5,
    });
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua A",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    await animalService.marcarComoEmAbrigo(animal.id, abrigo.id);

    const atualizado = await animalService.buscarPorId(animal.id);
    expect(atualizado?.status).toBe("em_abrigo");
    expect(atualizado?.abrigoId).toBe(abrigo.id);
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(1);
  });

  it("marcarComoReunificado libera a vaga do abrigo do animal", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo B",
      endereco: "Rua B",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 5,
    });
    const animal = await animalService.cadastrar({
      especie: "gato",
      raca: "SRD",
      porte: "pequeno",
      estadoSaude: "estável",
      rua: "Rua B",
      bairro: "Centro",
      registradoPor: "uid-operador",
      abrigoId: abrigo.id,
    });

    await animalService.marcarComoReunificado(animal.id);

    const atualizado = await animalService.buscarPorId(animal.id);
    expect(atualizado?.status).toBe("reunificado");
    // Regressão: abrigoId ficava "fantasma" (apontando pro abrigo antigo)
    // mesmo depois de a vaga já ter sido liberada.
    expect(atualizado?.abrigoId).toBeNull();
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(0);
  });

  it(
    "marcarComoEmAbrigo libera a vaga do abrigo anterior ao realocar",
    async () => {
      // Regressão: realocar um animal de um abrigo pra outro incrementava a
      // ocupação do novo sem nunca decrementar a do anterior — a vaga
      // "vazava" e ficava presa pra sempre.
      const {animalService, abrigoService} = buildServices();
      const abrigoOrigem = await abrigoService.criar({
        nome: "Abrigo Origem",
        endereco: "Rua O",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 5,
      });
      const abrigoDestino = await abrigoService.criar({
        nome: "Abrigo Destino",
        endereco: "Rua D",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 5,
      });
      const animal = await animalService.cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "medio",
        estadoSaude: "estável",
        rua: "Rua O",
        bairro: "Centro",
        registradoPor: "uid-operador",
        abrigoId: abrigoOrigem.id,
      });

      await animalService.marcarComoEmAbrigo(animal.id, abrigoDestino.id);

      const atualizado = await animalService.buscarPorId(animal.id);
      expect(atualizado?.abrigoId).toBe(abrigoDestino.id);
      const origemAtualizado = await abrigoService.buscarPorId(abrigoOrigem.id);
      expect(origemAtualizado?.capacidadeOcupada).toBe(0);
      const destinoAtualizado =
        await abrigoService.buscarPorId(abrigoDestino.id);
      expect(destinoAtualizado?.capacidadeOcupada).toBe(1);
    }
  );

  it(
    "marcarComoEmAbrigo é idempotente ao repetir o mesmo abrigo",
    async () => {
      // Regressão: marcar de novo o MESMO abrigo (reenvio, duplo toque)
      // pulava o decremento (correto, é o mesmo abrigo) mas incrementava
      // de novo (incorreto) — contava a vaga duas vezes pro mesmo animal.
      const {animalService, abrigoService} = buildServices();
      const abrigo = await abrigoService.criar({
        nome: "Abrigo Repetido",
        endereco: "Rua R",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 5,
      });
      const animal = await animalService.cadastrar({
        especie: "cachorro",
        raca: "SRD",
        porte: "medio",
        estadoSaude: "estável",
        rua: "Rua R",
        bairro: "Centro",
        registradoPor: "uid-operador",
        abrigoId: abrigo.id,
      });

      await animalService.marcarComoEmAbrigo(animal.id, abrigo.id);

      const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
      expect(abrigoAtualizado?.capacidadeOcupada).toBe(1);
    }
  );

  it("marcarComoEmAbrigo lança erro para animal inexistente", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo Y",
      endereco: "Rua Y",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 5,
    });

    await expect(
      animalService.marcarComoEmAbrigo("id-invalido", abrigo.id)
    ).rejects.toThrow(AnimalNaoEncontradoError);
  });

  it("marcarComoComTutor libera a vaga do abrigo do animal", async () => {
    const {animalService, abrigoService} = buildServices();
    const abrigo = await abrigoService.criar({
      nome: "Abrigo D",
      endereco: "Rua D",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 5,
    });
    const animal = await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "grande",
      estadoSaude: "estável",
      rua: "Rua D",
      bairro: "Centro",
      registradoPor: "uid-operador",
      abrigoId: abrigo.id,
    });

    await animalService.marcarComoComTutor(animal.id);

    const atualizado = await animalService.buscarPorId(animal.id);
    expect(atualizado?.status).toBe("com_tutor");
    const abrigoAtualizado = await abrigoService.buscarPorId(abrigo.id);
    expect(abrigoAtualizado?.capacidadeOcupada).toBe(0);
  });

  it("lista todos os animais cadastrados", async () => {
    const {animalService} = buildServices();
    await animalService.cadastrar({
      especie: "cachorro",
      raca: "SRD",
      porte: "medio",
      estadoSaude: "estável",
      rua: "Rua 1",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });
    await animalService.cadastrar({
      especie: "gato",
      raca: "SRD",
      porte: "pequeno",
      estadoSaude: "estável",
      rua: "Rua 2",
      bairro: "Centro",
      registradoPor: "uid-operador",
    });

    const lista = await animalService.listar();
    expect(lista).toHaveLength(2);
  });
});
