# Pulse HUD Pro

![Pulse HUD Pro logo](assets/logo-256.png)

Suite gamer leve para Windows com Pulse HUD, Focus Mode, Ping HUD, Clip Marker, Game Launcher Profiles, Aim Warmup Timer, OBS Quick Deck, Thermal Alert, Game Notes Overlay e Brightness Control.

O projeto reaproveita a base pronta do Pulse HUD - FPS Overlay e adiciona um painel all-in-one para abrir os novos modulos.

## Abrir

```text
bin\PulseHUDPro.exe
```

Modo portatil, sem instalar:

```text
Pulse HUD Pro - Portable.bat
```

Importante: extraia o ZIP inteiro antes de abrir. O executavel precisa das pastas `src`, `scripts`, `config`, `assets` e `bin` juntas.

Ou, durante desenvolvimento:

```text
scripts\IniciarPulseHudProDebug.bat
```

## Modulos

- Pulse HUD: overlay de FPS, CPU, GPU e RAM.
- Game Focus Mode: detecta jogos, muda plano de energia, fecha processos e aplica prioridade.
- Clip Marker: salva timestamps de highlights em CSV com hotkey.
- Ping HUD: overlay de ping, perda e jitter.
- Game Launcher Profiles: abre jogos com apps auxiliares e prioridade.
- Game Library: varre jogos no Windows, atalhos e pastas comuns; abre, remove do catalogo, chama desinstalador oficial e manda pastas seguras para a Lixeira.
- Aim Warmup Timer: blocos de treino antes de jogar.
- OBS Quick Deck: botoes que enviam hotkeys para o OBS.
- Thermal Alert: alerta uso alto e temperatura ACPI quando o Windows disponibiliza sensor.
- Game Notes Overlay: notas por jogo em overlay discreto.
- Brightness Control: controle de brilho por DDC/CI/WMI e dimmer visual universal por overlay.
- Profile Editor: editor validado para `config\profiles.json`, com backup antes de salvar.

## Configuracao

Os modulos Pro usam:

```text
config\profiles.json
```

O jeito mais seguro de editar e pelo modulo `Profile Editor`, aberto pelo dashboard.

O `Game Library` usa:

```text
.runtime\game-library.json
```

Ele procura jogos no Registro do Windows, atalhos do Menu Iniciar e pastas configuradas em `GameRoots`. A exclusao fisica manda para a Lixeira somente pastas dentro dessas roots; quando houver desinstalador oficial, ele abre o comando de uninstall do proprio Windows.

O HUD classico continua usando:

```text
config\settings.json
```

## HUD classico

O executavel antigo ainda existe:

```text
bin\PulseHUD.exe
```

O configurador do HUD:

```text
bin\PulseHUDConfig.exe
```

## Teste rapido

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\SmokeTest.ps1"
```

## Instalar e release

Criar atalho na Area de Trabalho:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\CriarAtalhoDesktop.ps1"
```

Instalar no usuario atual:

```text
bin\PulseHUDInstall.exe
```

Desinstalar:

```text
bin\PulseHUDUninstall.exe
```

Gerar ZIP:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\CriarReleaseZip.ps1"
```

O ZIP sai em:

```text
release\Pulse-HUD-Pro.zip
```

## PresentMon

FPS real continua documentado em [docs/presentmon.md](docs/presentmon.md).

## Requisitos

- Windows 10 ou 11.
- Windows PowerShell 5.1.
- Para GPU/alertas: contadores `GPU Engine` disponiveis no Windows.
- Para FPS real: PresentMon ou outro processo escrevendo FPS em arquivo.
- Para brilho real em monitor externo: DDC/CI ativado no menu do monitor, quando suportado.
- Para qualquer monitor: use o dimmer universal do Brightness Control.

## Licenca

MIT.
