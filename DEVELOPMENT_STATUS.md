# Estado do desenvolvimento

Última atualização: 2026-09-02

O cooperativo online em modo de teste está planejado em `STEAM_COOP_PLAN.md`. A implementação começou pela prova de compatibilidade MP0, preservando a V2 solo funcional.

### Multiplayer — MP0 concluída

- ambiente confirmado em Linux x86_64 com Godot 4.7.1;
- bundle oficial GodotSteam 4.20.1 / Steamworks SDK 1.64 armazenado localmente em `.tools/` e ignorado pelo Git;
- editor customizado inicia como Godot 4.7.1;
- singleton `Steam` e classe `SteamMultiplayerPeer` confirmados em execução headless;
- Godot do sistema não foi substituído;
- gameplay e cena principal ainda não receberam código de rede;
- próximo passo: MP1, inicialização Steam com App ID de teste `480` e fallback solo.

### Multiplayer — MP1 implementada

- App ID de teste `480` configurado somente no ambiente de desenvolvimento;
- Steam é detectada dinamicamente, preservando execução pelo Godot comum;
- callbacks, Steam ID e nome do usuário são lidos quando a API inicializa;
- painel `F3` mostra conexão ou causa do fallback solo.

### Multiplayer — MP2 implementada, aguardando teste com duas contas

- `L` abre o menu cooperativo e bloqueia os controles enquanto ele está aberto;
- criação de lobby privado/somente para amigos com dois lugares;
- convite pelo overlay Steam;
- entrada automática ao aceitar convite;
- nomes dos membros exibidos no menu;
- metadata identifica jogo, protocolo, estado e host;
- lobby com protocolo incompatível é recusado;
- sair do lobby limpa o estado e retorna ao modo solo;
- sem Steam, o menu permanece informativo e desativa ações online.
- se o overlay estiver indisponível, o menu agora informa a causa em vez de falhar silenciosamente;
- o host pode copiar o ID numérico do lobby e o convidado pode entrar colando esse código, sem depender do overlay;
- uma build enviada ao segundo jogador precisa usar os templates GodotSteam correspondentes ao sistema operacional dele.

### Multiplayer — MP3 implementada, aguardando teste com duas contas

- `NetworkSession` abre o transporte P2P automaticamente a partir do lobby;
- o dono usa `host_with_lobby` e o convidado usa `connect_to_lobby` conforme a API GodotSteam 4.20.1 instalada;
- `multiplayer.multiplayer_peer` recebe o peer Steam sem acoplar a extensão ao modo solo;
- conexão, desconexão, falha e queda do host possuem estado visível no menu cooperativo e no painel `F3`;
- um RPC confiável de ida e volta confirma protocolo e identidade entre os processos;
- sair do lobby fecha o peer e limpa a sessão para permitir novo teste;
- próximo passo após validar o RPC em duas contas: MP4, dois jogadores na cena.

### Multiplayer — MP3 validada em duas contas

- lobby, transporte Steam P2P e RPC de confirmação funcionaram em dois dispositivos;
- os dois processos reconheceram a sessão e a identidade do outro peer.

### Multiplayer — MP4 implementada, aguardando teste com duas contas

- jogador local preserva câmera, entrada, HUD, carteira e interação;
- jogador remoto não processa câmera, entrada, interação ou carregamento;
- host e convidado aparecem em pontos separados na entrada;
- cliente envia movimento ao host, que confirma e retransmite o estado;
- posição, corpo e inclinação da cabeça remotos são interpolados;
- nome Steam e cor laranja distinguem o parceiro remoto;
- desconexão remove a representação remota e o modo solo é restaurado;
- interações, itens e economia ainda não são sincronizados nesta fase.

### Multiplayer — MP4 validada em duas contas

- cada dispositivo controlou somente seu jogador;
- corpo, nome Steam, movimento e rotação remotos apareceram corretamente.

### Multiplayer — MP5 implementada, aguardando teste com duas contas

- itens recebem IDs únicos atribuídos pelo host;
- snapshot inicial e criação/remoção dinâmica replicam itens ao convidado;
- host valida pedidos de pegar, soltar, guardar, retirar e desempacotar;
- somente um peer pode carregar cada item;
- itens no chão, na mão e nos slots exatos das prateleiras são sincronizados;
- caixas compradas pelo host e seu conteúdo desempacotado são replicados;
- painel `F3` mostra total de itens, carregados e guardados;
- compras, carteira, clientes e pedidos permanecem fora desta etapa e entram na MP6.

### Multiplayer — MP5 validada em duas contas

- criação, transporte, disputa, descarte, troca e armazenamento de itens permaneceram consistentes;
- os dois dispositivos observaram o mesmo item e o mesmo slot.

### Multiplayer — MP6 implementada, aguardando teste com duas contas

- saldo, compras e entregas são decididos pelo host e replicados ao convidado;
- compras solicitadas pelo convidado validam distância, catálogo e saldo no host;
- somente o host gera e atualiza clientes durante a sessão;
- cliente recebe réplicas com movimento, fila, pedido, paciência e estado;
- qualquer jogador pode entregar, mas o host valida o item, consome uma vez e paga uma vez;
- saldo, status de entrega, pedidos e contadores aparecem nos dois HUDs;
- o protocolo agora é `farmacia-coop-mp6`.

### Multiplayer — MP6 validada em duas contas

- saldo, compra, entrega, cliente, pedido e pagamento permaneceram iguais nos dois dispositivos;
- entrega feita por qualquer jogador consumiu e recompensou uma única vez.

### Multiplayer — MP7 implementada, aguardando teste com duas contas

- host controla slots, receitas, timers, estabilidade, resultados e cooldown do laboratório;
- qualquer jogador pode inserir/retirar ingredientes e enviar comandos Q/R;
- caldeira e prensa replicam ingredientes, progresso e feedback de operação;
- sucesso cria um único produto compartilhado;
- falha cria uma explosão confirmada pelo host nos dois dispositivos;
- porta do laboratório pode ser acionada por qualquer peer e replica seu movimento;
- protocolo atualizado para `farmacia-coop-mp7`.

### Multiplayer — MP7 validada em duas contas

- fabricação, comandos cooperativos, resultado, explosão e porta permaneceram sincronizados;
- o laboratório pôde ser operado em conjunto sem duplicar o produto final.

### Multiplayer — MP8 implementada, aguardando teste com duas contas

- inspeções são calculadas apenas no host e o policial é replicado ao convidado;
- aviso, porta, aprovação, multa e confisco compartilham um único resultado;
- compras de melhorias solicitadas por qualquer jogador são validadas e cobradas no host;
- melhorias instaladas são replicadas exatamente, mesmo quando os saves locais eram diferentes;
- somente o host grava a progressão compartilhada; o cliente restaura seu save local ao sair;
- protocolo atualizado para `farmacia-coop-mp8`.

### Multiplayer — MP8.1 para até quatro jogadores

- lobby privado agora aceita host e até três convidados;
- quatro posições de entrada e quatro cores identificam o roster;
- distribuição de slots usa IDs ordenados e permanece igual em todas as máquinas;
- economia, itens, clientes, laboratório, inspeções e melhorias continuam sob autoridade do host;
- protocolo atualizado para `farmacia-coop-mp8-4p`.

### Multiplayer — MP9 validada

- item carregado por convidado desconectado é solto uma única vez pelo host;
- jogadores restantes não são teleportados quando o roster diminui;
- host continua jogando após a saída de qualquer convidado;
- queda do host limpa lobby, transporte e réplicas no cliente e abre novamente o menu;
- convidado restaura seu save local ao retornar ao modo solo;
- uma nova sessão pode ser criada sem reiniciar o jogo;
- protocolo atualizado para `farmacia-coop-mp9-4p`.
- correção MP9: entrada de novos peers posiciona somente quem acabou de conectar; host e jogadores já presentes não são movidos.

### Multiplayer — MP10 validada — RC1

- `F3` exibe RTT médio/máximo e contadores de RPCs aceitos/limitados;
- host limita rajadas por peer e categoria sem retirar as validações autoritativas existentes;
- pegar, soltar, estocar, desempacotar, comprar, entregar, fabricar e melhorar possuem proteção contra repetição;
- protocolo atualizado para `farmacia-coop-mp10-4p`;
- validação manual aprovada pelo usuário; versão consolidada como `0.3.0-mp10-rc1`.
- exportação Windows/Steam agora possui script reproduzível com smoke tests e verificação do pacote.

### Multiplayer — RC2: suavização visual do cliente

- snapshots móveis passaram de 10 Hz para 20 Hz;
- clientes e policial interpolam posição/rotação a cada frame;
- clientes remotos agora executam o feedback visual de caminhada;
- porta do laboratório interpola a posição recebida em vez de saltar entre snapshots;
- caldeira mantém autoridade no host, mas interpola timer, cooldown e estabilidade localmente;
- prensa mantém processamento visual e tween do acionamento no cliente;
- primeiro snapshot posiciona NPCs imediatamente, evitando deslocamento desde a origem.

### Menu inicial e acesso por código

- o projeto agora abre em um menu principal com `Jogar` e `Conectar a um host`;
- `Jogar` inicia a farmácia normalmente em modo solo, preservando a criação posterior de lobby pela tecla `L`;
- `Conectar a um host` aceita o código numérico da sala antes de carregar a farmácia;
- a conexão pendente só é iniciada após a cena jogável estar pronta, preservando os componentes de sincronização;
- ao criar ou entrar em uma sala, o código aparece no menu cooperativo dentro do jogo;
- o próprio botão com o código e o botão auxiliar de cópia enviam o número para a área de transferência do sistema.

### Multiplayer — MP1 implementada

- `SteamBootstrap` é carregado antes da cena principal;
- App ID de teste `480` é configurado somente no ambiente de desenvolvimento;
- callbacks Steam são processados quando a inicialização tem sucesso;
- nome, Steam ID e estado aparecem no painel `F3`;
- Godot oficial sem a extensão continua iniciando normalmente em modo solo;
- GodotSteam sem acesso ao cliente também retorna ao modo solo com a causa exibida;
- falta confirmar manualmente a identidade real executando o editor GodotSteam com o cliente Steam aberto.

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
