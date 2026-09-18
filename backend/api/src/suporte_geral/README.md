# Módulo de Suporte Geral

> "Responsável por prover segurança computacional, configuração do modelo de
> governança, controle de acesso e conformidade com regulamentações de proteção
> de dados." — TCC, seção 2.3.1

> "Configuração do modelo de governança para acesso diferenciado entre Defesa
> Civil, ONGs e população (tutores buscando informações sobre seus animais), em
> conformidade com a LGPD." — TCC, seção 2.3.3

## Responsabilidade neste projeto

- Perfis de acesso da equipe (`admin`, `operador`) via custom claim `role` no
  Firebase Auth. O perfil "público" não é um valor de claim — é
  simplesmente a ausência de token de autenticação, já que o público nunca
  faz login; isso espelha o Ecossistema de Atores (Defesa Civil/ONGs vs.
  população) descrito no TCC.
- Regras de segurança do Firestore (`firestore.rules`) — cada coleção só é
  legível/gravável pelo perfil apropriado.
- Rate limiting nas rotas públicas da API (solicitações de reunificação e
  tutoria, geocodificação).
- Tratamento de dados sensíveis (CPF do tutor) em conformidade com a LGPD: nunca
  expostos nas leituras públicas, apenas visíveis à equipe autenticada.
