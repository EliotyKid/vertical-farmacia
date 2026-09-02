# Estado do desenvolvimento

Última atualização: 2026-09-02

## Estado atual

As fases 0 a 14 do `AGENTS.md` foram implementadas e aprovadas nos smoke tests manuais.

O **vertical slice está completo**: compra, estoque, atendimento, economia, fabricação fictícia, falha com explosão, pedido especial, vitória e reinício funcionam em uma sessão contínua.

O próximo ciclo está especificado em `V2_PLAN.md` como uma operação contínua, sem encerramento por sessão: o jogador lucra, reinveste em prateleiras, equipamentos e conteúdo, e preserva essa progressão em um save mínimo.

## V2.0 — Fundação em andamento

- removida da cena principal a condição de vitória por dois pedidos;
- atendimento agora continua indefinidamente;
- `GameProgression` contabiliza pedidos e receita sem bloquear o jogador;
- HUD jogável separado do painel de debug;
- HUD permanece visível quando F3 oculta o debug;
- painel de debug reduzido a FPS, item carregado e alvo do raycast.

Feedbacks entregues na Fase 13:

- destaque visual de interação;
- animação simples de coleta e posicionamento;
- sons placeholders de interface, compra, entrega e posicionamento;
- popup de dinheiro;
- reação simples dos clientes;
- feedback de progresso da fabricação;
- fumaça, flash e melhoria visual da explosão;
- passos e outros feedbacks baratos e legíveis.

Primeiro pacote visual implementado:

- destaque emissivo no objeto sob a mira;
- animação curta ao coletar e posicionar itens;
- popup positivo/negativo de dinheiro;
- reação visual de sucesso e rejeição do cliente;
- barra 3D de progresso/recuperação da caldeira;
- expansão de fumaça e flash de tela na explosão.

Segundo pacote de feedback implementado:

- passos procedurais com cadência ajustada à velocidade;
- sons placeholders de coleta e posicionamento;
- feedback sonoro de compra, gasto e pagamento;
- alertas distintos para pedido, entrega correta e item rejeitado;
- sons de início, conclusão e falha da fabricação;
- ruído curto e grave para a explosão;
- todos os sons são gerados em memória, sem assets externos.

Pacote final de legibilidade implementado:

- prompt contextual com painel próprio e animação de entrada;
- pulsos coloridos para dinheiro, novo pedido, sucesso e rejeição;
- balanço simples dos clientes durante a caminhada;
- tremor de câmera associado à explosão e ao knockback.

Com estes três pacotes, a **Fase 13 foi implementada e aprovada no smoke test**.

## Fase 14 — Balanceamento e limpeza

Primeira auditoria implementada:

- interação e descarte agora respeitam `controls_enabled`, impedindo ações atrás do menu do fornecedor ou da tela de vitória;
- alvo destacado e prompt são limpos ao bloquear os controles;
- removido o parâmetro de espera do cliente que estava exposto, mas não participava de nenhuma regra;
- saldo inicial reduzido de `$100` para `$40`, suficiente para o ciclo principal e para recuperação após uma falha, mas limitado o bastante para dar relevância às vendas.

Segunda auditoria implementada:

- jogador que cair abaixo de `fall_recovery_height` retorna ao ponto inicial da sessão;
- itens soltos que caírem para fora da graybox retornam ao último ponto seguro;
- velocidade linear e rotação física são zeradas durante a recuperação;
- limites de recuperação ficam expostos no Inspector e não interferem na passagem dos clientes pela entrada.

Teste da recuperação:

1. sair pela entrada até cair do piso e confirmar o retorno do jogador;
2. soltar um item para fora do piso e confirmar seu retorno;
3. pegar o item recuperado e concluir uma interação normal;
4. confirmar que itens guardados em prateleiras ou na caldeira não mudam de posição.

Terceira auditoria implementada:

- removidos da cena jogável o botão, a porta e o boneco usados para validar a Fase 2;
- removidos os itens gratuitos usados para validar a Fase 3;
- as cenas de diagnóstico foram preservadas fora da fase principal;
- o jogador agora precisa usar o fornecedor para iniciar o ciclo econômico;
- instrução inicial do HUD aponta diretamente para o terminal verde;
- todo o ciclo continua viável com `$40`: medicamento `$12`, ingredientes `$15`, receita experimental e caminho opcional de falha.

Teste do fluxo limpo:

1. iniciar a sessão e confirmar que a área de entrega está vazia;
2. comprar o Remédio Básico no terminal verde;
3. estocar, retirar e entregar o medicamento;
4. comprar Rubro e Azul, fabricar e entregar o Remédio Experimental;
5. confirmar que nenhum objeto de diagnóstico interfere no percurso.

### Resultado da Fase 14

- fluxo econômico obrigatório e viável com saldo inicial limitado;
- controles protegidos durante menus e tela de vitória;
- recuperação contra queda do jogador e perda de itens;
- cena principal sem objetos antigos de diagnóstico ou mercadorias gratuitas;
- valores ajustáveis continuam expostos por exports e Resources;
- referências de cenas e Resources auditadas sem dependências quebradas;
- projeto validado no Godot 4.7.1 em carregamento de editor e execução headless.

Teste manual deste pacote:

1. mirar em itens, prateleira, cliente, terminal e caldeira e confirmar o destaque verde;
2. pegar e guardar um item e observar o pequeno efeito de escala;
3. comprar e entregar um item e confirmar os popups `-$` e `+$`;
4. tentar entregar um item errado e depois o correto para conferir as duas reações do cliente;
5. fabricar uma receita válida e observar a barra verde;
6. provocar uma mistura inválida e observar aviso vermelho, fumaça e flash de tela.
7. repetir o ciclo com áudio e verificar se cada ação importante possui som distinto;
8. caminhar e correr para conferir a mudança de cadência dos passos.
9. conferir o balanço do cliente enquanto ele entra e sai;
10. ficar próximo da caldeira durante a falha e confirmar o tremor da câmera.

## Vertical slice atual

O jogador pode:

1. movimentar-se em primeira pessoa pela farmácia e laboratório;
2. interagir com objetos por raycast e prompt contextual;
3. comprar medicamentos e ingredientes no fornecedor;
4. carregar um objeto por vez;
5. guardar e retirar medicamentos das prateleiras;
6. atender um cliente que solicita Remédio Básico;
7. guardar ingredientes no laboratório;
8. inserir ingredientes na caldeira;
9. fabricar Rubro + Azul em Remédio Experimental;
10. provocar uma explosão com uma combinação inválida;
11. atender um cliente especial com o produto fabricado;
12. concluir uma sessão após dois pedidos e reiniciá-la.

Há também um auxílio emergencial único de `$12` para evitar softlock financeiro.

## Limitação conhecida não bloqueante

O deslocamento físico do knockback da explosão já apresentou baixa percepção em um teste anterior. A explosão agora possui tremor de câmera, flash e som, portanto o impacto é legível, mas a intensidade do deslocamento pode ser recalibrada em uma rodada futura de playtest.

## Smoke test de regressão

1. executar `pharmacy_test.tscn`;
2. comprar e entregar um Remédio Básico;
3. comprar Rubro e Azul;
4. fabricar e entregar o Remédio Experimental;
5. confirmar a tela de vitória;
6. reiniciar a sessão;
7. provocar uma receita inválida e confirmar explosão, recuperação e continuidade;
8. verificar o console do Godot por erros.
