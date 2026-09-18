import * as admin from "firebase-admin";
import type {Firestore} from "firebase-admin/firestore";

const PROJECT_ID = "petguia-teste";

let app: admin.app.App | null = null;

/**
 * Inicializa o Admin SDK apontando pro emulador do Firestore — banco real
 * em memória, sem mock, mesma disciplina de testes do sistema web.
 * @return {Firestore} Instância conectada ao emulador.
 */
export function iniciarBancoTeste(): Firestore {
  if (!app) {
    process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
    app = admin.initializeApp({projectId: PROJECT_ID}, "teste");
  }
  return app.firestore();
}

/**
 * Apaga todos os documentos de todas as coleções usadas nos testes.
 * @param {Firestore} db Instância do Firestore de teste.
 * @return {Promise<void>} Nada.
 */
export async function limparBancoTeste(db: Firestore): Promise<void> {
  const colecoes = [
    "usuarios",
    "animais",
    "abrigos",
    "solicitacoes_reunificacao",
    "solicitacoes_tutoria",
    "solicitacoes_resgate",
    "ruas_cota",
    "leituras_rio",
  ];
  for (const nome of colecoes) {
    const snap = await db.collection(nome).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    if (snap.docs.length > 0) await batch.commit();
  }
}
