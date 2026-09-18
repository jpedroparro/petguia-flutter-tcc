# Módulo de Gestão de Dados e Conhecimento

> "Responsável por armazenar todos os tipos de dados técnicos e de conhecimento
> relacionados à gestão de desastres, incluindo histórico de eventos e lições
> aprendidas." — TCC, seção 2.3.1

## Responsabilidade neste projeto

Na prática, hoje este módulo (`GestaoDadosRepositorio`) só cobre as duas
coleções de referência consumidas pelo Módulo de Análise e Decisão:

- `ruas_cota` (cotas de inundação por rua — 545 ruas reais de Rio do Sul,
  fonte Defesa Civil/imprensa local; `cotaMinima` é oficial, `cotaMaxima`
  quando marcada com `cotaMaximaEstimada: true` é estimativa nossa —
  cotaMinima + 1m, limitada aos 15,3m da maior cheia já registrada
  (jul/1983) — não dado oficial). Sem nenhum caminho de escrita no app em
  produção — é dado de referência só lido; repovoar/atualizar é rodar
  `backend/api/scripts/seed_ruas_cota.mjs` manualmente (idempotente).
- `leituras_rio` (histórico de leituras do nível do rio — sem job de captura
  periódica dedicado; `registrarLeituraSeNecessaria` grava uma leitura nova
  a cada ~15min de tráfego orgânico nas rotas que já buscam o nível ao vivo
  do rio, `/rio` e `/painel-operador`, construindo o histórico usado por
  `calcularTendencia`/`estimarHorasAteInterditar`)

As coleções de negócio (`animais`, `abrigos`, `solicitacoes_reunificacao`,
`solicitacoes_tutoria`, `solicitacoes_resgate`) **não passam por aqui** — cada
service do Módulo de Planejamento da Execução acessa sua própria coleção
direto no Firestore (`this.db.collection(...)` dentro de `abrigo_service.ts`,
`animal_service.ts`, `tutoria_service.ts`, `reunificacao_service.ts`,
`resgate_service.ts`). Perfil e papel de acesso vivem como custom claim no
próprio usuário do Firebase Auth, não como documento à parte — o tipo
`Usuario` e a coleção `usuarios` (de uma versão anterior) foram removidos
do código; se ainda houver documentos órfãos lá no Firestore, são só
resíduo, nada os lê ou escreve mais.

Se um dia isso for centralizado de verdade num único ponto de acesso, é este
módulo que deveria absorver as leituras/escritas hoje espalhadas pelos
services de negócio — não é o caso hoje.
