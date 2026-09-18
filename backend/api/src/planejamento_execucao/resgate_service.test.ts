import {
  EnderecoForaDeRioDoSulError,
  type ValidadorEndereco,
} from "../comunicacao_externa/nominatim_client";
import {iniciarBancoTeste, limparBancoTeste} from "../gestao_dados/test_db";
import {
  ResgateService,
  SolicitacaoResgateJaConcluidaError,
  SolicitacaoResgateNaoEncontradaError,
  TelefoneContatoInvalidoError,
} from "./resgate_service";
import type {Firestore} from "firebase-admin/firestore";

let db: Firestore;
const VALIDADOR_OK: ValidadorEndereco = {existeEmRioDoSul: async () => true};
const VALIDADOR_FORA: ValidadorEndereco = {existeEmRioDoSul: async () => false};

beforeAll(() => {
  db = iniciarBancoTeste();
});

afterEach(async () => {
  await limparBancoTeste(db);
});

const INPUT_VALIDO = {
  descricaoSituacao: "Cachorro preso em cima de uma árvore, precisa de barco",
  rua: "Rua X",
  bairro: "Centro",
  nomeContato: "Maria",
  telefoneContato: "47999999999",
};

describe("ResgateService", () => {
  it("registra um alerta de resgate pendente", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar(INPUT_VALIDO);

    expect(solicitacao.status).toBe("pendente");
    expect(solicitacao.descricaoSituacao).toBe(INPUT_VALIDO.descricaoSituacao);
    expect(solicitacao.fotoUrl).toBeNull();
  });

  it("guarda a foto quando informada", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar({
      ...INPUT_VALIDO,
      fotoUrl: "https://exemplo.com/foto.jpg",
    });

    expect(solicitacao.fotoUrl).toBe("https://exemplo.com/foto.jpg");
  });

  it("rejeita endereço fora de Rio do Sul", async () => {
    const service = new ResgateService(db, VALIDADOR_FORA);
    await expect(service.solicitar(INPUT_VALIDO)).rejects.toThrow(
      EnderecoForaDeRioDoSulError
    );
  });

  it("rejeita telefone de contato inválido", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    await expect(
      service.solicitar({...INPUT_VALIDO, telefoneContato: "123"})
    ).rejects.toThrow(TelefoneContatoInvalidoError);
  });

  it("lista alertas registrados", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    await service.solicitar(INPUT_VALIDO);
    await service.solicitar(INPUT_VALIDO);

    const lista = await service.listar();
    expect(lista).toHaveLength(2);
  });

  it("atender muda o status para em_atendimento", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar(INPUT_VALIDO);

    await service.atender(solicitacao.id);

    const lista = await service.listar();
    expect(lista[0].status).toBe("em_atendimento");
  });

  it("concluir muda o status para concluido a partir de pendente", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar(INPUT_VALIDO);

    await service.concluir(solicitacao.id);

    const lista = await service.listar();
    expect(lista[0].status).toBe("concluido");
  });

  it("concluir muda status pra concluido a partir de atendimento", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar(INPUT_VALIDO);
    await service.atender(solicitacao.id);

    await service.concluir(solicitacao.id);

    const lista = await service.listar();
    expect(lista[0].status).toBe("concluido");
  });

  it("lança erro ao atender alerta inexistente", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    await expect(service.atender("id-invalido")).rejects.toThrow(
      SolicitacaoResgateNaoEncontradaError
    );
  });

  it("lança erro ao atender ou concluir alerta já concluído", async () => {
    const service = new ResgateService(db, VALIDADOR_OK);
    const solicitacao = await service.solicitar(INPUT_VALIDO);
    await service.concluir(solicitacao.id);

    await expect(service.atender(solicitacao.id)).rejects.toThrow(
      SolicitacaoResgateJaConcluidaError
    );
    await expect(service.concluir(solicitacao.id)).rejects.toThrow(
      SolicitacaoResgateJaConcluidaError
    );
  });
});
