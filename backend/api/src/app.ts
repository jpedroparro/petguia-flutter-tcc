/**
 * Fábrica do app Express do PetGuia Enchentes — API auto-hospedada (Docker)
 * que substitui as Cloud Functions do plano Blaze, mantendo a mesma
 * responsabilidade: única porta de escrita de negócio, Firestore só de
 * leitura para o cliente (ver firestore.rules).
 *
 * Cada bloco de rotas abaixo corresponde a um módulo da parte de Cognição
 * da arquitetura RADIAN (Zanchett, 2025), conforme especializado no TCC
 * (seção 2.3.3). Ver o README.md de cada pasta para a responsabilidade
 * exata e a citação correspondente.
 */

import cors from "cors";
import express, {
  type Express,
  type NextFunction,
  type Request,
  type Response,
} from "express";
import type {Firestore} from "firebase-admin/firestore";
import {montarEstadoRio} from "./analise_decisao/rio_classificacao";
import {UrgenciaService} from "./analise_decisao/urgencia_service";
import {
  AsthonClient,
  type ProvedorTelemetriaRio,
} from "./comunicacao_externa/asthon_client";
import {
  type GeocodificadorEndereco,
  NominatimClient,
} from "./comunicacao_externa/nominatim_client";
import {GestaoDadosRepositorio} from "./gestao_dados/repositorio";
import {AbrigoService} from "./planejamento_execucao/abrigo_service";
import {AnimalService} from "./planejamento_execucao/animal_service";
import {ResgateService} from "./planejamento_execucao/resgate_service";
import {
  ReunificacaoService,
} from "./planejamento_execucao/reunificacao_service";
import {TutoriaService} from "./planejamento_execucao/tutoria_service";
import {
  PainelOperadorService,
} from "./supervisao_execucao/painel_operador_service";
import {
  autenticar,
  exigirAdmin,
  exigirEquipe,
  limiteGlobal,
  limiteRotaPublica,
} from "./suporte_geral/auth";
import {assincrono, tratadorDeErros} from "./suporte_geral/erros";

/**
 * Headers de segurança padrão do projeto (mesmo conjunto do sistema web,
 * Camada 3) — a API não serve HTML, mas isso não custa nada e cobre o
 * caso de alguém abrir uma resposta JSON direto no navegador.
 * @param {Request} req Requisição HTTP.
 * @param {Response} res Resposta HTTP.
 * @param {NextFunction} next Próximo middleware.
 * @return {void} Nada.
 */
function cabecalhosDeSeguranca(
  req: Request, res: Response, next: NextFunction
): void {
  res.set("X-Frame-Options", "DENY");
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "strict-origin-when-cross-origin");
  next();
}

/**
 * Monta o app Express, injetando o Firestore (produção ou emulador) — a
 * mesma disciplina de injeção de dependência dos services, o que permite
 * testar as rotas com supertest contra um banco real de teste.
 * @param {Firestore} db Instância do Firestore.
 * @param {ProvedorTelemetriaRio} provedorTelemetriaRio Fonte de dados do
 *   nível do rio (padrão: Asthon real) — injetável pra testar sem rede.
 * @param {GeocodificadorEndereco} geocodificadorEndereco Geocodificação de
 *   endereço -> coordenadas (padrão: Nominatim real) — injetável pra testar
 *   sem rede.
 * @return {Express} O app Express pronto para `listen` ou para testes.
 */
export function criarApp(
  db: Firestore,
  provedorTelemetriaRio: ProvedorTelemetriaRio = new AsthonClient(),
  geocodificadorEndereco: GeocodificadorEndereco = new NominatimClient()
): Express {
  const app = express();
  // Atrás do proxy reverso do Render (ou qualquer host equivalente) — sem
  // isso, express-rate-limit rejeita o cabeçalho X-Forwarded-For.
  app.set("trust proxy", 1);
  app.use(cors());
  app.use(express.json());
  app.use(cabecalhosDeSeguranca);
  app.use(limiteGlobal);
  app.use(autenticar);

  const abrigoService = new AbrigoService(db);
  const animalService = new AnimalService(db);
  const reunificacaoService = new ReunificacaoService(db);
  const tutoriaService = new TutoriaService(db);
  const resgateService = new ResgateService(db);
  const gestaoDadosRepositorio = new GestaoDadosRepositorio(db);
  const urgenciaService = new UrgenciaService();
  const nominatimClient = new NominatimClient();
  const asthonClient = provedorTelemetriaRio;
  const painelOperadorService = new PainelOperadorService(
    asthonClient, resgateService, gestaoDadosRepositorio, urgenciaService
  );

  app.get("/health", (req, res) => {
    res.status(200).json({data: {ok: true}, error: null});
  });

  // ---------------------------------------------------------------------
  // Módulo de Planejamento da Execução — animais e abrigos
  // ---------------------------------------------------------------------

  app.post("/abrigos", exigirAdmin, assincrono(async (req, res) => {
    const abrigo = await abrigoService.criar(req.body);
    res.status(201).json({data: abrigo, error: null});
  }));

  app.put("/abrigos/:id", exigirAdmin, assincrono(async (req, res) => {
    const abrigo = await abrigoService.atualizar(req.params.id, req.body);
    res.status(200).json({data: abrigo, error: null});
  }));

  app.post("/animais", exigirEquipe, assincrono(async (req, res) => {
    const animal = await animalService.cadastrar({
      ...req.body,
      registradoPor: req.auth!.uid,
    });
    res.status(201).json({data: animal, error: null});
  }));

  app.post(
    "/animais/:id/em-abrigo", exigirEquipe, assincrono(async (req, res) => {
      const abrigoId = req.body.abrigoId;
      if (typeof abrigoId !== "string" || abrigoId.trim() === "") {
        res.status(400).json({data: null, error: "Informe o abrigoId"});
        return;
      }
      await animalService.marcarComoEmAbrigo(req.params.id, abrigoId);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  app.post(
    "/animais/:id/reunificado", exigirEquipe, assincrono(async (req, res) => {
      await animalService.marcarComoReunificado(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  app.post(
    "/animais/:id/com-tutor", exigirEquipe, assincrono(async (req, res) => {
      await animalService.marcarComoComTutor(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  // ---------------------------------------------------------------------
  // Módulo de Comunicação com Sistemas Externos — geocodificação (Nominatim)
  // ---------------------------------------------------------------------

  // Geocodificação reversa (coordenada -> rua/bairro/CEP) — pública: usada
  // pelo "usar minha localização" tanto no cadastro de animal/abrigo
  // (equipe) quanto no pedido de resgate e na busca do portal (público,
  // sem login). Só sugere preenchimento, não é uma ação de negócio —
  // não há motivo pra exigir autenticação aqui.
  app.get("/geo/reverso", assincrono(async (req, res) => {
    const latitude = Number(req.query.lat);
    const longitude = Number(req.query.lon);
    if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
      res.status(400).json({data: null, error: "Informe lat e lon válidos"});
      return;
    }
    const endereco = await nominatimClient.reverso(latitude, longitude);
    res.status(200).json({data: endereco, error: null});
  }));

  // Geocodificação direta (endereço -> coordenadas) — pública, usada pela
  // busca por região do portal (o tutor digita CEP/rua, filtramos animais
  // num raio a partir daí; não é uma ação de negócio da equipe).
  app.get("/geo/geocodificar", assincrono(async (req, res) => {
    const endereco = String(req.query.endereco ?? "").trim();
    if (!endereco) {
      res.status(400).json({data: null, error: "Informe um endereço"});
      return;
    }
    const coordenadas = await geocodificadorEndereco.geocodificar(endereco);
    res.status(200).json({data: coordenadas, error: null});
  }));

  // ---------------------------------------------------------------------
  // Módulo de Análise e Tomada de Decisão — cota do rio e ruas afetadas
  // (leitura pública — mesma informação de segurança que o portal expõe)
  // ---------------------------------------------------------------------

  app.get("/rio", assincrono(async (req, res) => {
    const [nivelAtual, ruas] = await Promise.all([
      asthonClient.buscarNivelAtual(),
      gestaoDadosRepositorio.listarRuasCota(),
    ]);
    if (nivelAtual != null) {
      // Sem bloquear a resposta — não há job de captura periódica dedicado,
      // então o próprio tráfego da aba Rio constrói o histórico usado pra
      // calcular tendência de subida (ver `registrarLeituraSeNecessaria`).
      gestaoDadosRepositorio
        .registrarLeituraSeNecessaria(nivelAtual, "asthon")
        .catch((erro) =>
          console.error("registrarLeituraSeNecessaria (GET /rio) falhou:", erro)
        );
    }
    res.status(200).json({
      data: montarEstadoRio(nivelAtual, ruas),
      error: null,
    });
  }));

  app.get("/rio/estacoes", assincrono(async (req, res) => {
    const estacoes = await asthonClient.buscarEstacoes();
    res.status(200).json({data: estacoes, error: null});
  }));

  // ---------------------------------------------------------------------
  // Módulo de Análise e Tomada de Decisão — ranking de urgência de resgate
  // ---------------------------------------------------------------------

  app.get("/animais/urgencia", exigirEquipe, assincrono(async (req, res) => {
    const [animais, ruas, leituras, nivelAtual] = await Promise.all([
      animalService.listar(),
      gestaoDadosRepositorio.listarRuasCota(),
      gestaoDadosRepositorio.listarLeiturasRio(),
      asthonClient.buscarNivelAtual(),
    ]);
    const ranking = urgenciaService.ranquear(
      animais, ruas, nivelAtual, leituras
    );
    res.status(200).json({data: ranking, error: null});
  }));

  // ---------------------------------------------------------------------
  // Módulo de Planejamento da Execução — reunificação (público solicita,
  // equipe confirma)
  // ---------------------------------------------------------------------

  app.post("/reunificacoes", limiteRotaPublica, assincrono(async (req, res) => {
    const solicitacao = await reunificacaoService.solicitar(req.body);
    res.status(201).json({data: solicitacao, error: null});
  }));

  app.get("/reunificacoes", exigirEquipe, assincrono(async (req, res) => {
    const solicitacoes = await reunificacaoService.listar();
    res.status(200).json({data: solicitacoes, error: null});
  }));

  app.post(
    "/reunificacoes/:id/confirmar", exigirEquipe,
    assincrono(async (req, res) => {
      await reunificacaoService.confirmar(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  app.post(
    "/reunificacoes/:id/recusar", exigirEquipe,
    assincrono(async (req, res) => {
      await reunificacaoService.recusar(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  // ---------------------------------------------------------------------
  // Módulo de Planejamento da Execução — tutoria (público solicita, equipe
  // confirma)
  // ---------------------------------------------------------------------

  app.post("/tutorias", limiteRotaPublica, assincrono(async (req, res) => {
    const solicitacao = await tutoriaService.solicitar(req.body);
    res.status(201).json({data: solicitacao, error: null});
  }));

  app.get("/tutorias", exigirEquipe, assincrono(async (req, res) => {
    const solicitacoes = await tutoriaService.listar();
    res.status(200).json({data: solicitacoes, error: null});
  }));

  app.post(
    "/tutorias/:id/confirmar", exigirEquipe, assincrono(async (req, res) => {
      await tutoriaService.confirmar(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  app.post(
    "/tutorias/:id/recusar", exigirEquipe, assincrono(async (req, res) => {
      await tutoriaService.recusar(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  // ---------------------------------------------------------------------
  // Módulo de Planejamento da Execução — alertas de resgate urgente
  // (público reporta, Defesa Civil/bombeiros logados atendem)
  // ---------------------------------------------------------------------

  app.post("/resgates", limiteRotaPublica, assincrono(async (req, res) => {
    const solicitacao = await resgateService.solicitar(req.body);
    res.status(201).json({data: solicitacao, error: null});
  }));

  app.get("/resgates", exigirEquipe, assincrono(async (req, res) => {
    const solicitacoes = await resgateService.listar();
    res.status(200).json({data: solicitacoes, error: null});
  }));

  app.post(
    "/resgates/:id/atender", exigirEquipe, assincrono(async (req, res) => {
      await resgateService.atender(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  app.post(
    "/resgates/:id/concluir", exigirEquipe, assincrono(async (req, res) => {
      await resgateService.concluir(req.params.id);
      res.status(200).json({data: {ok: true}, error: null});
    })
  );

  // ---------------------------------------------------------------------
  // Módulo de Supervisão da Execução — painel único do operador de campo
  // (rio + ruas bloqueadas + risco da posição atual + alertas mais
  // urgentes/próximos, tudo numa chamada só)
  // ---------------------------------------------------------------------

  app.get("/painel-operador", exigirEquipe, assincrono(async (req, res) => {
    const lat = req.query.lat != null ? Number(req.query.lat) : null;
    const lon = req.query.lon != null ? Number(req.query.lon) : null;
    const origemOperador = (lat != null && lon != null &&
        !Number.isNaN(lat) && !Number.isNaN(lon)) ?
      {latitude: lat, longitude: lon} :
      null;

    const painel = await painelOperadorService.montar(origemOperador);
    res.status(200).json({data: painel, error: null});
  }));

  app.use(tratadorDeErros);

  return app;
}
