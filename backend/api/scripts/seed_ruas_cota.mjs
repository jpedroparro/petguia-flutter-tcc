/**
 * Popula/atualiza a coleção `ruas_cota` a partir de
 * `ruas_cota_rio_do_sul.json` (545 ruas reais de Rio do Sul-SC, cota
 * mínima oficial — fonte: imprensa local/Defesa Civil, ver commit que
 * introduziu este script).
 *
 * Existe porque `ruas_cota` não tem nenhum caminho de escrita no app em
 * produção (é dado de referência, só lido) — sem isso commitado, não há
 * como reconstruir a coleção se ela for perdida/resetada.
 *
 * `cotaMaxima` (quando a rua não tem valor oficial) é estimada como
 * `cotaMinima + 1m`, limitada a 15,3m — a maior cheia já registrada em
 * Rio do Sul (jul/1983) — e marcada com `cotaMaximaEstimada: true` pra
 * nunca ser confundida com dado oficial. Sem latitude/longitude: geocodificar
 * 545 ruas violaria a política de uso do Nominatim (não é serviço pra
 * geocodificação em massa) — essas ruas entram na lista "ruas afetadas"
 * mas não no cálculo de "rua mais próxima" de um animal/alerta/operador.
 *
 * Uso:
 *   cd backend/api
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node scripts/seed_ruas_cota.mjs
 *
 * Idempotente: pula ruas cujo nome já existe na coleção (case-insensitive).
 */
import {readFileSync} from "fs";
import {fileURLToPath} from "url";
import {dirname, join} from "path";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const __dirname = dirname(fileURLToPath(import.meta.url));

const COTA_MAXIMA_HISTORICA = 15.3; // Enchente de julho/1983, Rio do Sul-SC.
const MARGEM_ESTIMATIVA = 1.0;
const TAMANHO_LOTE = 400;

initializeApp();
const db = getFirestore();

async function main() {
  const ruas = JSON.parse(
    readFileSync(join(__dirname, "ruas_cota_rio_do_sul.json"), "utf8")
  );
  console.log(`Lidas ${ruas.length} ruas de ruas_cota_rio_do_sul.json.`);

  const existentesSnap = await db.collection("ruas_cota").get();
  const nomesExistentes = new Set(
    existentesSnap.docs.map((d) => (d.data().nome ?? "").toLowerCase())
  );
  console.log(`Já existem ${nomesExistentes.size} ruas cadastradas.`);

  const novas = ruas.filter(
    (r) => !nomesExistentes.has(r.nome.toLowerCase())
  );
  console.log(`${novas.length} ruas novas a gravar.`);

  let gravadas = 0;
  for (let i = 0; i < novas.length; i += TAMANHO_LOTE) {
    const pedaco = novas.slice(i, i + TAMANHO_LOTE);
    const lote = db.batch();
    for (const r of pedaco) {
      const cotaMaxima = Math.min(
        r.cotaMinima + MARGEM_ESTIMATIVA, COTA_MAXIMA_HISTORICA
      );
      const ref = db.collection("ruas_cota").doc();
      lote.set(ref, {
        id: ref.id,
        nome: r.nome,
        cotaMinima: Math.round(r.cotaMinima * 100) / 100,
        cotaMaxima: Math.round(cotaMaxima * 100) / 100,
        cotaMaximaEstimada: true,
        latitude: null,
        longitude: null,
      });
    }
    await lote.commit();
    gravadas += pedaco.length;
    console.log(`Lote gravado: ${gravadas}/${novas.length}`);
  }

  console.log(`\nPronto! ${gravadas} ruas gravadas em ruas_cota.`);
}

main().catch((erro) => {
  console.error("ERRO:", erro);
  process.exit(1);
});
