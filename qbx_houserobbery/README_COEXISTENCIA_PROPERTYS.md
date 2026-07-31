# Integração qbx_houserobbery + Propertys

Correções:

- Ignora jogadores com `LocalPlayer.state.insideProperty`.
- Não mostra o prompt de saída do roubo dentro de propriedade própria.
- Valida o índice da casa no servidor.
- Impede acesso a `sharedConfig.houses[index]` quando o índice não existe.
- Limpa a sessão visual de roubo ao entrar pelo `propertys`.
