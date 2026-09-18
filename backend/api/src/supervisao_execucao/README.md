# Módulo de Supervisão da Execução

> "Suporta os atores no monitoramento e na supervisão da execução do plano,
> permitindo envio de alertas, coleta de feedback e acionamento de
> replanejamentos." — TCC, seção 2.3.1

> "Monitoramento em tempo real das operações de resgate, com painéis
> (dashboards) georreferenciados que exibem localização de animais resgatados,
> disponibilidade de abrigos e status das equipes de campo." — TCC, seção 2.3.3

## Responsabilidade neste projeto

**Painel do operador de campo** (`painel_operador_service.ts`, `GET
/painel-operador`): agrega, numa chamada só, tudo que o operador precisa
enquanto está em deslocamento — nível do rio e ruas atualmente bloqueadas,
se a posição atual dele está numa área que pode alagar (reaproveitando o
`UrgenciaService.avaliarRiscoDoPonto`, do Módulo de Análise e Decisão), e
os alertas de resgate urgente mais urgentes/próximos, ranqueados por risco
da rua com desempate por distância até o operador
(`UrgenciaService.ranquearAlertas`). Nenhuma lógica de risco é duplicada
aqui — este módulo só compõe o que `analise_decisao` já calcula, na forma
que o operador em campo precisa consumir.

## Capacidades do TCC ainda não cobertas por este módulo

- **Contagem de abrigos com vaga / animais por status** (fora do painel
  do operador): ainda calculada no cliente, a partir do `StreamBuilder`
  que já lê `animais`/`abrigos` do Firestore (ver
  `frontend/lib/equipe/abrigos_aba.dart`, `animais_aba.dart`) — sem
  volume que justifique mover pro backend.
- **"Status das equipes de campo" em tempo real**: não implementado —
  o painel do operador mostra o risco/alertas *pra* ele, mas não expõe
  a posição dele *pros outros* (Defesa Civil acompanhando o mapa, por
  exemplo).
- **Coleta de feedback / acionamento de replanejamento**: não
  implementado.
