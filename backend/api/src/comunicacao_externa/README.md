# Módulo de Comunicação com Sistemas Externos

> "Gerencia a recepção e o processamento de dados provenientes de sistemas
> externos, como redes de sensores, sistemas hidrológicos e plataformas
> colaborativas." — TCC, seção 2.3.1

## Responsabilidade neste projeto

Integrações reais com as Entidades Externas da RADIAN:

- **Asthon** (`public.asthon.com.br`) — nível do rio (3 estações), disponibilidade de
  abrigos publicados pela Defesa Civil, câmera ao vivo (snapshot).
- **Nominatim** (OpenStreetMap) — geocodificação/reverse geocoding de endereços em
  Rio do Sul.

Nenhuma lógica de decisão vive aqui — este módulo só busca, normaliza e expõe os
dados brutos para os módulos de Gestão de Dados e de Análise e Decisão.

## Planejado, não implementado nesta versão

- **Overpass API** — malha viária de Rio do Sul, usada pelo módulo de Análise
  e Decisão pra calcular rota evitando ruas bloqueadas. Nenhum código de
  integração existe ainda (ver nota equivalente em
  `analise_decisao/README.md`).
