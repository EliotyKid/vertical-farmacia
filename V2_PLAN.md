# Plano da V2 — Farmácia Frenética

## Visão

A V2 transforma o vertical slice atual em um jogo solo de gerenciamento frenético de farmácia, com organização espacial, produção sob pressão e entregas rápidas inspiradas no ritmo cooperativo de jogos como *Overcooked*.

O jogador deve alternar constantemente entre:

```text
PLANEJAR COMPRAS
	  ↓
RECEBER E ORGANIZAR ESTOQUE
	  ↓
ATENDER VÁRIOS CLIENTES
	  ↓
PRODUZIR ITENS NA FÁBRICA
	  ↓
CONTROLAR RISCOS E INSPEÇÕES
	  ↓
ENTREGAR ANTES DA PACIÊNCIA ACABAR
	  ↓
RECUPERAR O ESTOQUE E REPETIR
```

O caos deve nascer de decisões compreensíveis e conflitos de prioridade, não de controles imprecisos ou informações escondidas.

## Pilares da V2

1. **Pressão de tempo legível** — o jogador sempre entende o que está atrasado e por quê.
2. **Organização física importante** — posição e quantidade do estoque afetam a eficiência.
3. **Produção ativa** — fabricar exige atenção, não apenas esperar uma barra.
4. **Risco com possibilidade de reação** — explosões e inspeções devem ser evitáveis quando o jogador percebe os sinais.
5. **Múltiplas prioridades** — clientes, entregas, máquinas e polícia competem pela atenção.
6. **Recuperação após erros** — falhas custam tempo e dinheiro, mas não devem interromper permanentemente a progressão.
7. **Solo primeiro** — sistemas preparados para responsabilidades claras, sem implementar rede ou cooperação nesta versão.

## Loop principal da V2

```text
COMPRAR
  ↓ prazo de entrega
RECEBER CAIXAS
  ↓ desempacotar e organizar
ESTOCAR PRATELEIRAS / DEPÓSITO
  ↓
CLIENTES ENTRAM E FORMAM FILA
  ↓ paciência diminui
SEPARAR OU FABRICAR PEDIDOS
  ↓
OPERAR CORRETAMENTE AS ESTAÇÕES
  ↓
ESCONDER A FÁBRICA DURANTE INSPEÇÕES
  ↓
ENTREGAR PEDIDOS
  ↓
RECEBER DINHEIRO
  ↓
REABASTECER OU MELHORAR A FARMÁCIA
```

Não existe uma sessão com duração fixa ou tela de vitória por quantidade de pedidos. A farmácia continua funcionando enquanto o jogador desejar. O dinheiro recebido é usado tanto para manter o estoque quanto para comprar melhorias permanentes.

## Progressão contínua

O ciclo de longo prazo da V2 é:

```text
ATENDER MELHOR
	  ↓
ACUMULAR LUCRO
	  ↓
COMPRAR PRATELEIRAS E EQUIPAMENTOS
	  ↓
AUMENTAR CAPACIDADE E VARIEDADE
	  ↓
RECEBER MAIS DEMANDA
	  ↓
REORGANIZAR A OPERAÇÃO
```

Melhorias iniciais previstas:

- comprar uma prateleira adicional;
- aumentar a capacidade da área de ingredientes;
- comprar a estação secundária;
- desbloquear novos medicamentos para o catálogo;
- desbloquear novas receitas fictícias;
- adquirir uma melhoria simples de velocidade ou capacidade de uma máquina;
- comprar uma expansão pequena e predeterminada da área útil, somente depois que o layout básico estiver validado.

Regras da progressão:

- melhorias precisam oferecer uma vantagem concreta ou uma nova responsabilidade;
- preços devem forçar escolha entre estoque imediato e investimento;
- conteúdo novo entra gradualmente para não sobrecarregar o jogador;
- equipamentos são comprados em posições predeterminadas na V2, sem editor livre de construção;
- não usar árvore extensa de habilidades;
- não criar moeda premium ou progressão artificial por tempo real.

## Escopo mínimo

Conteúdo inicial recomendado:

```text
4 medicamentos normais
5 ingredientes fictícios
4 produtos fabricados fictícios
4 receitas válidas
1 caminho genérico de mistura inválida
3 arquétipos de cliente
até 4 clientes simultâneos
2 prateleiras de produtos
1 armazenamento de ingredientes
1 caldeirão
1 estação secundária simples
1 entregador ou área de recebimento
1 policial inspetor
1 porta de ocultação do laboratório
```

Os nomes, ingredientes e processos continuam totalmente fictícios e não devem reproduzir química ou fabricação real de medicamentos ou substâncias controladas.

## Sistemas aprovados para a V2

### Prateleiras com interação espacial

Problema atual:

- itens entram no primeiro espaço disponível;
- itens saem do último espaço ocupado;
- o jogador não escolhe visualmente o produto desejado.

Comportamento desejado:

- cada posição da prateleira possui uma área detectável pelo raycast;
- olhar para um item específico permite retirar exatamente aquele item;
- olhar para um espaço vazio permite colocar o item exatamente ali;
- o destaque mostra claramente o item ou espaço selecionado;
- espaços ocupados e vazios devem continuar fáceis de identificar;
- um item incompatível exibe feedback e não é colocado.

Implementação recomendada:

- criar `ShelfSlot` como componente/nó interativo;
- cada slot guarda no máximo um `WorldItem`;
- `Shelf` coordena capacidade e categorias, mas não escolhe automaticamente o slot;
- o raycast interage diretamente com o `ShelfSlot` atingido;
- manter encaixe por `Marker3D`, evitando posicionamento físico livre impreciso.

Não implementar arraste livre ou física complexa na prateleira nesta etapa.

### Entregas com atraso

Comprar não deve criar o produto imediatamente.

Fluxo:

1. jogador compra no terminal;
2. dinheiro é descontado;
3. a compra entra em uma fila de entregas;
4. a interface mostra o prazo restante;
5. ao terminar o prazo, uma caixa aparece na área de entrega;
6. o jogador transporta e organiza seu conteúdo.

Regras iniciais:

- prazo previsível e visível;
- múltiplos pedidos podem aguardar na fila;
- uma caixa pode representar uma pequena quantidade do mesmo item;
- a área de entrega possui limite legível;
- entrega não desaparece se a área estiver cheia: permanece pendente e avisa o jogador;
- comprar em quantidade deve reduzir viagens ao terminal, mas ocupar dinheiro e espaço.

### Clientes com paciência

Clientes passam a possuir tempo limitado de espera.

Estados sugeridos:

```text
ENTERING
JOINING_QUEUE
WAITING
ORDER_ACTIVE
RECEIVING
SATISFIED
COMPLAINING
LEAVING
```

Regras iniciais:

- até quatro clientes simultâneos;
- cada cliente possui uma barra de paciência visível;
- paciência começa a cair ao entrar na fila;
- pedido correto interrompe a perda de paciência;
- ao chegar a zero, o cliente reclama e vai embora;
- pedido perdido não paga recompensa;
- reclamação produz uma penalidade pequena e compreensível;
- clientes não devem bloquear fisicamente o jogador.

O sistema deve começar com fila fixa por `Marker3D`. Navegação avançada não é necessária.

### Produção ativa no caldeirão

Mesmo com ingredientes corretos, o jogador precisa mexer a mistura corretamente.

Fluxo inicial:

1. inserir ingredientes;
2. iniciar a receita;
3. uma direção ou ritmo de mistura é apresentado;
4. o jogador mantém ou alterna o comando solicitado;
5. uma faixa de estabilidade mostra a qualidade da mistura;
6. concluir dentro da faixa gera o produto;
7. ignorar ou errar demais causa falha e explosão.

Modelo recomendado para o primeiro protótipo:

- interação contínua simples, sem minigame complexo;
- comandos `mexer à esquerda` e `mexer à direita`;
- receita define duração, sequência e tolerância;
- ações corretas aumentam estabilidade;
- ausência de ação e direção errada reduzem estabilidade;
- avisos visuais e sonoros aparecem antes da explosão;
- valores ficam expostos no `RecipeData` ou em um recurso específico de operação.

A mecânica deve testar atenção e alternância de tarefas, não reflexos extremos.

### Polícia e ocultação da fábrica

Um policial inspetor visita a farmácia periodicamente.

Fluxo:

1. sinais antecipados anunciam a inspeção;
2. o policial caminha até a entrada e entra na farmácia;
3. o jogador precisa fechar a porta do laboratório;
4. durante a inspeção, o policial verifica se a área ilegal está visível ou acessível;
5. se estiver escondida, a inspeção termina sem punição;
6. se for descoberta, o jogador recebe multa e perde parte dos ingredientes;
7. o policial vai embora e a operação continua.

Regras de justiça:

- inspeção sempre possui aviso antecipado;
- porta aberta ou fechada deve ser visualmente óbvia;
- o jogo deve explicar claramente a causa da punição;
- multa nunca pode criar um softlock inevitável;
- perda de ingredientes deve ser limitada e previsível;
- o policial não usa combate, perseguição ou armas;
- inspeções não devem ocorrer durante o tutorial ou os primeiros minutos da operação;
- por enquanto, esconder a fábrica significa fechar corretamente a porta, sem sistema complexo de visão ou furtividade.

Arquitetura sugerida:

- `InspectionManager`: agenda e sinaliza inspeções;
- `PoliceInspector`: máquina de estados e deslocamento;
- `LabDoor`: informa se está aberta ou fechada;
- `ContrabandStorage` ou tags fictícias: identifica quais itens podem ser confiscados;
- sistemas se comunicam por sinais, sem o policial procurar e alterar diretamente toda a cena.

## Conteúdo adicional

### Medicamentos normais

Exemplos de nomes fictícios:

- Tônico Sereno;
- Pastilhas Solar;
- Bálsamo Nimbo;
- Gotas Vivas.

### Ingredientes fictícios

- Erva Rubra;
- Pó Azul;
- Seiva Lunar;
- Cristal Nimbo;
- Esporo Dourado.

### Produtos fabricados fictícios

- Xarope de Foco;
- Elixir Nimbo;
- Tônico Experimental;
- Composto Lunar.

### Arquétipos de cliente

- **Comum** — paciência e recompensa médias;
- **Apressado** — pouca paciência e pedido simples;
- **Especial** — pede produto fabricado, espera mais e paga melhor.

Não criar muitos modificadores antes que esses três produzam decisões diferentes.

# Ordem de implementação

## V2.0 — Fundação e regressão

Objetivo: preparar a V1 para evolução sem perder o ciclo existente.

Implementar:

- congelar uma checklist de regressão da V1;
- separar HUD de informações estritamente de debug;
- adicionar um controlador simples de ritmo e demanda;
- centralizar valores de progressão que designers precisam ajustar;
- manter uma cena de teste pequena para componentes isolados.

Definição de pronto:

O ciclo da V1 continua completo e os novos sistemas podem ser ligados gradualmente.

## V2.1 — Prateleiras direcionais

Objetivo: tornar organização e seleção espacialmente significativas.

Implementar:

- componente `ShelfSlot`;
- interação por slot atingido pelo raycast;
- colocação no espaço escolhido;
- retirada do item escolhido;
- destaque individual;
- migração das prateleiras existentes.

Definição de pronto:

O jogador consegue preencher espaços fora de ordem e retirar qualquer produto específico olhando diretamente para ele.

## V2.2 — Quantidade, caixas e estoque

Objetivo: permitir planejamento de abastecimento.

Implementar:

- compra em pequena quantidade;
- caixa de entrega simples;
- desempacotamento;
- contagem clara de conteúdo;
- limite da área de entrega;
- armazenamento de ingredientes compatível com slots direcionais.

Definição de pronto:

O jogador compra lotes, recebe caixas, desempacota e distribui os produtos onde desejar.

## V2.3 — Pedidos com prazo de entrega

Objetivo: fazer compras antecipadas importarem.

Implementar:

- fila de compras pendentes;
- temporizador visível;
- chegada com feedback;
- retenção quando a área está cheia;
- estado vazio, a caminho, entregue e bloqueado.

Definição de pronto:

Comprar exige antecipação e o jogador nunca perde mercadoria por falta de espaço.

## V2.4 — Fila e paciência dos clientes

Objetivo: criar pressão de atendimento.

Implementar:

- até quatro clientes;
- posições fixas de fila;
- barras de paciência;
- reclamação e saída;
- pedidos simultâneos visíveis;
- penalidade inicial simples.

Definição de pronto:

O jogador precisa escolher qual pedido resolver primeiro e clientes impacientes podem desistir sem quebrar a fila.

## V2.5 — Mais itens, receitas e pedidos

Objetivo: criar variedade suficiente para testar organização.

Implementar:

- quatro medicamentos normais;
- cinco ingredientes fictícios;
- quatro receitas;
- quatro produtos fabricados;
- três arquétipos de cliente;
- seleção de pedidos limitada ao conteúdo já desbloqueado e realmente obtível.

Definição de pronto:

Pedidos diferentes exigem encontrar, produzir e organizar itens distintos sem tornar a interface confusa.

## V2.6 — Operação ativa do caldeirão

Objetivo: transformar fabricação em tarefa ativa.

Implementar:

- controles de mistura;
- instrução de direção ou sequência;
- estabilidade;
- tolerância configurável;
- sucesso com ingredientes e operação corretos;
- falha com ingredientes inválidos ou operação ruim;
- possibilidade segura de abandonar ou reiniciar a estação.

Definição de pronto:

Uma receita correta ainda pode falhar por operação ruim, e o jogador entende o erro antes da explosão.

## V2.7 — Porta do laboratório

Objetivo: estabelecer a ação usada para ocultar a fábrica.

Implementar:

- porta interativa;
- estados aberta, fechando, fechada e abrindo;
- bloqueio de passagem consistente;
- indicador visual claro;
- sinal `lab_visibility_changed` ou equivalente.

Definição de pronto:

O jogador consegue abrir e fechar a área sem atravessar a porta ou prender objetos de forma permanente.

## V2.8 — Inspeção policial

Objetivo: adicionar interrupções previsíveis e risco econômico.

Implementar:

- agenda de inspeções;
- aviso antecipado;
- policial com máquina de estados;
- verificação simples da porta;
- resultado aprovado ou descoberta;
- multa;
- confisco limitado de ingredientes;
- intervalo seguro antes da próxima inspeção.

Definição de pronto:

O jogador recebe aviso, pode reagir fechando a fábrica e entende claramente sucesso ou punição.

## V2.9 — Estação secundária

Objetivo: criar alternância de tarefas no laboratório.

Implementar:

- uma máquina simples, como prensa ou embaladora fictícia;
- operação diferente do caldeirão;
- uma ou duas receitas que dependem dela;
- fila ou tempo de processamento legível.

Definição de pronto:

O jogador precisa alternar entre pelo menos duas estações sem que ambas sejam cópias visuais da mesma mecânica.

## V2.10 — Progressão, melhorias e ritmo contínuo

Objetivo: permitir que o jogador reinvista o lucro e expanda gradualmente a operação.

Implementar:

- loja de melhorias simples;
- compra e ativação de novas prateleiras;
- compra da estação secundária;
- desbloqueio gradual de itens e receitas;
- demanda crescente baseada no progresso da farmácia;
- entregas e inspeções mais espaçadas no início;
- recuperação contra falência e softlocks;
- indicadores claros do próximo investimento possível;
- ausência de condição obrigatória de vitória ou duração fixa.

Definição de pronto:

O jogador consegue ganhar dinheiro, escolher uma melhoria, perceber seu efeito na operação e continuar jogando com novas possibilidades e maior demanda.

## V2.11 — Salvamento mínimo

Objetivo: preservar a evolução de uma farmácia que não depende de sessões fechadas.

Salvar:

- dinheiro atual;
- melhorias compradas;
- equipamentos e prateleiras desbloqueados;
- catálogo e receitas liberados;
- nível atual de demanda/progresso;
- configurações essenciais que forem adicionadas.

Não salvar inicialmente:

- posição exata de cada item solto;
- cliente atualmente na fila;
- progresso parcial de uma fabricação;
- entrega a poucos segundos de chegar;
- estado intermediário de uma inspeção.

Ao carregar, a farmácia retorna a um estado operacional seguro, preservando a progressão permanente e reconstruindo estoque transitório apenas se isso for necessário para evitar perda injusta.

Definição de pronto:

Fechar e abrir o jogo preserva dinheiro e melhorias sem restaurar estados temporários quebrados.

## V2.12 — Feedback e balanceamento

Objetivo: tornar prioridades e consequências imediatamente compreensíveis.

Revisar:

- duração de entrega;
- capacidade das prateleiras;
- tamanho dos lotes;
- paciência por cliente;
- quantidade simultânea de clientes;
- tempo de fabricação;
- tolerância da mistura;
- frequência das inspeções;
- multa e confisco;
- distâncias entre estações;
- volume e repetição dos sons;
- acessibilidade das cores e alertas.

Definição de pronto:

O jogo é frenético sem parecer arbitrário e os principais erros podem ser atribuídos a uma decisão compreensível do jogador.

# Valores iniciais para prototipagem

Estes valores são pontos de partida, não metas finais:

```text
Clientes simultâneos: 3, máximo 4
Paciência comum: 45 s
Paciência apressado: 25 s
Paciência especial: 70 s
Prazo de entrega: 20–35 s
Aviso policial: 12 s
Intervalo entre inspeções: 120–180 s
Multa inicial: 20% do dinheiro, com valor mínimo e máximo
Confisco: até 25% dos ingredientes armazenados
Mistura ativa: 6–10 s
Recuperação da explosão: 4–6 s
Janela recomendada de playtest: 20–30 min
Primeira melhoria acessível: 8–12 min de jogo normal
```

Multas, confiscos e falhas precisam respeitar um piso de recuperação para evitar progressão matematicamente impossível.

# Métricas para playtest

Registrar durante testes:

- pedidos concluídos e abandonados;
- tempo médio de espera;
- dinheiro gasto em estoque que não foi usado;
- faltas de produto;
- tempo ocioso das estações;
- explosões por ingredientes errados;
- explosões por operação errada;
- inspeções evitadas e descobertas;
- distância/tempo gasto atravessando a farmácia;
- tempo até cada melhoria;
- escolhas entre reabastecer e investir;
- causa de softlocks ou abandonos antecipados.

# Guardrails da V2

Não implementar nesta versão:

- multiplayer ou rede;
- combate, armas ou perseguição policial;
- simulação realista de polícia;
- química ou síntese real;
- mundo aberto;
- funcionários controlados por IA;
- várias lojas;
- árvore extensa de habilidades ou progressão abstrata;
- economia com aluguel, impostos e empréstimos;
- geração procedural complexa;
- dezenas de receitas;
- arte final;
- sistema completo de inventário em grade.

# Backlog futuro — fora da V2

Estas ideias ficam registradas apenas para discussão futura. **Não fazem parte do escopo da V2.**

## Bancada de preparação

Uma bancada permite deixar temporariamente um item ou caixa enquanto o jogador resolve outra urgência. Isso cria organização espacial sem adicionar inventário.

## Pedidos combinados simples

Alguns clientes pedem dois itens, forçando o jogador a montar uma bandeja antes da entrega. Deve entrar apenas depois que pedidos unitários com fila estiverem claros.

## Telefone de pedidos urgentes

Um telefone toca ocasionalmente com um pedido opcional, curto e valioso. Atender cria risco de sobrecarga; ignorar não deve aplicar punição grave.

## Sujeira após explosão

Explosões deixam uma pequena área que reduz velocidade até ser limpa. Acrescenta consequência espacial, mas exige uma ação e ferramenta de limpeza.

## Máquina superaquecendo

Uma estação abandonada por muito tempo precisa ser desligada antes de falhar. Serve como segunda fonte de atenção além do cliente.

## Reputação simples

Uma única barra sobe com pedidos atendidos e cai com reclamações ou inspeções. Sua função precisará ser definida antes de qualquer implementação.

## Layout compacto revisado

Reposicionar balcão, estoque, laboratório e recebimento para criar rotas curtas com decisões interessantes. Deve ser feito depois que fila, caixas e duas estações existirem.

# Critério de conclusão da V2

A V2 estará completa quando o jogador puder, em uma operação contínua:

- comprar lotes antes de precisar deles;
- aguardar e receber entregas;
- desempacotar e organizar estoque em posições escolhidas;
- atender vários clientes com paciência limitada;
- perder clientes por demora e continuar jogando;
- produzir diferentes produtos fictícios;
- operar corretamente o caldeirão enquanto outras tarefas aguardam;
- causar uma explosão por ingredientes ou operação incorreta;
- reagir a um aviso policial fechando o laboratório;
- sofrer multa e confisco ao falhar numa inspeção;
- recuperar-se de erros sem softlock;
- comprar ao menos uma nova prateleira ou equipamento com o lucro obtido;
- salvar, fechar e retomar sua progressão;
- continuar operando sem uma tela obrigatória de encerramento.

O teste central é:

> O jogador entende suas prioridades, sente pressão para organizar, produzir e entregar, comete erros engraçados sob sobrecarga e deseja continuar melhorando sua farmácia?
