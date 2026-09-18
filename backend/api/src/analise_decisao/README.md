# Módulo de Análise e Tomada de Decisão

> "O núcleo decisional do DSS; converge os dados de todos os atores para
> realizar análises, simular cenários e apoiar a tomada de decisão
> colaborativa." — TCC, seção 2.3.1

> "Definição dos algoritmos de priorização de resgates com base nas cotas de
> inundação do Rio Itajaí-Sul e na situação de risco de cada área mapeada."
> — TCC, seção 2.3.3

## Responsabilidade neste projeto

- **Classificação de risco em tempo real**: nível do rio → `normal` / `atenção`
  / `alerta` / `emergência`; rua → `livre` / `parcial` / `interditada`, a partir
  da cota atual e do dataset de cotas mínimas por rua.
- **Ranking de urgência de resgate** (`urgencia_service.ts`; fecha a lacuna
  que existia na v1 web, que não tinha nenhum algoritmo de priorização):
  cada animal com status `resgatado` recebe uma pontuação de urgência
  combinando (a) o risco da rua onde foi encontrado — `livre`/`parcial`/
  `interditada`, a partir da cota mínima/máxima cadastrada — e (b) o tempo
  restante estimado até a rua ficar intransitável, calculado a partir da
  tendência de subida entre as duas leituras mais recentes do rio. Exposto
  em `GET /animais/urgencia` (só equipe) e consumido pelo painel Flutter,
  que já mostra os resgates ordenados por urgência, com o motivo do
  ranking visível para cada um — não por ordem de cadastro.
- **Avaliação de risco de um ponto qualquer** (`avaliarRiscoDoPonto`) e
  **ranking de alertas de resgate urgente por urgência + proximidade**
  (`ranquearAlertas`): generalização do ranking acima — mesmo núcleo de
  cálculo, reaproveitado pelo Módulo de Supervisão da Execução tanto pra
  ranquear os `SolicitacaoResgate` (animal ainda não capturado) quanto
  pra avisar o próprio operador se a posição dele estiver numa área que
  pode alagar em breve. Ver `GET /painel-operador`
  (`supervisao_execucao/painel_operador_service.ts`).

## Planejado, não implementado nesta versão

Estas duas capacidades fazem parte da especialização original do módulo,
mas não têm nenhum código nesta versão mobile — deixadas aqui porque a
intenção arquitetural continua válida, não porque existem hoje:

- **Cálculo de rota que evita ruas bloqueadas**: grafo viário (Overpass) +
  Dijkstra penalizando vias interditadas. Depende do módulo de Comunicação
  com Sistemas Externos expor a malha viária (ver nota equivalente no
  README daquela pasta).
- **Assistente de IA (Gemini)**: análise crítica de foto + contexto do
  animal, orientação de primeiros socorros — nunca recomendaria ação que
  coloque o operador em risco. Existe uma implementação de referência
  funcional (Gemini via `@google/genai`, rota autenticada com rate limit)
  no protótipo web anterior (`petguia-enchentes-web/src/lib/ia/`), não
  portada para este backend.
