# PetGuia Enchentes — Frontend

App Flutter (Android/iOS/Web) — camada de Interface do Usuário da
especialização da arquitetura RADIAN para suporte à decisão no resgate
animal em desastres hidrológicos em Rio do Sul/SC. Ver `README.md` na raiz
do repositório para a visão geral do projeto (backend, stack, como rodar).

## Estrutura (`lib/`)

```
autenticacao/   Login da equipe (admin/operador)
portal/         Portal público — consulta, busca por região, solicitações
                (tutoria, reunificação, resgate urgente), sem login
equipe/         Painel interno — animais, abrigos, rio, alertas de
                resgate, tutoria, reunificação (exige login)
rio/            Aba de nível do rio + câmera ao vivo, atualização a cada 30s
mapa/           Mapa dos abrigos com localização marcada
dados/          Modelos, repositórios (Firestore direto + chamadas à API),
                configuração (Cloudinary, base URL da API)
componentes/    Widgets reutilizados entre telas (botão, card, campo, etc.)
tema/           Cores, tipografia
```

Leitura pública (portal) vai direto no Firestore (`PortalRepositorio`,
regras em `backend/firestore.rules`); toda escrita de negócio passa pela
API (`FuncoesRepositorio`) — o app nunca escreve no Firestore diretamente.
