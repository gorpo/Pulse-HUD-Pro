# Pulse HUD Pro

![Pulse HUD Pro logo](assets/logo-256.png)

Suite gamer leve para Windows com Pulse HUD, Focus Mode, Ping HUD, Clip Marker, Game Launcher Profiles, Aim Warmup Timer, OBS Quick Deck, Thermal Alert, Game Notes Overlay e Brightness Control.

O projeto reaproveita a base pronta do Pulse HUD - FPS Overlay e adiciona um painel all-in-one para abrir os novos modulos.

## Abrir

```text
bin\PulseHUDPro.exe
```

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
- Aim Warmup Timer: blocos de treino antes de jogar.
- OBS Quick Deck: botoes que enviam hotkeys para o OBS.
- Thermal Alert: alerta uso alto e temperatura ACPI quando o Windows disponibiliza sensor.
- Game Notes Overlay: notas por jogo em overlay discreto.
- Brightness Control: controle de brilho por DDC/CI em monitores externos e WMI em telas internas.

## Configuracao

Os modulos Pro usam:

```text
config\profiles.json
```

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

## PresentMon

FPS real continua documentado em [docs/presentmon.md](docs/presentmon.md).

## Requisitos

- Windows 10 ou 11.
- Windows PowerShell 5.1.
- Para GPU/alertas: contadores `GPU Engine` disponiveis no Windows.
- Para FPS real: PresentMon ou outro processo escrevendo FPS em arquivo.
- Para brilho em monitor externo: DDC/CI ativado no menu do monitor, quando suportado.

## Licenca

MIT.
