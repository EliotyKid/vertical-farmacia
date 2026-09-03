# MP0 — Registro de compatibilidade

Verificado em 2026-09-02:

```text
Sistema: Linux 7.1.8-arch1-3 x86_64
Projeto: Godot 4.7.1 stable oficial
Steam: GodotSteam 4.20.1
Steamworks SDK: 1.64
Bundle: linux64-g471-s164-gs4201-editor.tar.xz
Editor Steam: Godot 4.7.1 stable custom build
SHA-256: ed15e994911eb84022f3251b5b3b89d3a2d0703fefabfb13ba92d82874f9d590
```

Resultado da prova de carregamento:

```text
Steam singleton: disponível
SteamMultiplayerPeer: disponível
Projeto solo: ainda não alterado pela integração
```

O pacote local fica em `.tools/godotsteam-4.20.1/` e é ignorado pelo Git.

Para abrir o projeto com o editor correto:

```bash
./scripts/run_godotsteam_editor.sh
```

O Godot oficial do sistema continua disponível e não foi substituído.

## Próxima validação

A MP1 inicializa dinamicamente o singleton com o App ID de teste `480`. O fallback foi validado tanto no Godot oficial sem a extensão quanto no GodotSteam sem acesso ao cliente Steam. A identidade real ainda deve ser confirmada manualmente com o cliente Steam aberto no mesmo usuário do editor.

Resultados automatizados:

```text
Godot oficial: Steam indisponível • modo solo
GodotSteam sem cliente acessível: Steam offline • modo solo
```
