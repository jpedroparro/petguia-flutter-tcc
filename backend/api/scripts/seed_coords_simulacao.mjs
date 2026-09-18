/**
 * Complemento do `seed_simulacao.mjs`: dá latitude/longitude às ruas de
 * `ruas_cota` que os animais/alertas da simulação referenciam.
 *
 * Por que é necessário: `seed_ruas_cota.mjs` grava as 545 ruas com
 * `latitude: null` de propósito (geocodificar 545 ruas violaria a política
 * de uso do Nominatim). Sem coordenada, o Módulo de Análise e Decisão não
 * consegue casar animal/alerta com rua, e a UI mostra "risco não calculado"
 * em todo cartão — o que esconde exatamente a contribuição central do TCC
 * nas capturas de tela.
 *
 * As coordenadas abaixo são APROXIMADAS (ponto representativo da via em Rio
 * do Sul-SC), marcadas com `coordenadaAproximada: true`. A `cotaMinima`
 * oficial de cada rua NÃO é tocada — este script só preenche coordenada de
 * ruas que já existem na coleção; nenhuma rua nova é criada e nenhuma cota
 * é inventada.
 *
 * Uso (só emulador):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   GOOGLE_CLOUD_PROJECT=tcc-udesc-enchentes \
 *   node scripts/seed_coords_simulacao.mjs
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    "ABORTADO: FIRESTORE_EMULATOR_HOST não está setado. " +
    "Este script é só para o emulador local."
  );
  process.exit(1);
}

initializeApp({projectId: "tcc-udesc-enchentes"});
const db = getFirestore();

// Ruas citadas pelos animais e alertas da simulação, com ponto aproximado.
// As chaves são os nomes como `ruas_cota` os guarda: sem o prefixo "Rua".
const COORDENADAS = {
  "maiate": [-27.2240, -49.6661],
  "tuiuti": [-27.2151, -49.6428],
  "aristiliano ramos": [-27.2186, -49.6401],
  "argentina": [-27.2325, -49.6494],
  "vereador adolfo frischknecht": [-27.2170, -49.6418],
  "xv de novembro": [-27.2144, -49.6437],
  "antônio packer": [-27.2158, -49.6141],
  "haroldo leopoldo swarowsky": [-27.1948, -49.5898],
  "joaquim paulino de souza": [-27.2029, -49.6488],
  "adolfo bechtold": [-27.1935, -49.6011],
  "visconde de cairu": [-27.2131, -49.6324],
  "oscar strey": [-27.2052, -49.6815],
  "blumenau": [-27.2159, -49.6445],
  "tiradentes": [-27.2205, -49.6372],
};

async function main() {
  const snap = await db.collection("ruas_cota").get();
  console.log(`${snap.size} ruas na coleção.`);

  const lote = db.batch();
  const encontradas = [];
  const faltando = new Set(Object.keys(COORDENADAS));

  for (const doc of snap.docs) {
    const nome = (doc.data().nome ?? "").toLowerCase().trim();
    const coord = COORDENADAS[nome];
    if (!coord) continue;
    faltando.delete(nome);
    encontradas.push({nome: doc.data().nome, cota: doc.data().cotaMinima});
    lote.update(doc.ref, {
      latitude: coord[0],
      longitude: coord[1],
      coordenadaAproximada: true,
    });
  }

  await lote.commit();

  console.log(`\n${encontradas.length} ruas receberam coordenada:`);
  for (const r of encontradas) {
    console.log(`  ${r.nome} — cota mínima oficial ${r.cota}m`);
  }
  if (faltando.size) {
    console.log(
      `\n${faltando.size} não existem em ruas_cota (nenhuma rua foi criada, ` +
      "nenhuma cota inventada):"
    );
    for (const n of faltando) console.log(`  ${n}`);
  }
}

main().catch((erro) => {
  console.error("ERRO:", erro);
  process.exit(1);
});
