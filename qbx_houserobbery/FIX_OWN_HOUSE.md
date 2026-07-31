# Correção: conflito com interiores de propriedades

## Problema

O `qbx_houserobbery` criava pontos de saída em todos os interiores IPL.
Como o sistema de propriedades usa os mesmos interiores, o prompt de saída
do roubo aparecia dentro da casa do jogador.

Ao usar o prompt, o servidor tentava acessar uma casa de roubo inexistente,
gerando erro em `server/main.lua:144`.

## Correções

- O ponto de saída do roubo só funciona após entrar pelo próprio roubo.
- O servidor valida jogador, índice, casa e interior.
- O índice ativo usa uma chave KVP exclusiva do recurso.
- A chave é removida ao sair.
- Entrar em uma propriedade normal não aciona mais a saída do roubo.

## Instalação

Substitua o recurso e execute:

```cfg
restart qbx_houserobbery
```
