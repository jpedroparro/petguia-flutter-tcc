# PetGuia Enchentes — Mobile

Reescrita em Flutter + Firebase da especialização da arquitetura RADIAN para
suporte à decisão no resgate animal em desastres hidrológicos em Rio do
Sul/SC (TCC de João Pedro Parro de Sousa, orientador Prof. Dr. Pedro Sidnei
Zanchett). Sucessora do protótipo web em
[petguia-enchentes-web](https://github.com/jpedroparro/petguia-enchentes-web).

## Estrutura

```
frontend/   Interface do Usuário (RADIAN) — app Flutter
backend/    Cognição (RADIAN) — API Express (Docker) + Firestore
  api/src/
    comunicacao_externa/    Módulo de Comunicação com Sistemas Externos
    gestao_dados/           Módulo de Gestão de Dados e Conhecimento
    suporte_geral/          Módulo de Suporte Geral
    analise_decisao/        Módulo de Análise e Tomada de Decisão
    planejamento_execucao/  Módulo de Planejamento da Execução
    supervisao_execucao/    Módulo de Supervisão da Execução
```

Cada pasta em `backend/api/src/` tem um `README.md` citando a
responsabilidade exata descrita no TCC (seção 2.3.1/2.3.3) para esse módulo —
a estrutura de código é rastreável até o texto da arquitetura, não apenas
nomeada por semelhança.

Entidades Externas da RADIAN (fora deste repositório, integradas pelo módulo
de Comunicação com Sistemas Externos): API pública Asthon (nível do rio,
abrigos, câmera), Nominatim/OpenStreetMap (geocodificação). Fotos são
hospedadas no Cloudinary (upload direto do cliente, plano gratuito) — não é
uma Entidade Externa da RADIAN, é infraestrutura de mídia. Overpass API
(malha viária) e Google Gemini (assistente de IA) fazem parte da
especialização original mas não estão implementados nesta versão — ver
`analise_decisao/README.md` e `comunicacao_externa/README.md`.

## Stack

- **Frontend**: Flutter (Android, iOS, Web)
- **Backend**: API Express auto-hospedada (Docker) + Firebase — Firestore e
  Authentication no plano gratuito Spark. A API usa o Admin SDK para
  autenticar (verifica o ID token do Firebase Auth) e escrever no Firestore;
  o cliente nunca escreve direto (ver `firestore.rules`). Cloud Functions
  não é usado — exigiria o plano pago Blaze só por causa do Cloud Run.
- **Projeto Firebase**: `tcc-udesc-enchentes`

## Rodando localmente

```bash
# Frontend
cd frontend
flutter pub get
flutter run

# Backend — testes (contra o emulador real do Firestore, nunca mock)
firebase emulators:start --only firestore,auth &
cd backend/api
npm install
npm test

# Backend — servidor de desenvolvimento
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npm run dev
```

## Rodando o backend em produção (Docker)

1. Baixe uma chave de service account: Firebase Console > Configurações do
   projeto > Contas de serviço > Gerar nova chave privada. Salve como
   `backend/api/service-account.json` (nunca commitar — já está no
   `.gitignore`).
2. `cd backend && docker compose up -d --build`
3. A API sobe em `http://localhost:8090`. No app Flutter, ajuste
   `frontend/lib/dados/api_config.dart` para apontar pro host correto
   (`10.0.2.2:8090` no emulador Android, IP da máquina em dispositivo físico
   na mesma rede).

### Gap de segurança conhecido: sem TLS

A API fala HTTP puro, não HTTPS — diferente das Cloud Functions antigas,
que só existiam atrás de TLS do Google. Em rede local (celular físico na
mesma Wi-Fi) o ID token do Firebase Auth e dados sensíveis (CPF em
`solicitacoes_tutoria`) trafegam em texto claro; alguém na mesma rede
pode capturar o token e reusá-lo como se fosse a equipe. Aceitável pra
demo/desenvolvimento, mas antes de um uso real em campo isso precisa de
TLS — a forma mais simples é colocar um reverse proxy com HTTPS
automático (Caddy, por exemplo) na frente do container, o que exige um
domínio real (não dá pra emitir certificado confiável só pro IP da LAN).
Ficou documentado aqui em vez de resolvido porque a escolha de onde/como
hospedar em produção é decisão do autor do TCC, não algo pra decidir
sozinho durante uma sessão sem supervisão.
