# Estado do desenvolvimento

Última atualização: 2026-09-02

## Estado atual

As fases 0 a 14 do `AGENTS.md` e as etapas V2.0 a V2.12 foram implementadas. A V2 está tecnicamente completa e pronta para playtest prolongado; os números finais continuam sujeitos às métricas de partidas reais.

O jogo agora funciona como uma operação contínua: compra, estoque espacial, fila de clientes, economia, produção fictícia ativa, explosões, inspeções policiais, melhorias e salvamento formam um único ciclo sem tela obrigatória de vitória.

## V2.0 — Fundação em andamento

- removida da cena principal a condição de vitória por dois pedidos;
- atendimento agora continua indefinidamente;
- `GameProgression` contabiliza pedidos e receita sem bloquear o jogador;
- HUD jogável separado do painel de debug;
- HUD permanece visível quando F3 oculta o debug;
- painel de debug reduzido a FPS, item carregado e alvo do raycast.

## V2.1 — Prateleiras direcionais em andamento

- cada prateleira agora possui seis `ShelfSlot` interativos independentes;
- o raycast seleciona diretamente um espaço vazio ou item armazenado;
- o jogador escolhe onde colocar e qual item retirar;
- encaixe continua preciso por `Marker3D`;
- categorias aceitas continuam sob autoridade da prateleira.

## V2.2 — Lotes e caixas em andamento

- compras agora adquirem lotes configuráveis, inicialmente com duas unidades;
- o preço exibido e cobrado representa o lote completo;
- mercadorias chegam dentro de uma caixa física carregável;
- primeira interação pega a caixa; após transportá-la e soltá-la, uma nova interação desempacota o conteúdo;
- produtos desempacotados preservam `ItemData` e podem ser estocados normalmente.

## V2.3 — Entregas temporizadas em andamento

- compras entram numa fila e chegam após 20 segundos por padrão;
- HUD e terminal exibem a próxima entrega e o tempo restante;
- múltiplas compras podem aguardar sem substituir umas às outras;
- área de entrega aceita inicialmente três caixas;
- se estiver cheia, a próxima entrega fica retida e sinaliza falta de espaço;
- mercadorias retidas nunca são descartadas e chegam assim que uma caixa é removida.

## V2.4 — Fila e paciência em andamento

- até quatro clientes podem permanecer simultaneamente na farmácia;
- quatro marcadores fixos organizam a fila;
- clientes avançam quando alguém atendido ou impaciente vai embora;
- cada pedido ativo possui barra de paciência verde/vermelha;
- após 45 segundos sem atendimento, o cliente reclama, abandona o pedido e sai;
- desistências não pagam recompensa e não interrompem a operação.
- ordem da fila é determinada pela distância física ao balcão, eliminando dependência da ordem interna dos grupos.
- primeiro cliente chega após 30 segundos, dando tempo para comprar e receber o primeiro lote;
- HUD exibe a contagem regressiva de abertura;
- clientes seguintes continuam chegando no intervalo normal de cinco segundos.
- cliente que desiste aplica multa configurável de `$3`, limitada ao saldo disponível;
- HUD contabiliza separadamente pedidos atendidos e perdidos.

## V2.5 — Conteúdo expandido em andamento

- catálogo do fornecedor agora é gerado dinamicamente e possui rolagem;
- quatro medicamentos normais disponíveis;
- cinco ingredientes totalmente fictícios disponíveis;
- quatro produtos fabricados totalmente fictícios;
- quatro receitas de caldeirão, incluindo uma receita com três ingredientes;
- sequência de clientes percorre os oito produtos vendáveis.

## V2.6 — Operação ativa do caldeirão em andamento

- receitas corretas agora exigem alternância entre `Q` e `R`;
- caldeirão mostra direção atual, estabilidade e tempo restante;
- estabilidade cai com o tempo e ao ignorar uma etapa;
- comando correto recupera estabilidade e comando errado penaliza;
- operar exige permanecer próximo da estação;
- chegar a zero ou terminar abaixo do mínimo causa explosão;
- intervalo, estabilidade, ganhos, perdas e tolerância são configuráveis por `RecipeData`.
- acerto agora avança imediatamente para a direção seguinte e reinicia a janela de comando;
- erro mantém a direção atual para permitir correção;
- repetição automática do teclado é ignorada;
- caldeirão inclina na direção pressionada e o texto pisca verde ou vermelho;
- perder a janela aplica penalidade e avança a sequência de forma previsível.

## V2.7 — Porta do laboratório em andamento

- passagem do laboratório possui porta deslizante com colisão física;
- painel fixo ao lado da passagem controla abertura e fechamento;
- estados `OPEN`, `CLOSING`, `CLOSED` e `OPENING` impedem interações concorrentes;
- indicador mostra `LAB ABERTO`, `OCULTANDO`, `LAB OCULTO` ou `ABRINDO`;
- sinal `lab_visibility_changed` informa quando a fábrica está efetivamente escondida;
- método `is_lab_hidden()` fornece consulta direta para a futura inspeção policial.
- painel espelhado no interior permite controlar a porta sem sair do laboratório;
- os dois painéis compartilham estado, texto contextual e bloqueio durante movimento.
- textos dos painéis agora ficam fixos no espaço; o painel interno está girado para leitura pelo lado do laboratório.

## V2.8 — Inspeção policial em andamento

- primeira inspeção ocorre após 75 segundos e as seguintes após 150 segundos;
- HUD emite aviso vermelho 12 segundos antes da chegada;
- policial entra, caminha até o ponto de inspeção e verifica a porta;
- laboratório fechado aprova a inspeção;
- laboratório aberto aplica multa de 20%, limitada entre `$5` e `$30`;
- descoberta confisca 25% dos ingredientes armazenados em prateleiras;
- multa nunca deixa saldo negativo e inspeção nunca encerra a operação;
- policial mostra o resultado, vai embora e reinicia o intervalo.
- rota policial corrigida para o corredor lateral, evitando colisão com o balcão;
- limite de 12 segundos no deslocamento garante que uma obstrução futura não paralise a inspeção.

## V2.9 — Estação secundária em andamento

- adicionada prensa manual no laboratório;
- receita fictícia `Cristal Nimbo + Esporo Dourado → Pastilha Nimbo`;
- ingredientes são inseridos usando o mesmo fluxo de carregamento;
- receita válida exige quatro acionamentos de `E`, com animação de alavanca;
- combinação incompatível pode ser desmontada sem explosão;
- produto final entra na sequência de pedidos de clientes;
- quantidade de acionamentos e intervalo da alavanca ficam expostos no Inspector.

## V2.10 — Progressão e melhorias em andamento

- prensa não começa mais instalada e precisa ser comprada por `$120`;
- Pastilha Nimbo só entra nos pedidos depois da instalação da prensa;
- terminal roxo de melhorias adicionado à farmácia;
- prateleira adicional pode ser instalada por `$80` em posição predeterminada;
- entrega expressa reduz o prazo de 20 para 12 segundos por `$90`;
- compras são permanentes durante a execução e botões passam a indicar `INSTALADO`;
- falha de instalação devolve automaticamente o dinheiro.
- ritmo começa `TRANQUILO`, limitado a dois clientes e intervalo de seis segundos;
- após cinco atendimentos passa a `MOVIMENTADO`, com três clientes e intervalo de 4,5 segundos;
- após doze atendimentos passa a `FRENÉTICO`, com quatro clientes e intervalo de três segundos;
- HUD mostra permanentemente o nível atual de demanda.

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

## V2.11 — Salvamento mínimo

- a progressão é salva automaticamente em `user://pharmacy_save.json`;
- dinheiro, atendimentos, desistências, receita acumulada e melhorias compradas são persistidos;
- prateleira adicional, prensa e entrega expressa são reinstaladas ao carregar;
- o nível de demanda é reconstruído a partir dos atendimentos concluídos;
- clientes, itens soltos, entregas em trânsito, inspeções e fabricação parcial não são salvos;
- saves ausentes, inválidos ou de outra versão voltam com segurança aos valores iniciais.
- em builds de desenvolvimento, `F4` apaga o save e recarrega a farmácia com a progressão inicial;

Teste manual:

1. ganhar ou gastar dinheiro e comprar ao menos uma melhoria;
2. aguardar um segundo para o autosave;
3. fechar e abrir o jogo;
4. confirmar saldo, contadores, ritmo e melhoria instalada;
5. confirmar que a nova execução começa sem clientes antigos, fabricação parcial ou entrega pendente.

## V2.12 — Feedback e balanceamento (pacote de urgência)

- a paciência agora possui segundos restantes e os estados textuais `ATENÇÃO` e `URGENTE!`, sem depender somente da cor;
- cada cliente emite um alerta sonoro uma única vez ao cruzar 50% e 25% de paciência;
- desistência de cliente possui som próprio;
- chegada de mercadoria possui confirmação sonora;
- o primeiro aviso de cada fiscalização possui alerta próprio, sem repetir a cada atualização do contador;
- inspeções aprovadas e descobertas possuem respostas sonoras distintas;
- os valores centrais foram mantidos neste pacote para que o efeito da comunicação possa ser avaliado separadamente do balanceamento numérico.

Instrumentação de playtest:

- `F3` mostra tempo desta execução, distância percorrida e espera média dos pedidos resolvidos;
- registra atendimentos, desistências, dinheiro gasto em mercadoria e explosões;
- registra inspeções aprovadas/fracassadas e tempo até a primeira melhoria;
- as métricas são apenas de diagnóstico da execução atual e não fazem parte do save permanente.

Arquétipos de cliente:

- `COMUM`: 45 segundos de paciência e corpo amarelo-alaranjado;
- `APRESSADO`: 28 segundos, corpo vermelho e aparece a cada terceiro pedido normal;
- `ESPECIAL`: 65 segundos, corpo roxo e solicita produtos fabricados;
- frequências e tempos permanecem exportados no `CustomerSpawner` para balanceamento.

Economia inicial e recuperação:

- o saldo inicial definido pelo designer é `$150`;
- o medicamento normal mais barato custa `$24` por lote e continua acessível no começo;
- o auxílio emergencial agora aparece sempre que o saldo não compra o medicamento normal mais barato;
- o auxílio completa apenas a diferença necessária e seu uso único faz parte do save;
- saves existentes mantêm o saldo atual; use `F4` para testar a nova abertura desde o zero;
- atalhos de desenvolvimento: `F5` adiciona `$100`, `F6` gera um cliente respeitando o limite atual, `F7` agenda fiscalização em cinco segundos e `B` força uma explosão na caldeira (`F8` é reservado pelo editor Godot para parar o jogo).

## Vertical slice atual

O jogador pode:

1. movimentar-se em primeira pessoa pela farmácia e laboratório;
2. interagir com objetos por raycast e prompt contextual;
3. comprar medicamentos e ingredientes no fornecedor;
4. carregar um objeto por vez;
5. guardar e retirar medicamentos das prateleiras;
6. organizar e atender uma fila de clientes comuns, apressados e especiais;
7. guardar ingredientes no laboratório;
8. inserir ingredientes na caldeira;
9. fabricar quatro receitas fictícias operando ativamente a mistura;
10. provocar uma explosão com ingredientes ou operação incorretos;
11. operar uma prensa comprada como melhoria;
12. reagir a inspeções fechando a porta do laboratório;
13. comprar prateleira, prensa e entrega expressa;
14. salvar, fechar e continuar a progressão posteriormente.

Há também um auxílio emergencial único que completa o saldo até o preço do medicamento normal mais barato.

## Auditoria técnica da V2

Em 2026-09-02, uma inicialização isolada da cena principal verificou 11 requisitos estruturais sem falhas:

- fornecedor e recuperação econômica;
- quatro medicamentos normais e cinco ingredientes fictícios;
- quatro receitas de caldeirão;
- quatro posições de fila e capacidade progressiva de clientes;
- porta do laboratório e fiscalização;
- três melhorias compráveis;
- salvamento mínimo;
- métricas de playtest.

Resultado automatizado: `V2_AUDIT checks=11 failures=[]`.

## Livro de receitas

- um livro físico foi adicionado dentro do laboratório;
- a interação abre uma interface rolável e bloqueia os controles do jogador enquanto está aberta;
- as quatro receitas da caldeira e a receita da prensa são lidas diretamente dos `RecipeData`;
- cada entrada mostra ingredientes fictícios, produto resultante e estação utilizada;
- o livro explica os comandos `Q/R` da caldeira e as quatro interações `E` da prensa;
- `Esc` ou o botão `Fechar` devolvem o controle ao jogador.

## Limitação conhecida não bloqueante

O deslocamento físico do knockback da explosão já apresentou baixa percepção em um teste anterior. A explosão agora possui tremor de câmera, flash e som, portanto o impacto é legível, mas a intensidade do deslocamento pode ser recalibrada em uma rodada futura de playtest.

## Smoke test de regressão

1. executar `pharmacy_test.tscn`;
2. comprar e entregar um Remédio Básico;
3. comprar Rubro e Azul;
4. fabricar e entregar o Remédio Experimental;
5. atender clientes até alcançar os ritmos movimentado e frenético;
6. comprar ao menos uma melhoria e confirmar seu efeito;
7. provocar uma receita inválida e confirmar explosão, recuperação e continuidade;
8. testar uma fiscalização com a porta aberta e outra com a porta fechada;
9. fechar e abrir o jogo e confirmar saldo, progresso e melhorias;
10. verificar as métricas com `F3` e o console do Godot por erros.
