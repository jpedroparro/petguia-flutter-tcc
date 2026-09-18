/**
 * Popula o EMULADOR local (Firestore + Auth) com uma simulação de operação
 * para tirar prints do TCC. Nunca toca em produção: aborta se as variáveis
 * de emulador não estiverem setadas.
 *
 * Uso:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   node seed_simulacao.mjs
 */
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error(
    "ABORTADO: FIRESTORE_EMULATOR_HOST e FIREBASE_AUTH_EMULATOR_HOST " +
    "precisam estar setados. Este script é só para o emulador local."
  );
  process.exit(1);
}

const PROJECT_ID = "tcc-udesc-enchentes";
const EMAIL_EQUIPE = "jpedroparro@gmail.com";
const SENHA_EQUIPE = "petguia123";

initializeApp({projectId: PROJECT_ID});
const db = getFirestore();
const auth = getAuth();

const agora = Date.now();
/** ISO de N horas atrás — espalha os `criadoEm` pra lista não parecer
 * semeada toda no mesmo segundo. */
const horasAtras = (h) => new Date(agora - h * 3600_000).toISOString();

// Os 10 abrigos reais do projeto (espelhados da produção, leitura pública).
const ABRIGOS = [
  ["abrigo-taboao", "Abrigo Temporário - Taboão", "Rua Antônio Packer, Taboão, Rio do Sul - SC", 50, -27.2162254, -49.6136321],
  ["abrigo-canta-galo", "Abrigo Temporário - Canta Galo", "Rua Joaquim Paulino de Souza, Canta Galo, Rio do Sul - SC", 45, -27.2033834, -49.6496343],
  ["abrigo-pamplona", "Abrigo Temporário - Pamplona", "Rua Maiate, Pamplona, Rio do Sul - SC", 55, -27.2234894, -49.6649859],
  ["abrigo-centro", "Abrigo Temporário - Centro", "Rua Vereador Adolfo Frischknecht, Centro, Rio do Sul - SC", 50, -27.2173911, -49.6413241],
  ["abrigo-sumare", "Abrigo Temporário - Sumaré", "Rua Argentina, Sumaré, Rio do Sul - SC", 35, -27.2318189, -49.6489725],
  ["abrigo-santana", "Abrigo Temporário - Santana", "Rua Visconde de Cairu, Santana, Rio do Sul - SC", 30, -27.2136261, -49.6318127],
  ["abrigo-valada", "Abrigo Temporário - Valada São Paulo", "Rua Antônio Dolzani, Valada São Paulo, Rio do Sul - SC", 60, -27.1589615, -49.5969597],
  ["abrigo-bela-alianca", "Abrigo Temporário - Bela Aliança", "Rua Haroldo Leopoldo Swarowsky, Bela Aliança, Rio do Sul - SC", 70, -27.1942741, -49.5891416],
  ["abrigo-bremer", "Abrigo Temporário - Bremer", "Rua Adolfo Bechtold, Bremer, Rio do Sul - SC", 65, -27.1929981, -49.6004153],
  ["abrigo-fundo-canoas", "Abrigo Temporário - Fundo Canoas", "Rua Oscar Strey, Fundo Canoas, Rio do Sul - SC", 40, -27.2046778, -49.6809341],
];

// Vocabulário idêntico ao do formulário do app (cadastrar_animal_pagina.dart),
// pra lista e filtros lerem coerentes nos prints.
const ANIMAIS = [
  // --- resgatados, ainda sem abrigo (é o que entra no ranking de urgência)
  ["Cachorro", "SRD (Vira-lata)", "medio", "Ferido", "Rua Joaquim Paulino de Souza, Canta Galo", -27.2029, -49.6488, true, "Bidu", "(47) 99621-4477", "resgatado", null, 3],
  ["Gato", "SRD (Vira-lata)", "pequeno", "Desidratado", "Rua Tuiuti, Centro", -27.2151, -49.6428, false, null, null, "resgatado", null, 5],
  ["Cachorro", "Pit Bull", "grande", "Estável", "Rua Aristiliano Ramos, Centro", -27.2186, -49.6401, true, "Thor", "(47) 99812-3065", "resgatado", null, 8],
  ["Cachorro", "SRD (Vira-lata)", "pequeno", "Grave", "Rua Maiate, Pamplona", -27.2240, -49.6661, false, null, null, "resgatado", null, 2],
  ["Gato", "Siamês", "pequeno", "Ferido", "Rua Argentina, Sumaré", -27.2325, -49.6494, true, "Mel", "(47) 99704-1188", "resgatado", null, 11],

  // --- já alocados em abrigo
  ["Cachorro", "Labrador", "grande", "Estável", "Rua Vereador Adolfo Frischknecht, Centro", -27.2170, -49.6418, true, "Simba", "(47) 99533-8821", "em_abrigo", "abrigo-centro", 26],
  ["Gato", "Persa", "pequeno", "Estável", "Rua XV de Novembro, Centro", -27.2144, -49.6437, false, null, null, "em_abrigo", "abrigo-centro", 30],
  ["Cachorro", "SRD (Vira-lata)", "medio", "Desidratado", "Rua Antônio Packer, Taboão", -27.2158, -49.6141, false, "Pretinha", null, "em_abrigo", "abrigo-taboao", 34],
  ["Cachorro", "Beagle", "medio", "Estável", "Rua Visconde de Cairu, Santana", -27.2131, -49.6324, true, "Bento", "(47) 99188-2043", "em_abrigo", "abrigo-taboao", 38],
  ["Gato", "SRD (Vira-lata)", "pequeno", "Ferido", "Rua Haroldo Leopoldo Swarowsky, Bela Aliança", -27.1948, -49.5898, false, null, null, "em_abrigo", "abrigo-bela-alianca", 44],
  ["Cachorro", "Shih Tzu", "pequeno", "Estável", "Rua Joaquim Paulino de Souza, Canta Galo", -27.2029, -49.6488, true, "Fiona", "(47) 99450-7719", "em_abrigo", "abrigo-canta-galo", 50],

  // --- devolvidos ao tutor original (vaga liberada, abrigoId nulo)
  ["Cachorro", "Golden Retriever", "grande", "Estável", "Rua Adolfo Bechtold, Bremer", -27.1935, -49.6011, true, "Luna", "(47) 99377-5512", "reunificado", null, 62],
  ["Gato", "Angorá", "pequeno", "Estável", "Rua Visconde de Cairu, Santana", -27.2131, -49.6324, true, "Nina", "(47) 99266-4408", "reunificado", null, 71],

  // --- sob tutor temporário
  ["Cachorro", "Poodle", "pequeno", "Estável", "Rua Oscar Strey, Fundo Canoas", -27.2052, -49.6815, false, "Bolinha", "(47) 99845-2290", "com_tutor", null, 80],
];

async function main() {
  const usuario = await criarUsuarioEquipe();

  const ocupacaoPorAbrigo = {};
  for (const a of ANIMAIS) {
    if (a[11]) ocupacaoPorAbrigo[a[11]] = (ocupacaoPorAbrigo[a[11]] ?? 0) + 1;
  }

  const lote = db.batch();

  for (const [id, nome, endereco, total, lat, lng] of ABRIGOS) {
    lote.set(db.collection("abrigos").doc(id), {
      id,
      nome,
      endereco,
      cep: "89160000",
      telefone: "(47) 3000-0000",
      capacidadeTotal: total,
      capacidadeOcupada: ocupacaoPorAbrigo[id] ?? 0,
      latitude: lat,
      longitude: lng,
      ativo: true,
      criadoEm: horasAtras(96),
    });
  }

  const idsPorStatus = {};
  ANIMAIS.forEach((a, i) => {
    const [especie, raca, porte, estadoSaude, local, lat, lng, coleira,
      nome, telefone, status, abrigoId, h] = a;
    const id = `animal-sim-${String(i + 1).padStart(2, "0")}`;
    (idsPorStatus[status] ??= []).push(id);
    lote.set(db.collection("animais").doc(id), {
      id,
      especie,
      raca,
      porte,
      estadoSaude,
      localizacaoResgate: local,
      cepResgate: null,
      latitudeResgate: lat,
      longitudeResgate: lng,
      comColeira: coleira,
      nomeIdentificacao: nome,
      telefoneContato: telefone,
      fotoUrl: null,
      abrigoId,
      status,
      registradoPor: usuario.uid,
      criadoEm: horasAtras(h),
    });
  });

  // Alertas de resgate urgente (fila da tela "Alertas"): um pendente e um
  // já em atendimento, pra os dois blocos da tela aparecerem no print.
  const alertas = [
    ["Cachorro preso no telhado, água subindo pela Rua Blumenau",
      "Rua Blumenau", "Centro", -27.2159, -49.6445, "Marcos Vieira",
      "(47) 99615-8830", "pendente", 1],
    ["Gato ilhado em cima de muro, não consegue descer",
      "Rua Tiradentes", "Jardim América", -27.2205, -49.6372, "Cláudia Reif",
      "(47) 99521-3374", "em_atendimento", 4],
  ];
  alertas.forEach((s, i) => {
    const [descricaoSituacao, rua, bairro, latitude, longitude, nomeContato,
      telefoneContato, status, h] = s;
    const id = `resgate-sim-${i + 1}`;
    lote.set(db.collection("solicitacoes_resgate").doc(id), {
      id, descricaoSituacao, rua, bairro, latitude, longitude,
      nomeContato, telefoneContato, fotoUrl: null, status,
      criadoEm: horasAtras(h),
    });
  });

  // Fila de reunificação: pedidos do público pra retomar o próprio animal.
  const reunificacoes = [
    ["Ana Souza", "(47) 99612-7745",
      "É minha cachorrinha, tem uma mancha branca no peito.", 6],
    ["Rodrigo Hess", "(47) 99880-1263", null, 9],
  ];
  reunificacoes.forEach((s, i) => {
    const [nomeTutor, telefoneTutor, mensagem, h] = s;
    const id = `reunificacao-sim-${i + 1}`;
    lote.set(db.collection("solicitacoes_reunificacao").doc(id), {
      id,
      animalId: idsPorStatus.em_abrigo[i],
      nomeTutor,
      telefoneTutor,
      mensagem,
      status: "pendente",
      criadoEm: horasAtras(h),
    });
  });

  // Tutoria temporária: dado sensível (CPF/LGPD) — CPFs abaixo são
  // sintéticos, geram dígito verificador válido mas não pertencem a ninguém.
  const tutorias = [
    ["Helena Krause", "1987-04-12", "11144477735", "(47) 99702-5518", 7],
  ];
  tutorias.forEach((s, i) => {
    const [nomeTutor, dataNascimentoTutor, cpfTutor, telefoneTutor, h] = s;
    const id = `tutoria-sim-${i + 1}`;
    lote.set(db.collection("solicitacoes_tutoria").doc(id), {
      id,
      animalId: idsPorStatus.resgatado[i],
      nomeTutor,
      dataNascimentoTutor,
      cpfTutor,
      telefoneTutor,
      status: "pendente",
      criadoEm: horasAtras(h),
    });
  });

  await lote.commit();

  console.log(`Usuário de equipe: ${EMAIL_EQUIPE} / ${SENHA_EQUIPE} (role=admin)`);
  console.log(`Abrigos: ${ABRIGOS.length}`);
  console.log(`Animais: ${ANIMAIS.length}`);
  for (const [status, ids] of Object.entries(idsPorStatus)) {
    console.log(`  ${status}: ${ids.length}`);
  }
  console.log("Ocupação semeada por abrigo:", ocupacaoPorAbrigo);
  console.log(`Alertas de resgate: ${alertas.length}`);
  console.log(`Pedidos de reunificação: ${reunificacoes.length}`);
  console.log(`Pedidos de tutoria: ${tutorias.length}`);
}

/** Cria (ou reaproveita) o usuário de equipe com custom claim role=admin. */
async function criarUsuarioEquipe() {
  let usuario;
  try {
    usuario = await auth.getUserByEmail(EMAIL_EQUIPE);
  } catch {
    usuario = await auth.createUser({
      email: EMAIL_EQUIPE,
      password: SENHA_EQUIPE,
      displayName: "João Pedro",
      emailVerified: true,
    });
  }
  await auth.setCustomUserClaims(usuario.uid, {role: "admin"});
  return usuario;
}

main().catch((erro) => {
  console.error("ERRO:", erro);
  process.exit(1);
});
