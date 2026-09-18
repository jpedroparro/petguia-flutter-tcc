import {
  EnderecoForaDeRioDoSulError,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {
  AbrigoLotadoError,
  AbrigoNaoEncontradoError,
  AbrigoService,
  CapacidadeMenorQueOcupacaoError,
} from "./abrigo_service";
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
 * @param {ValidadorEndereco} validadorEndereco Validador a injetar (padrão:
 *   sempre aceita).
 * @return {AbrigoService} Serviço configurado para o banco de teste.
 */
function buildService(validadorEndereco: ValidadorEndereco = VALIDADOR_OK): AbrigoService {
  return new AbrigoService(db, validadorEndereco);
}

describe("AbrigoService", () => {
  it("cria um abrigo com capacidade ocupada zerada", async () => {
    const service = buildService();

    const abrigo = await service.criar({
      nome: "Abrigo Central",
      endereco: "Rua Principal, 100",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 40,
    });

    expect(abrigo.capacidadeOcupada).toBe(0);
    expect(abrigo.ativo).toBe(true);
    expect(abrigo.nome).toBe("Abrigo Central");
    expect(abrigo.cep).toBe("89160-000");
    expect(abrigo.telefone).toBe("(47) 99999-0000");
  });

  it("rejeita capacidade total menor ou igual a zero", async () => {
    const service = buildService();
    await expect(
      service.criar({
        nome: "Abrigo Inválido",
        endereco: "Rua X",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 0,
      })
    ).rejects.toThrow();
  });

  it("rejeita CEP com quantidade de dígitos inválida", async () => {
    const service = buildService();
    await expect(
      service.criar({
        nome: "Abrigo Inválido",
        endereco: "Rua X",
        cep: "123",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 10,
      })
    ).rejects.toThrow();
  });

  it("rejeita telefone com quantidade de dígitos inválida", async () => {
    const service = buildService();
    await expect(
      service.criar({
        nome: "Abrigo Inválido",
        endereco: "Rua X",
        cep: "89160-000",
        telefone: "123",
        capacidadeTotal: 10,
      })
    ).rejects.toThrow();
  });

  it("rejeita endereço que não existe em Rio do Sul", async () => {
    const service = buildService({existeEmRioDoSul: async () => false});
    await expect(
      service.criar({
        nome: "Abrigo Inválido",
        endereco: "Rua Que Não Existe",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 10,
      })
    ).rejects.toThrow(EnderecoForaDeRioDoSulError);
  });

  it("lista os abrigos criados", async () => {
    const service = buildService();
    await service.criar({
      nome: "Abrigo A",
      endereco: "Rua A",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 10,
    });
    await service.criar({
      nome: "Abrigo B",
      endereco: "Rua B",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 20,
    });

    const lista = await service.listar();
    expect(lista).toHaveLength(2);
  });

  it("atualiza a ocupação de um abrigo", async () => {
    const service = buildService();
    const abrigo = await service.criar({
      nome: "Abrigo C",
      endereco: "Rua C",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 5,
    });

    await service.atualizarOcupacao(abrigo.id, 3);

    const atualizado = await service.buscarPorId(abrigo.id);
    expect(atualizado?.capacidadeOcupada).toBe(3);
  });

  it(
    "rejeita incrementar ocupação acima da capacidade total",
    async () => {
      // Regressão: a checagem de lotação rodava fora da transação de
      // incrementarOcupacao, abrindo uma condição de corrida entre dois
      // cadastros concorrentes pro mesmo abrigo. Agora o teto é reforçado
      // dentro da própria transação.
      const service = buildService();
      const abrigo = await service.criar({
        nome: "Abrigo Cheio",
        endereco: "Rua G",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 1,
      });
      await service.incrementarOcupacao(abrigo.id, 1);

      await expect(
        service.incrementarOcupacao(abrigo.id, 1)
      ).rejects.toThrow(AbrigoLotadoError);

      const atualizado = await service.buscarPorId(abrigo.id);
      expect(atualizado?.capacidadeOcupada).toBe(1);
    }
  );

  it(
    "sob concorrência real, nunca deixa passar mais incrementos que a " +
      "capacidade total",
    async () => {
      // Regressão real do teto: disparar N incrementos ao mesmo tempo (não
      // em sequência) é o único jeito de provar que a checagem roda dentro
      // da transação — em sequência, o teste passaria mesmo com a checagem
      // de fora (o bug original), porque cada chamada já veria o resultado
      // commitado da anterior.
      const service = buildService();
      const abrigo = await service.criar({
        nome: "Abrigo Concorrente",
        endereco: "Rua H",
        cep: "89160-000",
        telefone: "(47) 99999-0000",
        capacidadeTotal: 3,
      });

      const resultados = await Promise.allSettled(
        Array.from({length: 6}, () => service.incrementarOcupacao(abrigo.id, 1))
      );

      const sucesso = resultados.filter((r) => r.status === "fulfilled");
      const falha = resultados.filter((r) => r.status === "rejected");
      expect(sucesso).toHaveLength(3);
      expect(falha).toHaveLength(3);

      const atualizado = await service.buscarPorId(abrigo.id);
      expect(atualizado?.capacidadeOcupada).toBe(3);
    },
    // Contenção real força retries de transação com backoff no emulador —
    // mais lento que os outros testes por design; o timeout padrão de 5s
    // do Jest basta isolado, mas flaqueia com a suíte inteira rodando.
    15000
  );

  it("lança erro ao incrementar ocupação de abrigo inexistente", async () => {
    const service = buildService();
    await expect(
      service.incrementarOcupacao("id-invalido", 1)
    ).rejects.toThrow(AbrigoNaoEncontradoError);
  });

  it("atualiza os dados cadastrais de um abrigo", async () => {
    const service = buildService();
    const abrigo = await service.criar({
      nome: "Abrigo D",
      endereco: "Rua D",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 10,
    });

    const atualizado = await service.atualizar(abrigo.id, {
      nome: "Abrigo D Renomeado",
      telefone: "(47) 98888-1111",
      capacidadeTotal: 15,
    });

    expect(atualizado.nome).toBe("Abrigo D Renomeado");
    expect(atualizado.telefone).toBe("(47) 98888-1111");
    expect(atualizado.capacidadeTotal).toBe(15);
    expect(atualizado.endereco).toBe("Rua D");

    const persistido = await service.buscarPorId(abrigo.id);
    expect(persistido?.nome).toBe("Abrigo D Renomeado");
  });

  it("lança erro ao atualizar abrigo inexistente", async () => {
    const service = buildService();
    await expect(
      service.atualizar("id-invalido", {nome: "X"})
    ).rejects.toThrow(AbrigoNaoEncontradoError);
  });

  it("rejeita reduzir a capacidade total abaixo da ocupação atual", async () => {
    const service = buildService();
    const abrigo = await service.criar({
      nome: "Abrigo E",
      endereco: "Rua E",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 10,
    });
    await service.atualizarOcupacao(abrigo.id, 8);

    await expect(
      service.atualizar(abrigo.id, {capacidadeTotal: 5})
    ).rejects.toThrow(CapacidadeMenorQueOcupacaoError);
  });

  it("rejeita atualizar pra um endereço que não existe em Rio do Sul", async () => {
    const service = buildService();
    const abrigo = await service.criar({
      nome: "Abrigo F",
      endereco: "Rua F",
      cep: "89160-000",
      telefone: "(47) 99999-0000",
      capacidadeTotal: 10,
    });
    const servicoComValidadorFalho = new AbrigoService(db, {
      existeEmRioDoSul: async () => false,
    });

    await expect(
      servicoComValidadorFalho.atualizar(abrigo.id, {endereco: "Rua Inexistente"})
    ).rejects.toThrow(EnderecoForaDeRioDoSulError);
  });
});
