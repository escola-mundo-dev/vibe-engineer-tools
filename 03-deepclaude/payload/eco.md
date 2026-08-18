---
description: Mostra se a API DeepSeek está em horário de economia ou de pico agora
allowed-tools: Bash(deepeco:*)
---

## Status da economia (peak/off-peak da DeepSeek)

!`deepeco`

Apresente ao usuário o status acima em uma resposta curta e direta:

1. Diga se estamos em ECONOMIA (metade do preço de pico) ou em HORÁRIO DE PICO
   (preço 2×) — ou, se o regime ainda não começou, que hoje o preço é fixo.
2. Se estamos em pico, diga a hora local em que a economia volta (e quanto falta).
3. Se estamos em economia, diga a hora local do próximo pico — e sugira
   aproveitar agora para tarefas pesadas (refatorações grandes, geração em lote).

Não invente números: use somente o que o comando imprimiu.
