# SkyTools Plugin

Plugin Millennium que leva as principais funções do DolinTools para dentro da Steam.

## Build

```powershell
cd SkyTools.Plugin
pnpm install
pnpm build
```

Depois coloque esta pasta em `%Steam%\plugins` ou crie um link simbólico para ela.

O backend principal é Lua. Operações que exigem APIs do Windows, como varrer pastas,
baixar pacotes e executar reparos externos, usam helpers JScript/PowerShell pontuais
dentro do próprio plugin. Os dados ficam em `data` dentro do plugin, sem `node_modules`
empacotado e sem worker persistente.
