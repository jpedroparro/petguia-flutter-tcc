/**
 * Ponto de entrada do processo — inicializa o Admin SDK contra o Firebase
 * real (Firestore + Auth, ambos no plano gratuito Spark) e sobe o servidor
 * HTTP. Roda tanto direto (`npm start`) quanto dentro do container Docker.
 */

import "dotenv/config";
import {cert, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {criarApp} from "./app";

/**
 * Em produção (Render), a credencial vem em uma variável de ambiente única
 * codificada em base64 — evita colar um JSON multilinha numa caixa de texto
 * do painel, que corrompe as quebras de linha da chave privada. Localmente
 * (Docker ou `npm start`), continua usando o arquivo apontado por
 * `GOOGLE_APPLICATION_CREDENTIALS`.
 */
const credencialBase64 = process.env.GOOGLE_APPLICATION_CREDENTIALS_BASE64;
if (credencialBase64) {
  const credencial = JSON.parse(
    Buffer.from(credencialBase64, "base64").toString("utf-8")
  );
  initializeApp({credential: cert(credencial)});
} else {
  initializeApp();
}

const db = getFirestore();
const app = criarApp(db);

const porta = Number(process.env.PORT) || 8090;
app.listen(porta, () => {
  console.log(`PetGuia Enchentes API ouvindo na porta ${porta}`);
});
