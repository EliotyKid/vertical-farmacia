# Plano de implementação — Cooperativo online Steam (modo de teste)

## Objetivo

Adicionar um modo cooperativo simples para **até quatro jogadores** usando Steamworks em ambiente de desenvolvimento, com o App ID de teste `480` (Spacewar), sem publicar o jogo e sem servidor dedicado.

O primeiro resultado jogável deve permitir:

```text
HOST CRIA LOBBY PRIVADO
        ↓
CONVIDA UM AMIGO PELA STEAM
        ↓
SEGUNDO JOGADOR ENTRA
        ↓
OS DOIS APARECEM NA MESMA FARMÁCIA
        ↓
MOVEM, CARREGAM, ESTOCAM, PRODUZEM E ATENDEM JUNTOS
```

O cooperativo não deve substituir o modo solo. Se a Steam não estiver disponível, o jogo deve continuar abrindo em modo solo.

## Decisões técnicas

- Plataforma inicial: Linux e/ou Windows desktop, conforme os computadores usados no teste.
- Engine: Godot 4.7.x.
- Integração: GodotSteam com implementação `SteamMultiplayerPeer` compatível.
- Matchmaking: lobby Steam privado ou somente para amigos.
- Transporte: Steam Networking P2P.
- Topologia: jogador que cria o lobby é o host e autoridade da partida.
- Capacidade atual: quatro jogadores; nenhum “slot” próprio da Steam é necessário.
- App ID de desenvolvimento: `480`.
- Servidor dedicado: fora do escopo.
- Entrada durante partida: fora do primeiro marco; os dois entram antes de começar.
- Migração de host: fora do primeiro marco.

O App ID `480` serve apenas para desenvolvimento. Antes de uma distribuição pública, ele deve ser substituído pelo App ID real do produto.

## Regra de autoridade

O host decide todo estado que altera a farmácia. O cliente envia intenções, e o host valida e aplica o resultado.

| Sistema | Autoridade | Dados sincronizados |
|---|---|---|
| Jogadores | cada jogador envia seu movimento; host confirma estado relevante | posição, rotação e animação visual |
| Itens carregados | host | dono atual, posição lógica, pegar e soltar |
| Prateleiras | host | slot e item armazenado |
| Carteira | host | saldo e diferenças de dinheiro |
| Fornecedor | host | compras, fila e chegada de caixas |
| Clientes | host | spawn, fila, pedido, paciência e saída |
| Caldeirão/prensa | host | ingredientes, operação, progresso e resultado |
| Polícia | host | temporizador, presença e resultado da inspeção |
| Porta do laboratório | host | aberta/fechada |
| Melhorias | host | compras e objetos instalados |
| Save | host | progressão permanente da farmácia |

O cliente nunca deve conceder dinheiro, criar itens ou concluir pedidos diretamente.

## Estrutura proposta

```text
res://multiplayer/
├── steam_bootstrap.gd
├── steam_lobby_manager.gd
├── network_session.gd
├── coop_lobby_ui.tscn
├── coop_lobby_ui.gd
├── network_player_spawner.gd
├── replicated_player.tscn
└── multiplayer_debug_overlay.gd
```

Responsabilidades:

- `SteamBootstrap`: detecta a extensão, inicializa Steam e fornece identidade/nome.
- `SteamLobbyManager`: cria, entra, abandona e recebe convites de lobby.
- `NetworkSession`: instala o `MultiplayerPeer`, acompanha peers e define host/cliente.
- `CoopLobbyUI`: mostra estado da Steam, lobby, jogadores e botões.
- `NetworkPlayerSpawner`: cria um jogador por peer usando o ID como autoridade.
- componentes existentes continuam responsáveis por suas mecânicas; recebem apenas a camada de autoridade/RPC necessária.

## Fase MP0 — Backup, versão e compatibilidade

**Estado: concluída em 2026-09-02 para Linux x86_64.** Consulte `multiplayer/COMPATIBILITY.md`.

Objetivo: confirmar a base antes de alterar gameplay.

Implementar:

- criar uma cópia/versionamento seguro do estado solo funcional;
- registrar versão exata do Godot, GodotSteam, Steamworks SDK e sistemas operacionais;
- confirmar qual build de `SteamMultiplayerPeer` suporta Godot 4.7;
- testar a extensão em um projeto vazio antes de colocá-la na farmácia;
- garantir que bibliotecas nativas não sejam incluídas sem licença/documentação.

Definição de pronto:

O Godot reconhece `Steam` e `SteamMultiplayerPeer` sem erro de carregamento.

## Fase MP1 — Inicialização Steam em modo de teste

**Estado: implementação local concluída; validação manual com o cliente Steam aberto ainda necessária.**

Objetivo: reconhecer o usuário local.

Implementar:

- instalar o pacote compatível do GodotSteam/MultiplayerPeer;
- configurar App ID `480` somente para desenvolvimento;
- inicializar Steam e processar callbacks;
- mostrar nome, Steam ID e estado da conexão em um painel de diagnóstico;
- fallback explícito para modo solo quando Steam não estiver aberta.

Cuidados:

- `steam_appid.txt` deve ficar ao lado do executável usado no teste;
- não distribuir `steam_appid.txt` na versão publicada;
- não assumir que o overlay funciona corretamente dentro do editor: validar também uma build exportada.

Definição de pronto:

Duas contas diferentes executam a build e cada uma vê sua própria identidade Steam.

## Fase MP2 — Lobby Steam

**Estado: implementação local concluída; criação, convite e entrada aguardam validação com duas contas Steam.**

Objetivo: reunir host e convidado sem gameplay sincronizado.

Implementar:

- menu `Solo`, `Criar lobby`, `Convidar amigo` e `Sair do lobby`;
- lobby privado/somente para amigos com limite inicial de dois membros, ampliado posteriormente para quatro;
- metadata com versão do protocolo e estado (`aguardando`/`em jogo`);
- entrada por convite do overlay Steam;
- lista com nome dos dois participantes;
- mensagens claras para lobby cheio, versão incompatível ou falha de conexão.

Definição de pronto:

O host cria um lobby, convida a segunda conta e ambos veem dois participantes.

## Fase MP3 — Transporte e conexão Godot

**Estado: implementação local concluída; conexão P2P e RPC aguardam validação com duas contas Steam.**

Objetivo: transformar o lobby em uma sessão P2P utilizável pela API multiplayer do Godot.

Implementar:

- host cria o `SteamMultiplayerPeer`;
- convidado conecta usando o lobby;
- atribuir peer ao `multiplayer.multiplayer_peer`;
- tratar `peer_connected`, `peer_disconnected`, falha e queda do host;
- painel de debug com peer ID, papel, ping/estado quando disponível;
- protocolo simples de versão para impedir peers incompatíveis.

Definição de pronto:

Os dois processos recebem os eventos de conexão e conseguem trocar uma chamada RPC de teste.

Implementação atual:

- `NetworkSession` cria dinamicamente o `SteamMultiplayerPeer`, preservando o fallback no Godot oficial;
- host usa `host_with_lobby` e convidado usa `connect_to_lobby` automaticamente ao entrar;
- saída do lobby encerra o peer e limpa a lista de conexões;
- conexão, falha, queda do host e desconexão de peer aparecem no menu e no painel `F3`;
- cada novo peer troca uma chamada RPC confiável com protocolo e nome Steam para confirmar o transporte.

## Fase MP4 — Dois jogadores na cena

**Estado: implementação local concluída; visualização e movimento aguardam validação com duas contas Steam.**

Objetivo: navegar juntos pela farmácia.

Implementar:

- substituir o único `Player` fixo por spawn controlado por peer;
- criar dois pontos de spawn;
- câmera e entrada ativas apenas no jogador local;
- corpo remoto com cor/nome Steam visível;
- sincronizar posição e rotação com interpolação;
- impedir que desconexão deixe câmera ou jogador órfão.

Definição de pronto:

Cada conta controla apenas seu personagem e vê o outro se mover suavemente.

Implementação atual:

- o jogador original permanece como personagem local para preservar HUD, carteira e interação existentes;
- cada peer remoto recebe uma instância sem câmera, entrada, raycast ou controle de carregamento;
- host e convidado usam pontos de spawn separados na entrada da farmácia;
- o cliente envia estado ao host e o host retransmite a confirmação usando RPC não confiável ordenado;
- posição, rotação horizontal e inclinação da cabeça usam interpolação no personagem remoto;
- corpo remoto possui cor distinta e nome Steam visível;
- desconexão remove o corpo remoto e encerramento da sessão restaura o jogador solo.

## Fase MP5 — Interações e carregamento

**Estado: implementação local concluída; itens e prateleiras aguardam validação com duas contas Steam.**

Objetivo: provar cooperação física básica.

Implementar:

- cliente solicita interação ao host por ID de rede do alvo;
- host valida distância, disponibilidade e estado;
- sincronizar pegar, carregar, soltar e consumir `WorldItem`;
- garantir dono único para cada item;
- sincronizar caixas de entrega e desempacotamento;
- sincronizar ocupação exata dos `ShelfSlot`.

Conflito esperado:

Se os dois tentarem pegar o mesmo item, o primeiro pedido aceito pelo host vence; o outro recebe feedback de indisponibilidade.

Definição de pronto:

Um jogador entrega um item ao outro indiretamente ao soltá-lo, e ambos veem o mesmo estado de prateleira.

Implementação atual:

- host atribui um ID numérico único a cada `WorldItem` criado durante a sessão;
- convidado recebe snapshot inicial e criação/remoção posterior dos itens;
- pegar, soltar, guardar, retirar e desempacotar são pedidos enviados ao host;
- host valida existência, distância, mão livre, compatibilidade e ocupação do slot;
- primeiro pedido aceito define o dono único do item carregado;
- itens no chão recebem transformações físicas periódicas do host;
- itens carregados acompanham a mão do peer confirmado em ambas as máquinas;
- prateleiras base possuem IDs estáveis e replicam slot exato;
- consumo direto pelo cliente fica bloqueado até pedidos/economia serem sincronizados na MP6.

## Fase MP6 — Loop da farmácia com host autoritativo

**Estado: implementação local concluída; compra, clientes e pagamento aguardam validação com duas contas Steam.**

Objetivo: completar compra e atendimento cooperativos.

Implementar:

- executar `GameProgression`, fornecedor e carteira apenas sob autoridade do host;
- replicar saldo e contadores para o cliente;
- host controla clientes, pedidos, fila e paciência;
- os dois jogadores podem entregar, mas somente o host valida e paga;
- compras feitas pelo cliente tornam-se solicitações validadas pelo host;
- HUD mostra o mesmo pedido e entrega para ambos.

Definição de pronto:

Um jogador compra/estoca e o outro atende; saldo e pedidos permanecem iguais nas duas telas.

Implementação atual:

- carteira do jogador host é a fonte única do saldo compartilhado;
- compras do convidado são solicitações validadas por distância, catálogo e saldo no host;
- fila e temporizador de entregas rodam apenas no host e o status é replicado;
- `CustomerSpawner` roda somente no host durante a sessão;
- clientes recebem IDs, snapshot, posição, rotação, estado, pedido e paciência replicados;
- entrega feita por qualquer peer é validada no host contra o item carregado da MP5;
- item correto é consumido uma vez e recompensa a carteira compartilhada;
- rejeição, conclusão, abandono e contadores de progressão aparecem nos dois HUDs;
- ao encerrar a sessão, o cliente remove as réplicas e recupera seu fluxo solo.

## Fase MP7 — Laboratório cooperativo

**Estado: validada em duas contas Steam em 2026-09-02.**

Objetivo: permitir produção conjunta.

Implementar:

- sincronizar porta, ingredientes e slots das estações;
- host controla receita, estabilidade, timer, produto e explosão;
- qualquer jogador próximo pode executar o comando solicitado da mistura;
- sincronizar prensa, cooldown e produto fabricado;
- reproduzir feedback visual/sonoro localmente a partir do evento confirmado pelo host.

Definição de pronto:

Um jogador busca ingredientes enquanto o outro opera a estação, e ambos observam o mesmo resultado.

Implementação atual:

- IDs de itens da MP5 também identificam ingredientes nos slots das estações;
- inserção, retirada, início da receita e comandos de operação são validados no host;
- caldeira processa timer, sequência Q/R, estabilidade, sucesso e falha somente no host;
- estado, receita, ingredientes, progresso, estabilidade e cooldown são replicados;
- explosão confirmada pelo host é reproduzida nos dois dispositivos;
- produto resultante nasce no host e entra no registro de itens compartilhado;
- prensa aceita inserção/retirada e acionamentos confirmados pelo host;
- porta do laboratório replica estado e posição e pode ser acionada por qualquer peer;
- feedbacks de mexer, prensar, fabricar e explodir são reproduzidos no convidado.

## Fase MP8 — Polícia, melhorias e save

**Estado: implementação local concluída; inspeção, melhorias e persistência aguardam validação com duas contas Steam.**

Objetivo: sincronizar consequências e progressão.

Implementar:

- inspeção calculada somente pelo host;
- porta fechada por qualquer jogador replica para ambos;
- multa e confisco aplicados uma vez;
- compras de melhorias validadas e instanciadas pelo host;
- somente o host carrega e grava o save da farmácia;
- cliente recebe snapshot ao entrar, sem escrever o save local do host;
- ao voltar para solo, restaurar comportamento normal do save.

Definição de pronto:

Inspeção e melhoria produzem exatamente um resultado compartilhado e persistem no save do host.

Implementação atual:

- somente o host avança o temporizador, cria e resolve a inspeção;
- convidado recebe estado, aviso, posição e resultado visual do policial;
- multa e confisco executam uma vez no host e seus efeitos usam os estados compartilhados;
- compras de melhorias feitas por qualquer jogador são validadas por distância, saldo e disponibilidade no host;
- lista exata de melhorias instaladas é replicada, inclusive prateleira, prensa e entrega expressa;
- o cliente suspende gravações durante a sessão e restaura seu próprio save ao voltar para solo;
- o host continua usando o save normal e persiste dinheiro, progresso e melhorias da sessão.

## Fase MP9 — Desconexão e recuperação

**Estado: implementação local concluída; quedas e repetição de lobby aguardam validação com múltiplas contas Steam.**

Objetivo: evitar corrupção ou softlock.

Implementar:

- ao cliente sair, soltar com segurança o item que carregava;
- remover seu personagem;
- host continua a partida em modo solo;
- se o host cair, encerrar a sessão com mensagem clara e voltar ao menu;
- não implementar migração automática de host nesta versão;
- limpar peer e lobby ao sair para permitir nova conexão.

Definição de pronto:

Desconectar qualquer lado não duplica itens, dinheiro ou melhorias e não trava o próximo lobby.

Implementação atual:

- saída de um convidado libera no host o item que estava em sua mão, usando a última transformação válida;
- personagem desconectado é removido sem reposicionar os jogadores restantes;
- entrada de um novo convidado posiciona apenas esse peer, sem teleportar o host ou participantes já ativos;
- o host mantém a fazenda/farmácia e seus sistemas ativos quando um convidado sai;
- queda do host encerra transporte e lobby no convidado, restaura o save local, recarrega a cena limpa e abre o menu cooperativo;
- saída voluntária do convidado também recarrega a cena para eliminar réplicas remanescentes;
- encerramento voluntário do host libera itens de todos os convidados antes de fechar o peer;
- limpeza é idempotente para permitir criar ou entrar em um novo lobby no mesmo processo;
- protocolo atualizado para `farmacia-coop-mp9-4p`.

## Fase MP10 — Teste e balanceamento cooperativo

**Estado: validada pelo usuário em 2026-09-02; cooperativo concluído como RC1.**

Instrumentação implementada:

- ping periódico mede RTT individual e mostra média/máximo no painel `F3`;
- painel contabiliza solicitações aceitas e limitadas pelo host;
- limitador por peer e tipo de ação protege item, prateleira, compra, atendimento, laboratório e melhoria contra rajadas duplicadas;
- o host continua validando distância, posse, saldo, slot e estado depois do limitador;
- protocolo final de teste atualizado para `farmacia-coop-mp10-4p`.
- versão candidata consolidada como `0.3.0-mp10-rc1`.

Smoke test obrigatório:

1. abrir Steam em duas contas diferentes;
2. executar duas builds compatíveis;
3. criar lobby privado e aceitar convite;
4. confirmar dois jogadores e controles locais;
5. comprar uma caixa e desempacotar;
6. entregar um item entre jogadores por meio do mundo;
7. estocar e retirar o mesmo slot;
8. atender um cliente;
9. fabricar uma receita na caldeira;
10. provocar uma explosão;
11. testar porta e inspeção;
12. comprar uma melhoria;
13. desconectar o cliente enquanto carrega um item;
14. confirmar que o host continua jogando;
15. fechar o host, reabrir solo e conferir o save;
16. repetir o lobby após uma desconexão.

Testar adicionalmente:

- latência artificial ou conexão ruim;
- tentativas simultâneas de interação;
- diferenças de FPS;
- overlay e convite em build exportada;
- ausência da Steam;
- lobby cheio;
- versões diferentes do protocolo.

## Extensão MP8.1 — Sessões com quatro jogadores

**Estado: validada pelo usuário em 2026-09-02.**

- lobby privado ampliado para quatro membros;
- quatro pontos de spawn evitam sobreposição na entrada;
- peers recebem slot e cor determinísticos conforme o roster compartilhado;
- todos os sistemas autoritativos existentes aceitam solicitações dos três convidados;
- snapshots de mundo, clientes, laboratório, inspeção e melhorias são enviados a cada peer;
- protocolo atualizado para `farmacia-coop-mp8-4p`, impedindo mistura com builds antigas.

## Fora do primeiro cooperativo

- mais de quatro jogadores;
- servidor dedicado;
- matchmaking público automático;
- migração de host;
- reconexão no meio da partida;
- voz;
- chat;
- cross-play fora da Steam;
- compensação avançada de latência;
- proteção competitiva/anti-cheat;
- Steam Cloud para o save;
- Remote Play Together.

## Riscos principais

### Compatibilidade binária

GodotSteam contém bibliotecas nativas e precisa corresponder à versão/plataforma do Godot. A compatibilidade com Godot 4.7 deve ser comprovada na MP0 antes de integrar o projeto principal.

### Conversão de autoridade

Os sistemas atuais foram construídos para uma única instância local. Adicionar RPC diretamente em todos os métodos tende a criar duplicação. Cada fase deve primeiro separar “pedido de ação” de “resultado confirmado pelo host”.

### Identidade de objetos

Itens criados dinamicamente precisam de IDs de rede estáveis. Caminhos de nós e nomes gerados automaticamente não devem ser usados como identidade permanente.

### Save e duplicação

Somente o host salva. Salvar em ambos os computadores pode duplicar ou divergir dinheiro, estoque e melhorias.

### App ID público de teste

Muitos projetos usam o `480`. Lobbies devem ser privados e filtrados por versão/identificador próprio para reduzir colisões durante o desenvolvimento.

## Critério de conclusão

O cooperativo de teste estará pronto quando duas contas Steam puderem entrar em um lobby privado, controlar personagens separados e completar juntas o ciclo:

```text
COMPRAR → RECEBER → ESTOCAR → ATENDER → FABRICAR →
REAGIR À POLÍCIA → RECEBER DINHEIRO → SALVAR NO HOST
```

O estado deve permanecer consistente após conflitos de interação e desconexão do cliente.

## Ordem de execução

```text
MP0 Compatibilidade
 ↓
MP1 Steam inicializada
 ↓
MP2 Lobby
 ↓
MP3 Peer/RPC de teste
 ↓
MP4 Dois jogadores
 ↓
MP5 Itens e prateleiras
 ↓
MP6 Economia e clientes
 ↓
MP7 Laboratório
 ↓
MP8 Polícia, melhorias e save
 ↓
MP9 Desconexão
 ↓
MP10 Playtest
```
