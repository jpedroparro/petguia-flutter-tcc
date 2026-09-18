import type {NextFunction, Request, RequestHandler, Response} from "express";
import criarRateLimit from "express-rate-limit";
import {getAuth} from "firebase-admin/auth";
import {ErroDominio} from "./erro_dominio";

/**
 * Rate limit das rotas públicas de mutação (solicitações de reunificação e
 * tutoria) — não exigem autenticação, então são o alvo natural de abuso.
 * Máx. 10 requisições/minuto por IP, mesmo padrão do sistema web.
 */
export const limiteRotaPublica = criarRateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    data: null,
    error: "Muitas requisições. Tente novamente em instantes.",
  },
});

/**
 * Rate limit global — todas as rotas, autenticadas ou não. As Cloud
 * Functions tinham `maxInstances` para conter abuso de um token vazado ou
 * comprometido; a API self-hosted não tem esse teto automático, então o
 * limite entra aqui. Bem mais folgado que `limiteRotaPublica`.
 */
export const limiteGlobal = criarRateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    data: null,
    error: "Muitas requisições. Tente novamente em instantes.",
  },
});

export interface AuthInfo {
  uid: string;
  role?: string;
}

declare module "express-serve-static-core" {
  interface Request {
    auth?: AuthInfo;
  }
}

/** Erro lançado quando a ação exige um papel que o usuário não tem. */
export class NaoAutorizadoError extends ErroDominio {
  /**
   * @param {string} mensagem Mensagem segura para exibir ao cliente.
   */
  constructor(mensagem: string) {
    super(mensagem, 403);
    this.name = "NaoAutorizadoError";
  }
}

/**
 * Decodifica o ID token do Firebase Auth enviado no header Authorization
 * (Bearer) e anexa `req.auth` — substitui o `request.auth` que as Cloud
 * Functions callable davam de graça. Nunca lança: rotas públicas seguem sem
 * `req.auth` definido, e `exigirEquipe`/`exigirAdmin` decidem se bloqueiam.
 * @param {Request} req Requisição HTTP.
 * @param {Response} res Resposta HTTP.
 * @param {NextFunction} next Próximo middleware.
 * @return {Promise<void>} Nada.
 */
export async function autenticar(
  req: Request, res: Response, next: NextFunction
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    next();
    return;
  }

  try {
    const token = header.slice("Bearer ".length);
    const decoded = await getAuth().verifyIdToken(token);
    req.auth = {uid: decoded.uid, role: decoded.role as string | undefined};
  } catch {
    req.auth = undefined;
  }
  next();
}

/**
 * Confirma que a requisição vem de um usuário autenticado com papel
 * "admin" ou "operador" (custom claim "role") — governança de acesso do
 * Módulo de Suporte Geral.
 * @param {Request} req Requisição HTTP.
 * @param {Response} res Resposta HTTP.
 * @param {NextFunction} next Próximo middleware.
 * @return {void} Nada; encaminha NaoAutorizadoError se não autorizado.
 */
export const exigirEquipe: RequestHandler = (req, res, next) => {
  const papel = req.auth?.role;
  if (!req.auth || (papel !== "admin" && papel !== "operador")) {
    next(
      new NaoAutorizadoError(
        "Apenas a equipe (admin/operador) pode executar esta ação."
      )
    );
    return;
  }
  next();
};

/**
 * Confirma que a requisição vem de um usuário autenticado com papel
 * "admin".
 * @param {Request} req Requisição HTTP.
 * @param {Response} res Resposta HTTP.
 * @param {NextFunction} next Próximo middleware.
 * @return {void} Nada; encaminha NaoAutorizadoError se não autorizado.
 */
export const exigirAdmin: RequestHandler = (req, res, next) => {
  if (!req.auth || req.auth.role !== "admin") {
    next(
      new NaoAutorizadoError("Apenas administradores podem executar esta ação.")
    );
    return;
  }
  next();
};
