# FPS real com PresentMon

O OverlayLeve consegue mostrar FPS real quando recebe uma fonte externa de FPS.

A fonte mais indicada para jogos no Windows e o PresentMon, projeto aberto da Intel/GameTechDev. Ele captura eventos de apresentacao de frames e grava CSV por frame. O OverlayLeve le esse CSV e calcula FPS a partir de colunas como `FPS`, `FPS-Display`, `FPS-Presents`, `MsBetweenPresents`, `MsBetweenDisplayChange`, `Displayed Frame Time` ou `Presented Frame Time`.

Documentacao oficial:

- https://github.com/GameTechDev/PresentMon
- https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md

## Uso manual

1. Baixe o PresentMon pelo repositorio oficial:
   https://github.com/GameTechDev/PresentMon/releases
2. Inicie a captura gerando um CSV.
3. Abra o overlay apontando para o CSV:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\src\OverlayLeve.ps1" -PresentMonCsv "C:\caminho\presentmon.csv"
```

## Scripts incluidos

Baixar a ultima release:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\BaixarPresentMon.ps1"
```

Iniciar captura para um processo e abrir o overlay:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\IniciarComPresentMon.ps1" -ProcessName "jogo.exe"
```

## Alternativa simples

Qualquer programa pode escrever apenas um numero de FPS no arquivo:

```text
%TEMP%\overlay_fps.txt
```

O overlay vai ler a ultima linha desse arquivo e mostrar como FPS.
