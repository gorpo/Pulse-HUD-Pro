# Status do Projeto - Pulse HUD Pro

Ultima atualizacao: 2026-06-13

Repositorio: https://github.com/gorpo/Pulse-HUD-Pro

Pasta local:

```text
C:\Users\guilh\Desktop\Pulse Hud Pro
```

Ultimo checkpoint antes deste documento:

```text
9a2c531 Build Pulse HUD Pro suite
```

## O que ja foi feito

- Criado projeto separado na Area de Trabalho em `Pulse Hud Pro`.
- Clonado o repositorio `gorpo/Pulse-HUD-Pro`.
- Importada a base pronta do Pulse HUD antigo sem misturar com o outro repo.
- Mantido o HUD classico com FPS, CPU, GPU, RAM, tray icon, hotkey, configurador, instalador, scripts e PresentMon.
- Criado dashboard all-in-one em `src\PulseHudPro.ps1`.
- Compilado `bin\PulseHUDPro.exe` como entrada principal do Pro.
- Adicionado `config\profiles.json` para configurar os modulos novos.
- Adicionado `src\PulseHudProCommon.ps1` com funcoes compartilhadas.
- Adicionado Game Focus Mode em `src\GameFocusMode.ps1`.
- Adicionado Clip Marker em `src\ClipMarker.ps1`.
- Adicionado Ping HUD em `src\PingHud.ps1`.
- Adicionado Game Launcher Profiles em `src\GameLauncherProfiles.ps1`.
- Adicionado Aim Warmup Timer em `src\AimWarmupTimer.ps1`.
- Adicionado OBS Quick Deck em `src\ObsQuickDeck.ps1`.
- Adicionado Thermal Alert em `src\ThermalAlert.ps1`.
- Adicionado Game Notes Overlay em `src\GameNotesOverlay.ps1`.
- Adicionado Brightness Control em `src\BrightnessController.ps1`.
- Brightness Control tenta DDC/CI para monitores externos e WMI para telas internas.
- Brightness Control agora tem dimmer visual universal por overlay para funcionar em qualquer monitor.
- Game Notes Overlay usa a hotkey configurada para mostrar/ocultar.
- Adicionado tema gamer compartilhado em `src\PulseHudProCommon.ps1`.
- Dashboard, Brightness Control, Ping HUD e Game Notes Overlay passaram a usar o tema compartilhado.
- Adicionado Profile Editor em `src\ProfileEditor.ps1`.
- Profile Editor valida JSON por modulo e cria backup antes de salvar.
- Tema compartilhado aplicado tambem em Focus, Launcher, Clip Marker, OBS Quick Deck, Thermal Alert e Aim Warmup Timer.
- Scripts de atalho, instalacao, desinstalacao e release passaram a usar Pulse HUD Pro como produto principal.
- Adicionado Game Library backend em `src\GameLibraryBackend.ps1`.
- Adicionada interface Game Library em `src\GameLibrary.ps1`.
- Game Library varre registro do Windows, atalhos do Menu Iniciar e pastas comuns configuradas em `GameRoots`.
- Game Library salva catalogo em `.runtime\game-library.json`.
- Game Library permite abrir jogo/pasta, remover do catalogo, chamar desinstalador oficial e mover para Lixeira quando a pasta esta dentro de uma GameRoot segura.
- Instalador testado em pasta temporaria dentro de `%LOCALAPPDATA%\Programs`.
- Desinstalador testado removendo pasta temporaria e chave HKCU de uninstall.
- Corrigido dashboard portatil para cada botao abrir seu proprio modulo de forma confiavel.
- Adicionado launcher `Pulse HUD Pro - Portable.bat` na raiz do pacote.
- Launcher `.exe` agora explica que o ZIP precisa ser extraido inteiro quando as pastas do app nao sao encontradas.
- Atualizado `README.md` com abertura, modulos e requisitos.
- Adicionado `docs\pro-suite.md`.
- Corrigido `scripts\PararOverlay.bat` para funcionar em pasta com espacos no caminho.
- Ignorado `.runtime/` no `.gitignore`.
- Smoke test passou abrindo e fechando o overlay classico.
- Checagem de sintaxe PowerShell passou para todos os `.ps1`.
- Commit inicial da suite foi enviado ao GitHub.

## Como abrir

Entrada principal:

```text
bin\PulseHUDPro.exe
```

Modo debug:

```text
scripts\IniciarPulseHudProDebug.bat
```

Config dos modulos:

```text
config\profiles.json
```

Config do HUD classico:

```text
config\settings.json
```

## O que falta validar melhor

- Testar Brightness Control em monitor externo real com DDC/CI ligado no menu do monitor.
- Testar Brightness Control em notebook/tela interna via WMI.
- Testar o dimmer universal em setups com multiplos monitores.
- Melhorar feedback quando um monitor nao aceita controle de brilho.
- Testar Game Focus Mode com jogos reais e confirmar restauracao do plano de energia.
- Adicionar opcao de pausar processos em vez de apenas fechar processos.
- Implementar limpeza real de standby RAM com ferramenta apropriada, se decidirmos incluir uma dependencia.
- Testar Clip Marker dentro de jogo fullscreen/borderless para confirmar hotkey global.
- Melhorar Clip Marker para importar horarios de gravações OBS/ShadowPlay.
- Melhorar Ping HUD com presets por jogo e servidores comuns.
- Melhorar Game Launcher Profiles com editor visual de perfis.
- Melhorar OBS Quick Deck com obs-websocket real para status de gravacao, cena atual e mute.
- Melhorar Thermal Alert com leitura de sensores via LibreHardwareMonitor/OpenHardwareMonitor se aceitarmos dependencia.
- Criar tema visual gamer mais consistente entre todos os modulos.
- Criar instalador/atalho especifico para `PulseHUDPro.exe`.
- Validar instalacao completa em uma maquina limpa ou pasta temporaria.
- Revisar heuristica de varredura com mais bibliotecas reais para reduzir falsos positivos de launchers/apps.

## Planejamento recomendado

1. Fechar base visual gamer:
   - Adicionar icones/indicadores visuais por modulo.
   - Refinar espacamento e tamanhos depois de teste visual manual.

2. Evoluir editor de configuracao:
   - Transformar o editor JSON por modulo em formularios especificos para cada ferramenta.
   - Comecar por Brightness, Ping HUD e Game Focus Mode.
   - Criar formulario especifico para editar GameRoots e opcoes do Game Library.

3. Priorizar modulos mais uteis:
   - Game Focus Mode.
   - Brightness Control.
   - Ping HUD.
   - Clip Marker.

4. Integrar OBS de verdade:
   - Avaliar obs-websocket.
   - Mostrar status real de gravacao/stream.
   - Trocar cenas por API, nao por SendKeys.

5. Preparar release:
   - Atualizar instalador para Pulse HUD Pro.
   - Criar atalhos do Pro.
   - Gerar `release\Pulse-HUD-Pro.zip`.
   - Testar em pasta com espacos e em uma pasta sem permissao especial.

## Comandos uteis

Checar sintaxe:

```powershell
$errors = @(); Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object { $tokens = $null; $parseErrors = $null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null; if ($parseErrors) { $errors += $parseErrors } }; $errors
```

Rodar smoke test:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\SmokeTest.ps1"
```

Recompilar executaveis:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\CompilarExecutaveis.ps1"
```
