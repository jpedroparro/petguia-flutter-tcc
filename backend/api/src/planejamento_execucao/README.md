# Módulo de Planejamento da Execução

> "Após a tomada de decisão, suporta o detalhamento operacional, seleção de
> atores, alocação de recursos e gerenciamento de abrigos e operações de
> resgate." — TCC, seção 2.3.1

> "Adaptação das funcionalidades de Gerenciamento de Abrigos & Ajuda
> Humanitária para o contexto animal, incluindo controle de ocupação de
> abrigos temporários e coordenação de veterinários." — TCC, seção 2.3.3

## Responsabilidade neste projeto

- Cadastro e edição de abrigos, com capacidade total/ocupada.
- Alocação de animal a abrigo (transição `resgatado` → `em_abrigo`), rejeitando
  a operação se o abrigo estiver lotado.
- Fluxo de tutoria temporária (`solicitacoes_tutoria`): pedido público →
  confirmação pela equipe → transição para `com_tutor`, liberando a vaga do
  abrigo se havia uma.
- Fluxo de reunificação (`solicitacoes_reunificacao`): mesmo padrão, para
  devolução ao tutor original.
- Alertas de resgate urgente (`solicitacoes_resgate`, `resgate_service.ts`):
  animal que não dá pra simplesmente buscar a pé (preso em árvore, telhado,
  ilhado) — público reporta situação + foto + endereço sem login, vira um
  alerta `pendente` → `em_atendimento` → `concluido` que a equipe atende.
