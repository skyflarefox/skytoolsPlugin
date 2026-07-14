# SkyTools Plugin

Plugin Millennium que leva as principais funcoes do DolinTools para dentro da Steam.

## Build

```powershell
cd SkyTools.Plugin
bun install
bun run build
```

Depois coloque esta pasta em `%Steam%\plugins` ou crie um link simbolico para ela.

O backend principal e Lua. Operacoes que exigem APIs do Windows, como varrer pastas,
baixar pacotes e executar reparos externos, usam helpers JScript/PowerShell pontuais
dentro do proprio plugin. Os dados ficam em `data` dentro do plugin, sem `node_modules`
empacotado e sem worker persistente.
