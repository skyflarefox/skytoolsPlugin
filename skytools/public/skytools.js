(function () {
  "use strict";

  var SKYTOOLS_UI_VERSION = "2026-07-23-i18n-live-chrome-1";

  if (window.__skytoolsPluginLoaded && window.__skytoolsPluginVersion === SKYTOOLS_UI_VERSION) {
    return;
  }

  if (window.__skytoolsPluginLoaded && window.__skytoolsPluginVersion !== SKYTOOLS_UI_VERSION) {
    var staleNodes = document.querySelectorAll(".skytools-panel,.skytools-fab,.skytools-toast,.skytools-game-button");
    for (var staleIndex = 0; staleIndex < staleNodes.length; staleIndex += 1) {
      staleNodes[staleIndex].remove();
    }
  }

  window.__skytoolsPluginLoaded = true;
  window.__skytoolsPluginVersion = SKYTOOLS_UI_VERSION;

  var PLUGIN_ID = "skytools-plugin";
  var API_ORDER_STORAGE_KEY = "SkyTools.ApiOrder";
  var THEME_STORAGE_KEY = "SkyTools.Theme";
  var THEME_STORAGE_KEYS = [THEME_STORAGE_KEY, "SkyTools.SelectedThemeId", "SkyTools.SelectedTheme"];
  var LANGUAGE_STORAGE_KEY = "SkyTools.Language";
  var DEFAULT_THEME = "official-orange";
  var DEFAULT_LANGUAGE = "auto";
  var SUPPORTED_LANGUAGES = [
    { id: "auto", label: "Automático do Windows" },
    { id: "en", label: "English" },
    { id: "pt-BR", label: "Português Brasileiro" },
    { id: "es", label: "Español" },
    { id: "ru", label: "Русский" }
  ];
  var SKYTOOLS_TRANSLATIONS = {
    "pt-BR": {
      "Home": "Início",
      "Fixes": "Correções",
      "Settings": "Configurações",
      " Steam integrated": "Steam integrado",
      "Steam integrated": "Steam integrado",
      "Library": "Biblioteca",
      "Default API": "API padrão",
      "Active": "Ativa",
      "Enabled": "Ativa",
      "Generic": "Genérica",
      "Generica": "Genérica",
      "Online": "Online",
      "Choose file": "Escolher arquivo",
      "No file selected": "Nenhum arquivo escolhido"
    },
    en: {
      "A ação falhou.": "The action failed.",
      "Ação concluída.": "Action completed.",
      "Abra uma página de jogo para adicionar.": "Open a game page to add it.",
      "A ação atual terminar.": "current action to finish.",
      "A aplicação da correção não respondeu a tempo.": "Applying the fix timed out.",
      "A URL da API precisa conter <appid>.": "The API URL must contain <appid>.",
      "Adicionar": "Add",
      "Adicionar API": "Add API",
      "Adicionar jogo": "Add game",
      "Adicionar via SkyTools": "Add with SkyTools",
      "Adicionando este jogo via SkyTools": "Adding this game with SkyTools",
      "Adicionando jogo": "Adding game",
      "Adicionando...": "Adding...",
      "Aguardando uma ação.": "Waiting for an action.",
      "Aguarde a ação atual terminar.": "Wait for the current action to finish.",
      "Aguarde a adição terminar.": "Wait for the add action to finish.",
      "Aplicando Sky": "Applying Sky",
      "Aplicar na pasta do jogo": "Apply to game folder",
      "APIs": "APIs",
      "APIs de download": "Download APIs",
      "API key": "API key",
      "API padrão": "Built-in API",
      "API personalizada": "Custom API",
      "API personalizada {count}": "Custom API {count}",
      "API sem nome": "Unnamed API",
      "App atual": "Current app",
      "AppID inválido.": "Invalid AppID.",
      "Arquivo de backup": "Backup file",
      "Arrastar para ordenar": "Drag to reorder",
      "Arraste para definir a ordem de tentativa.": "Drag to set the retry order.",
      "Automático do Windows": "Windows automatic",
      "Ativa": "Enabled",
      "Ativar SkyTools": "Enable SkyTools",
      "Ativar SteamTools": "Enable SteamTools",
      "Ativando SkyTools": "Enabling SkyTools",
      "Ativando SteamTools": "Enabling SteamTools",
      "Atualizar": "Refresh",
      "Backup": "Backup",
      "Biblioteca": "Library",
      "Biblioteca carregada": "Library loaded",
      "Baixando e instalando manifests": "Downloading and installing manifests",
      "Buscar correções": "Search fixes",
      "Buscar jogo instalado": "Search installed game",
      "Buscar na biblioteca": "Search library",
      "Buscar por jogo instalado": "Search by installed game",
      "Buscando correções": "Searching fixes",
      "Buscando correções Sky": "Searching Sky fixes",
      "Cache da Steam limpo e Steam reiniciada.": "Steam cache cleared and Steam restarted.",
      "Carregando APIs...": "Loading APIs...",
      "Carregando APIs": "Loading APIs",
      "Carregando biblioteca": "Loading library",
      "Carregando jogos adicionados.": "Loading added games.",
      "Carregando jogos instalados": "Loading installed games",
      "Carregando jogos instalados...": "Loading installed games...",
      "Carregando status": "Loading status",
      "Carregue um arquivo de backup primeiro.": "Load a backup file first.",
      "Carregue um backup": "Load a backup",
      "Configurações": "Settings",
      "Coletando configurações": "Collecting settings",
      "Concluído": "Done",
      "Correção Sky Aplicada.": "Sky fix applied.",
      "Correções": "Fixes",
      "Correções para jogo": "Game fixes",
      "Desativada": "Disabled",
      "Detectando": "Detecting",
      "Disponível em páginas de jogo": "Available on game pages",
      "Digite nome ou AppID": "Type name or AppID",
      "Editar API": "Edit API",
      "Editar API": "Edit API",
      "Encapsular URL.": "Wrap URL.",
      "Executando correção externa...": "Running external fix...",
      "Executando em segundo plano.": "Running in the background.",
      "Executando em segundo plano...": "Running in the background...",
      "Excluir API": "Delete API",
      "Exportando backup": "Exporting backup",
      "Exportar": "Export",
      "Exportar backup": "Export backup",
      "Falha": "Failed",
      "Fechar": "Close",
      "Fonte": "Source",
      "Genérica": "Generic",
      "Generic": "Generic",
      "HTTP indisponível": "HTTP unavailable",
      "HTTP sucesso": "HTTP success",
      "Idioma": "Language",
      "Idioma aplicado": "Language applied",
      "Idioma inválido.": "Invalid language.",
      "Informe um nome para a API.": "Enter an API name.",
      "Início": "Home",
      "Instalar integração Steam": "Install Steam integration",
      "Instalar manifests na Steam": "Install manifests in Steam",
      "Integração": "Integration",
      "Integracao": "Integration",
      "Jogos instalados": "Installed games",
      "Jogos na biblioteca": "Games in library",
      "Jogo atual": "Current game",
      "Link copiado.": "Link copied.",
      "Link indisponível.": "Link unavailable.",
      "Nome": "Name",
      "Nenhum": "None",
      "Nenhum backup carregado.": "No backup loaded.",
      "Nenhum arquivo escolhido": "No file selected",
      "Nenhum jogo aberto": "No game open",
      "Nenhum jogo carregado ainda.": "No games loaded yet.",
      "Nenhum jogo encontrado com esse filtro.": "No games found with this filter.",
      "Nenhum jogo instalado encontrado nas bibliotecas Steam.": "No installed games found in Steam libraries.",
      "Nenhuma API configurada.": "No APIs configured.",
      "Nenhuma correção Sky carregada.": "No Sky fixes loaded.",
      "Não foi possível gravar settings.json.": "Could not write settings.json.",
      "Não foi possível salvar o idioma.": "Could not save the language.",
      "Não foi possível salvar para a próxima inicialização.": "Could not save for the next startup.",
      "O idioma não foi persistido em settings.json.": "The language was not persisted in settings.json.",
      "Ordem salva": "Order saved",
      "Oceano ciano": "Cyan ocean",
      "Oficial laranja": "Official orange",
      "Online": "Online",
      "Pacote não suportado": "Unsupported package",
      "Preferência salva.": "Preference saved.",
      "A prioridade das APIs foi atualizada.": "The API priority was updated.",
      "Grafite lima": "Lime graphite",
      "Processando": "Processing",
      "Pronto": "Ready",
      "Proxy": "Proxy",
      "Remover correção e verificar integridade": "Remove fix and verify integrity",
      "Remover da Steam": "Remove from Steam",
      "Remover este jogo da biblioteca SkyTools": "Remove this game from the SkyTools library",
      "Remover via SkyTools": "Remove with SkyTools",
      "Removendo API": "Removing API",
      "Removendo correção": "Removing fix",
      "Removendo jogo": "Removing game",
      "Restaurando backup": "Restoring backup",
      "Restaurar ausentes": "Restore missing",
      "Rubi brasa": "Ruby ember",
      "Resultados": "Results",
      "Salvar API": "Save API",
      "Salvar biblioteca em JSON": "Save library as JSON",
      "Salvando API": "Saving API",
      "Salvando idioma": "Saving language",
      "Salvando ordem": "Saving order",
      "Salvando preferências": "Saving preferences",
      "Sem dados ainda.": "No data yet.",
      "Steam integrado": "Steam integrated",
      "SkyTools carregado.": "SkyTools loaded.",
      "Sincronizando com o backend...": "Syncing with the backend...",
      "Steam não encontrada.": "Steam not found.",
      "Tema": "Theme",
      "Tema aplicado": "Theme applied",
      "Tema não aplicado": "Theme not applied",
      "Tema selecionado.": "Selected theme.",
      "URL da API": "API URL",
      "URL do proxy": "Proxy URL",
      "URL não configurada": "URL not configured",
      "Escolher arquivo": "Choose file",
      "Home": "Home",
      "Fixes": "Fixes",
      "Settings": "Settings",
      "Biblioteca": "Library",
      "Steam integrated": "Steam integrated",
      "Use <appid> na URL. Use <apikey> quando a fonte exigir chave.": "Use <appid> in the URL. Use <apikey> when the source requires a key.",
      "Usar nas instalações.": "Use during installs.",
      "Voltando ao tema oficial.": "Returning to the official theme."
    },
    es: {
      "A ação falhou.": "La acción falló.",
      "Ação concluída.": "Acción completada.",
      "Abra uma página de jogo para adicionar.": "Abre una página de juego para añadirlo.",
      "A aplicação da correção não respondeu a tempo.": "La aplicación de la corrección agotó el tiempo.",
      "A URL da API precisa conter <appid>.": "La URL de la API debe contener <appid>.",
      "Adicionar": "Añadir",
      "Adicionar API": "Añadir API",
      "Adicionar jogo": "Añadir juego",
      "Adicionar via SkyTools": "Añadir con SkyTools",
      "Adicionando este jogo via SkyTools": "Añadiendo este juego con SkyTools",
      "Adicionando jogo": "Añadiendo juego",
      "Adicionando...": "Añadiendo...",
      "Aguardando uma ação.": "Esperando una acción.",
      "Aguarde a ação atual terminar.": "Espera a que termine la acción actual.",
      "Aguarde a adição terminar.": "Espera a que termine la adición.",
      "Aplicando Sky": "Aplicando Sky",
      "Aplicar na pasta do jogo": "Aplicar en la carpeta del juego",
      "APIs de download": "APIs de descarga",
      "API padrão": "API predeterminada",
      "API personalizada": "API personalizada",
      "API personalizada {count}": "API personalizada {count}",
      "API sem nome": "API sin nombre",
      "App atual": "App actual",
      "AppID inválido.": "AppID inválido.",
      "Arquivo de backup": "Archivo de backup",
      "Arrastar para ordenar": "Arrastrar para ordenar",
      "Arraste para definir a ordem de tentativa.": "Arrastra para definir el orden de intento.",
      "Automático do Windows": "Automático de Windows",
      "Ativa": "Activa",
      "Ativar SkyTools": "Activar SkyTools",
      "Ativar SteamTools": "Activar SteamTools",
      "Ativando SkyTools": "Activando SkyTools",
      "Ativando SteamTools": "Activando SteamTools",
      "Atualizar": "Actualizar",
      "Backup": "Backup",
      "Biblioteca": "Biblioteca",
      "Biblioteca carregada": "Biblioteca cargada",
      "Baixando e instalando manifests": "Descargando e instalando manifests",
      "Buscar correções": "Buscar correcciones",
      "Buscar jogo instalado": "Buscar juego instalado",
      "Buscar na biblioteca": "Buscar en la biblioteca",
      "Buscar por jogo instalado": "Buscar por juego instalado",
      "Buscando correções": "Buscando correcciones",
      "Buscando correções Sky": "Buscando correcciones Sky",
      "Cache da Steam limpo e Steam reiniciada.": "Caché de Steam limpiada y Steam reiniciado.",
      "Carregando APIs...": "Cargando APIs...",
      "Carregando APIs": "Cargando APIs",
      "Carregando biblioteca": "Cargando biblioteca",
      "Carregando jogos adicionados.": "Cargando juegos añadidos.",
      "Carregando jogos instalados": "Cargando juegos instalados",
      "Carregando jogos instalados...": "Cargando juegos instalados...",
      "Carregando status": "Cargando estado",
      "Carregue um arquivo de backup primeiro.": "Carga primero un archivo de backup.",
      "Carregue um backup": "Carga un backup",
      "Configurações": "Configuración",
      "Coletando configurações": "Recopilando configuración",
      "Concluído": "Completado",
      "Correção Sky Aplicada.": "Corrección Sky aplicada.",
      "Correções": "Correcciones",
      "Correções para jogo": "Correcciones del juego",
      "Desativada": "Desactivada",
      "Detectando": "Detectando",
      "Disponível em páginas de jogo": "Disponible en páginas de juegos",
      "Digite nome ou AppID": "Escribe nombre o AppID",
      "Editar API": "Editar API",
      "Encapsular URL.": "Encapsular URL.",
      "Executando correção externa...": "Ejecutando corrección externa...",
      "Executando em segundo plano.": "Ejecutando en segundo plano.",
      "Executando em segundo plano...": "Ejecutando en segundo plano...",
      "Excluir API": "Eliminar API",
      "Exportando backup": "Exportando backup",
      "Exportar": "Exportar",
      "Exportar backup": "Exportar backup",
      "Falha": "Error",
      "Fechar": "Cerrar",
      "Fonte": "Fuente",
      "Genérica": "Genérica",
      "Generic": "Genérica",
      "HTTP indisponível": "HTTP no disponible",
      "HTTP sucesso": "HTTP éxito",
      "Idioma": "Idioma",
      "Idioma aplicado": "Idioma aplicado",
      "Idioma inválido.": "Idioma inválido.",
      "Informe um nome para a API.": "Introduce un nombre para la API.",
      "Início": "Inicio",
      "Instalar integração Steam": "Instalar integración Steam",
      "Instalar manifests na Steam": "Instalar manifests en Steam",
      "Integração": "Integración",
      "Integracao": "Integración",
      "Jogos instalados": "Juegos instalados",
      "Jogos na biblioteca": "Juegos en la biblioteca",
      "Jogo atual": "Juego actual",
      "Link copiado.": "Enlace copiado.",
      "Link indisponível.": "Enlace no disponible.",
      "Nome": "Nombre",
      "Nenhum": "Ninguno",
      "Nenhum backup carregado.": "Ningún backup cargado.",
      "Nenhum arquivo escolhido": "Ningún archivo elegido",
      "Nenhum jogo aberto": "Ningún juego abierto",
      "Nenhum jogo carregado ainda.": "No hay juegos cargados todavía.",
      "Nenhum jogo encontrado com esse filtro.": "No se encontraron juegos con este filtro.",
      "Nenhum jogo instalado encontrado nas bibliotecas Steam.": "No se encontraron juegos instalados en las bibliotecas de Steam.",
      "Nenhuma API configurada.": "Ninguna API configurada.",
      "Nenhuma correção Sky carregada.": "Ninguna corrección Sky cargada.",
      "Não foi possível gravar settings.json.": "No se pudo escribir settings.json.",
      "Não foi possível salvar o idioma.": "No se pudo guardar el idioma.",
      "Não foi possível salvar para a próxima inicialização.": "No se pudo guardar para el próximo inicio.",
      "O idioma não foi persistido em settings.json.": "El idioma no se guardó en settings.json.",
      "Ordem salva": "Orden guardado",
      "Oceano ciano": "Océano cian",
      "Oficial laranja": "Naranja oficial",
      "Online": "Online",
      "Pacote não suportado": "Paquete no compatible",
      "Preferência salva.": "Preferencia guardada.",
      "A prioridade das APIs foi atualizada.": "La prioridad de las APIs se actualizó.",
      "Grafite lima": "Grafito lima",
      "Processando": "Procesando",
      "Pronto": "Listo",
      "Proxy": "Proxy",
      "Remover correção e verificar integridade": "Eliminar corrección y verificar integridad",
      "Remover da Steam": "Eliminar de Steam",
      "Remover este jogo da biblioteca SkyTools": "Eliminar este juego de la biblioteca SkyTools",
      "Remover via SkyTools": "Eliminar con SkyTools",
      "Removendo API": "Eliminando API",
      "Removendo correção": "Eliminando corrección",
      "Removendo jogo": "Eliminando juego",
      "Restaurando backup": "Restaurando backup",
      "Restaurar ausentes": "Restaurar ausentes",
      "Rubi brasa": "Rubí brasa",
      "Resultados": "Resultados",
      "Salvar API": "Guardar API",
      "Salvar biblioteca em JSON": "Guardar biblioteca en JSON",
      "Salvando API": "Guardando API",
      "Salvando idioma": "Guardando idioma",
      "Salvando ordem": "Guardando orden",
      "Salvando preferências": "Guardando preferencias",
      "Sem dados ainda.": "Sin datos todavía.",
      "Steam integrado": "Steam integrado",
      "SkyTools carregado.": "SkyTools cargado.",
      "Sincronizando com o backend...": "Sincronizando con el backend...",
      "Steam não encontrada.": "Steam no encontrada.",
      "Tema": "Tema",
      "Tema aplicado": "Tema aplicado",
      "Tema não aplicado": "Tema no aplicado",
      "Tema selecionado.": "Tema seleccionado.",
      "URL da API": "URL de la API",
      "URL do proxy": "URL del proxy",
      "URL não configurada": "URL no configurada",
      "Escolher arquivo": "Elegir archivo",
      "Home": "Inicio",
      "Fixes": "Correcciones",
      "Settings": "Configuración",
      "Steam integrated": "Steam integrado",
      "Use <appid> na URL. Use <apikey> quando a fonte exigir chave.": "Usa <appid> en la URL. Usa <apikey> cuando la fuente requiera una clave.",
      "Usar nas instalações.": "Usar en las instalaciones.",
      "Voltando ao tema oficial.": "Volviendo al tema oficial."
    },
    ru: {
      "A ação falhou.": "Действие не выполнено.",
      "Ação concluída.": "Действие завершено.",
      "Abra uma página de jogo para adicionar.": "Откройте страницу игры, чтобы добавить ее.",
      "A aplicação da correção não respondeu a tempo.": "Применение исправления не ответило вовремя.",
      "A URL da API precisa conter <appid>.": "URL API должен содержать <appid>.",
      "Adicionar": "Добавить",
      "Adicionar API": "Добавить API",
      "Adicionar jogo": "Добавить игру",
      "Adicionar via SkyTools": "Добавить через SkyTools",
      "Adicionando este jogo via SkyTools": "Добавление этой игры через SkyTools",
      "Adicionando jogo": "Добавление игры",
      "Adicionando...": "Добавление...",
      "Aguardando uma ação.": "Ожидание действия.",
      "Aguarde a ação atual terminar.": "Дождитесь завершения текущего действия.",
      "Aguarde a adição terminar.": "Дождитесь завершения добавления.",
      "Aplicando Sky": "Применение Sky",
      "Aplicar na pasta do jogo": "Применить в папке игры",
      "APIs de download": "API загрузки",
      "API padrão": "Встроенный API",
      "API personalizada": "Пользовательский API",
      "API personalizada {count}": "Пользовательский API {count}",
      "API sem nome": "API без имени",
      "App atual": "Текущее приложение",
      "AppID inválido.": "Недействительный AppID.",
      "Arquivo de backup": "Файл резервной копии",
      "Arrastar para ordenar": "Перетащите для сортировки",
      "Arraste para definir a ordem de tentativa.": "Перетащите, чтобы задать порядок попыток.",
      "Automático do Windows": "Автоматически из Windows",
      "Ativa": "Включена",
      "Ativar SkyTools": "Включить SkyTools",
      "Ativar SteamTools": "Включить SteamTools",
      "Ativando SkyTools": "Включение SkyTools",
      "Ativando SteamTools": "Включение SteamTools",
      "Atualizar": "Обновить",
      "Backup": "Резервная копия",
      "Biblioteca": "Библиотека",
      "Biblioteca carregada": "Библиотека загружена",
      "Baixando e instalando manifests": "Загрузка и установка манифестов",
      "Buscar correções": "Искать исправления",
      "Buscar jogo instalado": "Искать установленную игру",
      "Buscar na biblioteca": "Поиск в библиотеке",
      "Buscar por jogo instalado": "Поиск по установленной игре",
      "Buscando correções": "Поиск исправлений",
      "Buscando correções Sky": "Поиск исправлений Sky",
      "Cache da Steam limpo e Steam reiniciada.": "Кэш Steam очищен, Steam перезапущен.",
      "Carregando APIs...": "Загрузка API...",
      "Carregando APIs": "Загрузка API",
      "Carregando biblioteca": "Загрузка библиотеки",
      "Carregando jogos adicionados.": "Загрузка добавленных игр.",
      "Carregando jogos instalados": "Загрузка установленных игр",
      "Carregando jogos instalados...": "Загрузка установленных игр...",
      "Carregando status": "Загрузка статуса",
      "Carregue um arquivo de backup primeiro.": "Сначала загрузите файл резервной копии.",
      "Carregue um backup": "Загрузите резервную копию",
      "Configurações": "Настройки",
      "Coletando configurações": "Сбор настроек",
      "Concluído": "Готово",
      "Correção Sky Aplicada.": "Исправление Sky применено.",
      "Correções": "Исправления",
      "Correções para jogo": "Исправления для игры",
      "Desativada": "Отключена",
      "Detectando": "Определение",
      "Disponível em páginas de jogo": "Доступно на страницах игр",
      "Digite nome ou AppID": "Введите имя или AppID",
      "Editar API": "Редактировать API",
      "Encapsular URL.": "Обернуть URL.",
      "Executando correção externa...": "Запуск внешнего исправления...",
      "Executando em segundo plano.": "Выполняется в фоне.",
      "Executando em segundo plano...": "Выполняется в фоне...",
      "Excluir API": "Удалить API",
      "Exportando backup": "Экспорт резервной копии",
      "Exportar": "Экспорт",
      "Exportar backup": "Экспорт резервной копии",
      "Falha": "Ошибка",
      "Fechar": "Закрыть",
      "Fonte": "Источник",
      "Genérica": "Общее",
      "Generic": "Общее",
      "HTTP indisponível": "HTTP недоступен",
      "HTTP sucesso": "HTTP успех",
      "Idioma": "Язык",
      "Idioma aplicado": "Язык применен",
      "Idioma inválido.": "Недействительный язык.",
      "Informe um nome para a API.": "Введите имя API.",
      "Início": "Главная",
      "Instalar integração Steam": "Установить интеграцию Steam",
      "Instalar manifests na Steam": "Установить манифесты в Steam",
      "Integração": "Интеграция",
      "Integracao": "Интеграция",
      "Jogos instalados": "Установленные игры",
      "Jogos na biblioteca": "Игры в библиотеке",
      "Jogo atual": "Текущая игра",
      "Link copiado.": "Ссылка скопирована.",
      "Link indisponível.": "Ссылка недоступна.",
      "Nome": "Имя",
      "Nenhum": "Нет",
      "Nenhum backup carregado.": "Резервная копия не загружена.",
      "Nenhum arquivo escolhido": "Файл не выбран",
      "Nenhum jogo aberto": "Игра не открыта",
      "Nenhum jogo carregado ainda.": "Игры еще не загружены.",
      "Nenhum jogo encontrado com esse filtro.": "Игры по этому фильтру не найдены.",
      "Nenhum jogo instalado encontrado nas bibliotecas Steam.": "Установленные игры в библиотеках Steam не найдены.",
      "Nenhuma API configurada.": "API не настроены.",
      "Nenhuma correção Sky carregada.": "Исправления Sky не загружены.",
      "Não foi possível gravar settings.json.": "Не удалось записать settings.json.",
      "Não foi possível salvar o idioma.": "Не удалось сохранить язык.",
      "Não foi possível salvar para a próxima inicialização.": "Не удалось сохранить для следующего запуска.",
      "O idioma não foi persistido em settings.json.": "Язык не был сохранен в settings.json.",
      "Ordem salva": "Порядок сохранен",
      "Oceano ciano": "Циановый океан",
      "Oficial laranja": "Официальный оранжевый",
      "Online": "Онлайн",
      "Pacote não suportado": "Пакет не поддерживается",
      "Preferência salva.": "Настройка сохранена.",
      "A prioridade das APIs foi atualizada.": "Приоритет API обновлен.",
      "Grafite lima": "Графитовый лайм",
      "Processando": "Обработка",
      "Pronto": "Готово",
      "Proxy": "Прокси",
      "Remover correção e verificar integridade": "Удалить исправление и проверить целостность",
      "Remover da Steam": "Удалить из Steam",
      "Remover este jogo da biblioteca SkyTools": "Удалить эту игру из библиотеки SkyTools",
      "Remover via SkyTools": "Удалить через SkyTools",
      "Removendo API": "Удаление API",
      "Removendo correção": "Удаление исправления",
      "Removendo jogo": "Удаление игры",
      "Restaurando backup": "Восстановление резервной копии",
      "Restaurar ausentes": "Восстановить отсутствующие",
      "Rubi brasa": "Рубиновый жар",
      "Resultados": "Результаты",
      "Salvar API": "Сохранить API",
      "Salvar biblioteca em JSON": "Сохранить библиотеку в JSON",
      "Salvando API": "Сохранение API",
      "Salvando idioma": "Сохранение языка",
      "Salvando ordem": "Сохранение порядка",
      "Salvando preferências": "Сохранение настроек",
      "Sem dados ainda.": "Данных пока нет.",
      "Steam integrado": "Steam интегрирован",
      "SkyTools carregado.": "SkyTools загружен.",
      "Sincronizando com o backend...": "Синхронизация с backend...",
      "Steam não encontrada.": "Steam не найден.",
      "Tema": "Тема",
      "Tema aplicado": "Тема применена",
      "Tema não aplicado": "Тема не применена",
      "Tema selecionado.": "Выбранная тема.",
      "URL da API": "URL API",
      "URL do proxy": "URL прокси",
      "URL não configurada": "URL не настроен",
      "Escolher arquivo": "Выбрать файл",
      "Home": "Главная",
      "Fixes": "Исправления",
      "Settings": "Настройки",
      "Steam integrated": "Steam интегрирован",
      "Use <appid> na URL. Use <apikey> quando a fonte exigir chave.": "Используйте <appid> в URL. Используйте <apikey>, если источник требует ключ.",
      "Usar nas instalações.": "Использовать при установке.",
      "Voltando ao tema oficial.": "Возврат к официальной теме."
    }
  };
  var BUILT_IN_THEMES = [
    { id: DEFAULT_THEME, name: "Oficial laranja", file: "official-orange.css" },
    { id: "ocean-cyan", name: "Oceano ciano", file: "ocean-cyan.css" },
    { id: "graphite-lime", name: "Grafite lima", file: "graphite-lime.css" },
    { id: "ruby-ember", name: "Rubi brasa", file: "ruby-ember.css" }
  ];
  var BUILT_IN_THEME_VARS = {
    "official-orange": {
      "bg": "#17120f", "bg-elevated": "rgba(28, 22, 18, 0.98)", "surface": "rgba(255, 255, 255, 0.035)", "surface-strong": "rgba(255, 255, 255, 0.045)", "surface-muted": "rgba(0, 0, 0, 0.16)", "surface-deep": "rgba(0, 0, 0, 0.28)", "text": "#ffffff", "text-soft": "#f6ddc5", "muted": "#d1a57d", "muted-strong": "#d7b28d", "brand-muted": "#d9ad83", "accent": "#e88914", "accent-strong": "#c24e12", "accent-alt": "#f59e0b", "accent-rgb": "255, 166, 77", "accent-strong-rgb": "194, 78, 18", "accent-text": "#ffd29a", "button-start": "#bf4b10", "button-end": "#e88914", "button-remove-start": "#9f3b0e", "button-remove-end": "#d86510", "success": "#34d399", "success-soft": "#7ee0a3", "danger": "#fb7185", "danger-soft": "#ff8a8a", "danger-text": "#ffb4a8", "warning": "#f2c94c"
    },
    "ocean-cyan": {
      "bg": "#101817", "bg-elevated": "rgba(17, 28, 28, 0.98)", "surface": "rgba(185, 255, 245, 0.04)", "surface-strong": "rgba(185, 255, 245, 0.07)", "surface-muted": "rgba(0, 0, 0, 0.18)", "surface-deep": "rgba(0, 0, 0, 0.32)", "text": "#f5fffd", "text-soft": "#c9f4ed", "muted": "#8ac9c1", "muted-strong": "#a5d8d1", "brand-muted": "#95d5ce", "accent": "#22d3ee", "accent-strong": "#0e7490", "accent-alt": "#14b8a6", "accent-rgb": "34, 211, 238", "accent-strong-rgb": "14, 116, 144", "accent-text": "#b9fbff", "button-start": "#0f766e", "button-end": "#0891b2", "button-remove-start": "#155e75", "button-remove-end": "#0e7490", "success": "#4ade80", "success-soft": "#86efac", "danger": "#fb7185", "danger-soft": "#fda4af", "danger-text": "#fecdd3", "warning": "#facc15"
    },
    "graphite-lime": {
      "bg": "#141611", "bg-elevated": "rgba(23, 26, 19, 0.98)", "surface": "rgba(222, 255, 171, 0.04)", "surface-strong": "rgba(222, 255, 171, 0.07)", "surface-muted": "rgba(0, 0, 0, 0.18)", "surface-deep": "rgba(0, 0, 0, 0.32)", "text": "#fbfff5", "text-soft": "#e2f7c0", "muted": "#bdd38f", "muted-strong": "#d0e5a6", "brand-muted": "#c4dd92", "accent": "#a3e635", "accent-strong": "#4d7c0f", "accent-alt": "#84cc16", "accent-rgb": "163, 230, 53", "accent-strong-rgb": "77, 124, 15", "accent-text": "#ecfccb", "button-start": "#3f6212", "button-end": "#65a30d", "button-remove-start": "#713f12", "button-remove-end": "#a16207", "success": "#22c55e", "success-soft": "#86efac", "danger": "#f87171", "danger-soft": "#fca5a5", "danger-text": "#fecaca", "warning": "#fbbf24"
    },
    "ruby-ember": {
      "bg": "#180f13", "bg-elevated": "rgba(30, 18, 23, 0.98)", "surface": "rgba(255, 214, 224, 0.04)", "surface-strong": "rgba(255, 214, 224, 0.07)", "surface-muted": "rgba(0, 0, 0, 0.17)", "surface-deep": "rgba(0, 0, 0, 0.31)", "text": "#fff8fa", "text-soft": "#ffd8df", "muted": "#dfa0aa", "muted-strong": "#efb5bf", "brand-muted": "#e6a4ae", "accent": "#fb7185", "accent-strong": "#be123c", "accent-alt": "#f97316", "accent-rgb": "251, 113, 133", "accent-strong-rgb": "190, 18, 60", "accent-text": "#ffe4e6", "button-start": "#9f1239", "button-end": "#e11d48", "button-remove-start": "#7f1d1d", "button-remove-end": "#b91c1c", "success": "#34d399", "success-soft": "#86efac", "danger": "#f43f5e", "danger-soft": "#fb7185", "danger-text": "#fecdd3", "warning": "#fbbf24"
    }
  };
  var state = {
    lastUrl: "",
    appid: "",
    appName: "",
    busy: false,
    activeTab: "inicio",
    status: null,
    installed: null,
    fixGames: null,
    installedMap: {},
    installedLoadedAt: 0,
    installedLoading: false,
    fixGamesLoading: false,
    fixGamesPromise: null,
    nameCache: {},
    apis: null,
    themes: BUILT_IN_THEMES.slice(),
    themeId: readStoredTheme(),
    languageMode: readStoredLanguage(),
    themeRequestId: 0,
    themeCss: "",
    themeAppliedId: "",
    themeVars: null,
    apisLoading: false,
    apiForm: null,
    apiOrder: null,
    draggingApiId: "",
    pendingApiDrop: null,
    draggingPointerId: null,
    libraryQuery: "",
    installedPromise: null,
    backup: null,
    fixResults: null,
    fixQuery: "",
    fixVisibleCount: 80,
    fixMatchedCount: 0,
    selectedFixGame: null,
    lastResult: null,
    addingAppId: "",
    activityTitle: "Pronto",
    activityDetail: "Aguardando uma ação.",
    activityKind: "idle"
  };

  var icons = {
    add: "f055",
    library: "f11b",
    api: "f233",
    fixes: "f0ad",
    online: "f0c2",
    denuvo: "f3ed",
    backup: "f019",
    repair: "f7d9",
    status: "f05a",
    settings: "f013",
    close: "f00d",
    refresh: "f021",
    check: "f058",
    error: "f071",
    spinner: "f110",
    folder: "f07b",
    list: "f03a",
    shield: "f3ed",
    trash: "f2ed",
    plug: "f1e6",
    pencil: "f303"
  };

  function icon(name, extraClass) {
    return '<i class="skytools-fa ' + (extraClass || "") + '">&#x' + (icons[name] || icons.status) + ';</i>';
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function normalizeLanguageId(value) {
    value = String(value || "").trim();
    if (!value) {
      return DEFAULT_LANGUAGE;
    }
    var lower = value.toLowerCase();
    if (lower === "pt" || lower === "pt-br" || lower === "pt_br") {
      return "pt-BR";
    }
    if (lower === "en" || lower.indexOf("en-") === 0) {
      return "en";
    }
    if (lower === "es" || lower.indexOf("es-") === 0) {
      return "es";
    }
    if (lower === "ru" || lower.indexOf("ru-") === 0) {
      return "ru";
    }
    if (lower === "auto" || lower === "system" || lower === "windows") {
      return "auto";
    }
    return DEFAULT_LANGUAGE;
  }

  function systemLanguageId() {
    var candidates = [];
    if (navigator.languages && navigator.languages.length) {
      candidates = Array.prototype.slice.call(navigator.languages);
    }
    candidates.push(navigator.language || navigator.userLanguage || "");
    for (var i = 0; i < candidates.length; i += 1) {
      var id = normalizeLanguageId(candidates[i]);
      if (id !== "auto") {
        return id;
      }
    }
    return "en";
  }

  function activeLanguageId() {
    var mode = normalizeLanguageId(state && state.languageMode || DEFAULT_LANGUAGE);
    return mode === "auto" ? systemLanguageId() : mode;
  }

  function languageLabel(id) {
    id = normalizeLanguageId(id);
    for (var i = 0; i < SUPPORTED_LANGUAGES.length; i += 1) {
      if (SUPPORTED_LANGUAGES[i].id === id) {
        return SUPPORTED_LANGUAGES[i].label;
      }
    }
    return SUPPORTED_LANGUAGES[0].label;
  }

  function t(text, vars) {
    text = String(text == null ? "" : text);
    var lang = activeLanguageId();
    var value = (SKYTOOLS_TRANSLATIONS[lang] && SKYTOOLS_TRANSLATIONS[lang][text]) || text;
    if (vars) {
      Object.keys(vars).forEach(function (key) {
        value = value.split("{" + key + "}").join(String(vars[key]));
      });
    }
    return value;
  }

  function translateMessage(message) {
    var text = String(message == null ? "" : message);
    var exact = t(text);
    if (exact !== text) {
      return exact;
    }
    var lang = activeLanguageId();
    var prefixes = [
      ["Nenhuma API retornou um pacote válido.", {
        en: "No API returned a valid package.",
        es: "Ninguna API devolvió un paquete válido.",
        ru: "Ни один API не вернул допустимый пакет."
      }],
      ["Não foi possível abrir o pacote zip.", {
        en: "Could not open the zip package.",
        es: "No se pudo abrir el paquete zip.",
        ru: "Не удалось открыть zip-пакет."
      }],
      ["Já existe uma operação em andamento para este jogo.", {
        en: "There is already an operation running for this game.",
        es: "Ya hay una operación en curso para este juego.",
        ru: "Для этой игры уже выполняется операция."
      }]
    ];
    for (var p = 0; p < prefixes.length; p += 1) {
      if (text.indexOf(prefixes[p][0]) === 0 && lang !== "pt-BR") {
        return prefixes[p][1][lang] + text.slice(prefixes[p][0].length);
      }
    }
    var replacements = [
      [/^(\d+) jogos adicionados\. Integração: (.+)\.$/, "{count} games added. Integration: {integration}.", "{count} juegos añadidos. Integración: {integration}.", "{count} игр добавлено. Интеграция: {integration}."],
      [/^Manifests: (\d+)\. DLCs: (\d+)\.$/, "Manifests: {manifests}. DLCs: {dlcs}.", "Manifests: {manifests}. DLCs: {dlcs}.", "Манифесты: {manifests}. DLC: {dlcs}."],
      [/^Resultados para (.+)$/, "Results for {name}", "Resultados para {name}", "Результаты для {name}"],
      [/^Mostrar mais (\d+) de (\d+)$/, "Show {count} more of {total}", "Mostrar {count} más de {total}", "Показать еще {count} из {total}"],
      [/^(\d+) jogo\(s\) carregado\(s\)$/, "{count} game(s) loaded", "{count} juego(s) cargado(s)", "{count} игр загружено"],
      [/^(\d+) item\(ns\) encontrados\.$/, "{count} item(s) found.", "{count} elemento(s) encontrados.", "Найдено элементов: {count}."]
    ];
    for (var i = 0; i < replacements.length; i += 1) {
      var match = text.match(replacements[i][0]);
      if (!match) {
        continue;
      }
      var template = lang === "en" ? replacements[i][1] : lang === "es" ? replacements[i][2] : lang === "ru" ? replacements[i][3] : text;
      return template
        .replace("{count}", match[1] || "")
        .replace("{integration}", match[2] || "")
        .replace("{manifests}", match[1] || "")
        .replace("{dlcs}", match[2] || "")
        .replace("{name}", match[1] || "")
        .replace("{total}", match[2] || "");
    }
    return text;
  }

  function localizeDom(root) {
    if (!root || !document.createTreeWalker) {
      return;
    }
    var walker = document.createTreeWalker(root, window.NodeFilter ? window.NodeFilter.SHOW_TEXT : 4, null);
    var nodes = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }
    for (var i = 0; i < nodes.length; i += 1) {
      var raw = nodes[i].nodeValue || "";
      var trimmed = raw.trim();
      if (!trimmed) {
        continue;
      }
      var translated = translateMessage(trimmed);
      if (translated !== trimmed) {
        nodes[i].nodeValue = raw.replace(trimmed, translated);
      }
    }
    var attrs = ["title", "placeholder", "aria-label"];
    var elements = root.querySelectorAll ? root.querySelectorAll("[title],[placeholder],[aria-label]") : [];
    for (var e = 0; e < elements.length; e += 1) {
      for (var a = 0; a < attrs.length; a += 1) {
        var attr = attrs[a];
        var value = elements[e].getAttribute(attr);
        if (value) {
          elements[e].setAttribute(attr, translateMessage(value));
        }
      }
    }
  }

  function log(message) {
    try {
      Millennium.callServerMethod(PLUGIN_ID, "Logger.log", { message: String(message) });
    } catch (_) {
      console.log("[SkyTools]", message);
    }
  }

  function parseResponse(response) {
    if (typeof response === "string") {
      try {
        return JSON.parse(response);
      } catch (_) {
        return { success: false, error: response };
      }
    }
    return response || {};
  }

  function shouldRetryLegacyCall(result) {
    if (!result || result.success !== false) {
      return false;
    }
    return /metodo desconhecido|m[eé]todo desconhecido|method.*not.*found|unknown method|bridge/i.test(String(result.error || ""));
  }

  function withTimeout(promise, label) {
    var timeoutMs = 35000;
    return new Promise(function (resolve, reject) {
      var settled = false;
      var timer = setTimeout(function () {
        if (!settled) {
          settled = true;
          reject(new Error((label || "Chamada") + " demorou demais para responder."));
        }
      }, timeoutMs);
      promise.then(function (value) {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(value);
        }
      }, function (error) {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(error);
        }
      });
    });
  }

  function wrapPayload(payload) {
    var value = payload || {};
    if (typeof value === "object") {
      return { payload: JSON.stringify(value) };
    }
    return { payload: String(value) };
  }

  function callLegacy(method, payload) {
    return withTimeout(Millennium.callServerMethod(PLUGIN_ID, method, wrapPayload(payload)).then(parseResponse), method);
  }

  function call(method, payload) {
    if (typeof Millennium === "undefined" || typeof Millennium.callServerMethod !== "function") {
      return Promise.reject(new Error("Millennium bridge indisponível"));
    }
    try {
      return withTimeout(Millennium.callServerMethod(method, wrapPayload(payload)).then(parseResponse), method).then(function (result) {
        if (shouldRetryLegacyCall(result)) {
          return callLegacy(method, payload);
        }
        return result;
      }, function () {
        return callLegacy(method, payload);
      });
    } catch (_) {
      return callLegacy(method, payload);
    }
  }

  function callJson(method, payload) {
    return call(method, payload || {});
  }

  function callArgs(method, args) {
    args = Array.isArray(args) ? args : [];
    if (typeof Millennium === "undefined" || typeof Millennium.callServerMethod !== "function") {
      return Promise.reject(new Error("Millennium bridge indisponível"));
    }
    return call(method, { args: args });
  }

  function apiFormArgs(api) {
    api = api || {};
    return [
      String(api.id || ""),
      String(api.name || ""),
      String(api.urlTemplate || ""),
      String(api.apiKey || ""),
      api.enabled !== false,
      api.useProxy === true,
      String(api.proxyUrlTemplate || ""),
      Number(api.successCode) || 200,
      Number(api.unavailableCode) || 404
    ];
  }

  function appIdFromUrl() {
    var match = String(location.href).match(/\/app\/(\d+)/i);
    return match ? match[1] : "";
  }

  function appNameFromPage() {
    var selectors = [".apphub_AppName", ".game_title_area .title", "#appHubAppName", "h1"];
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node && node.textContent.trim()) {
        return node.textContent.trim();
      }
    }
    var meta = document.querySelector('meta[property="og:title"], meta[name="twitter:title"]');
    if (meta && meta.getAttribute("content")) {
      return meta.getAttribute("content").replace(/\s+on Steam\s*$/i, "").trim();
    }
    return document.title.replace(/\s+on Steam\s*$/i, "").trim();
  }

  function isPlaceholderName(name, appid) {
    var value = String(name || "").trim();
    var id = String(appid || "").trim();
    if (!value) return true;
    if (id && value === id) return true;
    if (id && value.toLowerCase() === ("appid " + id).toLowerCase()) return true;
    return /^AppID\s+\d+$/i.test(value);
  }

  function currentPayload() {
    var appid = appIdFromUrl() || state.appid;
    var name = appNameFromPage() || state.appName || state.nameCache[String(appid)] || "";
    if (isPlaceholderName(name, appid)) {
      name = state.nameCache[String(appid)] || "";
    }
    return {
      appid: appid,
      name: name
    };
  }

  function normalizeData(result) {
    if (!result) {
      return null;
    }
    return result.data !== undefined ? result.data : result;
  }

  function readStoredTheme() {
    try {
      for (var i = 0; i < THEME_STORAGE_KEYS.length; i += 1) {
        var stored = String(localStorage.getItem(THEME_STORAGE_KEYS[i]) || "").trim();
        if (stored) {
          return stored;
        }
      }
      return DEFAULT_THEME;
    } catch (_) {
      return DEFAULT_THEME;
    }
  }

  function writeStoredTheme(themeId) {
    try {
      var value = themeId || DEFAULT_THEME;
      for (var i = 0; i < THEME_STORAGE_KEYS.length; i += 1) {
        localStorage.setItem(THEME_STORAGE_KEYS[i], value);
      }
    } catch (_) {
      // O CSS base mantém o tema oficial mesmo quando o storage da WebView falha.
    }
  }

  function readStoredLanguage() {
    try {
      return normalizeLanguageId(localStorage.getItem(LANGUAGE_STORAGE_KEY) || DEFAULT_LANGUAGE);
    } catch (_) {
      return DEFAULT_LANGUAGE;
    }
  }

  function writeStoredLanguage(languageId) {
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, normalizeLanguageId(languageId));
    } catch (_) {
      // Local storage can be unavailable in Steam WebView; backend persistence remains authoritative.
    }
  }

  function syncLanguageFromStatus(result) {
    var data = normalizeData(result) || {};
    var saved = data.selectedLanguageId || data.selectedLanguage || data.language || data.Language;
    if (saved) {
      state.languageMode = normalizeLanguageId(saved);
      writeStoredLanguage(state.languageMode);
    }
  }

  function saveThemePreference(themeId) {
    themeId = themeId || DEFAULT_THEME;
    writeStoredTheme(themeId);
    function localThemeSavedResult(error) {
      return {
        success: true,
        data: {
          themeId: themeId,
          selectedThemeId: themeId,
          localOnly: true,
          warning: error ? String(error) : ""
        }
      };
    }

    function confirmSaved() {
      return call("SkyToolsStatus", {}).then(function (status) {
        var data = normalizeData(status) || {};
        var savedTheme = String(data.selectedThemeId || data.SelectedThemeId || "").trim();
        if (savedTheme === themeId) {
          state.status = status;
          return { success: true };
        }
        return { success: false, error: "O backend não confirmou o tema salvo." };
      }, function (error) {
        return localThemeSavedResult(error);
      });
    }

    return call("SkyToolsSaveApiSettings", { selectedThemeId: themeId, themeId: themeId }).then(function (result) {
      if (result && result.success === false) {
        return result;
      }
      return confirmSaved();
    }).then(function (result) {
      if (!result || result.success !== false) {
        return result;
      }
      return call("SkyToolsSaveTheme", { themeId: themeId, selectedThemeId: themeId }).then(function (fallbackResult) {
        if (fallbackResult && fallbackResult.success === false) {
          return fallbackResult;
        }
        return confirmSaved();
      });
    }).catch(function (error) {
      return localThemeSavedResult(error);
    });
  }

  function safeThemeFile(file) {
    var value = String(file || "").trim();
    if (!/^[a-z0-9][a-z0-9._-]*\.css$/i.test(value)) {
      return "official-orange.css";
    }
    return value;
  }

  function themeArray(result) {
    var data = normalizeData(result) || {};
    var source = Array.isArray(data.themes) ? data.themes : [];
    var themes = [];
    var seen = {};

    function add(theme) {
      var id = String(theme && theme.id || "").trim();
      var file = safeThemeFile(theme && theme.file || "");
      var name = String(theme && theme.name || "").trim();
      if (!id) {
        id = file.replace(/\.css$/i, "");
      }
      if (!id || seen[id]) {
        return;
      }
      seen[id] = true;
      themes.push({ id: id, name: name || id, file: file });
    }

    for (var builtInIndex = 0; builtInIndex < BUILT_IN_THEMES.length; builtInIndex += 1) {
      add(BUILT_IN_THEMES[builtInIndex]);
    }
    for (var i = 0; i < source.length; i += 1) {
      add(source[i]);
    }
    return themes;
  }

  function themeById(themeId) {
    var themes = state.themes && state.themes.length ? state.themes : themeArray(state.status);
    var requested = String(themeId || "").trim();
    for (var i = 0; i < themes.length; i += 1) {
      if (String(themes[i].id) === requested) {
        return themes[i];
      }
    }
    if (!state.status && requested && requested !== DEFAULT_THEME && /^[a-z0-9][a-z0-9._-]*$/i.test(requested)) {
      return { id: requested, name: requested, file: requested + ".css" };
    }
    return themes[0] || { id: DEFAULT_THEME, name: "Oficial laranja", file: "official-orange.css" };
  }

  function hasTheme(themeId) {
    var themes = state.themes && state.themes.length ? state.themes : themeArray(state.status);
    for (var i = 0; i < themes.length; i += 1) {
      if (String(themes[i].id) === String(themeId || "")) {
        return true;
      }
    }
    return false;
  }

  function themeUrlCandidates(file) {
    var encoded = encodeURIComponent(safeThemeFile(file));
    var suffix = "?v=" + encodeURIComponent(SKYTOOLS_UI_VERSION);
    return [
      "/webkit/SkyTools/themes/" + encoded + suffix,
      "webkit/SkyTools/themes/" + encoded + suffix,
      "SkyTools/themes/" + encoded + suffix,
      "themes/" + encoded + suffix
    ];
  }

  function isThemeCss(css) {
    var text = String(css || "");
    return text.indexOf("--skytools-") >= 0;
  }

  function themeScopeSelector(themeId) {
    return [
      'html.skytools-theme-scope[data-skytools-theme="' + String(themeId || DEFAULT_THEME) + '"]',
      'html.skytools-theme-scope[data-skytools-theme="' + String(themeId || DEFAULT_THEME) + '"] body',
      '.skytools-panel',
      '.skytools-fab',
      '.skytools-game-button',
      '.skytools-toast'
    ].join(", ");
  }

  function scopedThemeCss(theme, declarations) {
    return themeScopeSelector(theme.id) + " {\n" + declarations.join("\n") + "\n}";
  }

  function themeVarMapFromCss(css) {
    var matches = String(css || "").match(/--skytools-[a-z0-9-]+\s*:\s*[^;]+;/gi) || [];
    var vars = {};
    for (var i = 0; i < matches.length; i += 1) {
      var declaration = matches[i].replace(/\s*!important\s*;/i, ";").replace(/;$/, "");
      var colon = declaration.indexOf(":");
      if (colon <= 0) {
        continue;
      }
      var name = declaration.slice(0, colon).trim();
      var value = declaration.slice(colon + 1).trim();
      if (name.indexOf("--skytools-") === 0 && value) {
        vars[name] = value;
      }
    }
    return vars;
  }

  function builtInThemeVarMap(themeId) {
    var values = BUILT_IN_THEME_VARS[String(themeId || "")];
    var vars = {};
    if (!values) {
      return vars;
    }
    Object.keys(values).forEach(function (key) {
      vars["--skytools-" + key] = values[key];
    });
    return vars;
  }

  function applyThemeVars(vars) {
    vars = vars || state.themeVars || builtInThemeVarMap(state.themeId);
    if (!vars || !Object.keys(vars).length) {
      return;
    }
    state.themeVars = vars;
    var nodes = [document.documentElement];
    if (document.body) {
      nodes.push(document.body);
    }
    var scopedNodes = document.querySelectorAll(".skytools-panel,.skytools-fab,.skytools-game-button,.skytools-toast");
    for (var i = 0; i < scopedNodes.length; i += 1) {
      nodes.push(scopedNodes[i]);
    }
    Object.keys(vars).forEach(function (name) {
      for (var index = 0; index < nodes.length; index += 1) {
        if (nodes[index] && nodes[index].style && nodes[index].style.setProperty) {
          nodes[index].style.setProperty(name, vars[name], "important");
        }
      }
    });
  }

  function builtInThemeCss(theme) {
    var values = BUILT_IN_THEME_VARS[String(theme.id || "")];
    if (!values) {
      return "";
    }
    var declarations = [];
    Object.keys(values).forEach(function (key) {
      declarations.push("  --skytools-" + key + ": " + values[key] + " !important;");
    });
    return scopedThemeCss(theme, declarations);
  }

  function normalizeThemeCss(theme, css) {
    var matches = String(css || "").match(/--skytools-[a-z0-9-]+\s*:\s*[^;]+;/gi) || [];
    var declarations = [];
    var seen = {};
    for (var i = 0; i < matches.length; i += 1) {
      var declaration = matches[i].replace(/\s*!important\s*;/i, ";").trim();
      var name = declaration.split(":")[0].trim().toLowerCase();
      if (!name || seen[name]) {
        continue;
      }
      seen[name] = true;
      declarations.push("  " + declaration.replace(/;$/, " !important;"));
    }
    return declarations.length ? scopedThemeCss(theme, declarations) : "";
  }

  function fetchThemeCss(theme) {
    if (typeof fetch !== "function") {
      return Promise.reject(new Error("fetch indisponível"));
    }
    var urls = themeUrlCandidates(theme.file);
    var index = 0;

    function next() {
      if (index >= urls.length) {
        return Promise.reject(new Error("Tema não encontrado no webkit"));
      }
      var url = urls[index];
      index += 1;
      return fetch(url, { cache: "no-store" }).then(function (response) {
        if (!response || !response.ok) {
          throw new Error("HTTP " + (response && response.status || 0));
        }
        return response.text();
      }).then(function (css) {
        if (!isThemeCss(css)) {
          throw new Error("CSS de tema inválido");
        }
        return css;
      }).catch(function () {
        return next();
      });
    }

    return next();
  }

  function backendThemeCss(theme) {
    return call("SkyToolsTheme", { id: theme.id, file: theme.file }).then(function (result) {
      var data = normalizeData(result) || {};
      if (result && result.success === false || !isThemeCss(data.css)) {
        throw new Error(result && result.error || "Tema não retornou CSS válido");
      }
      return data.css;
    });
  }

  function loadThemeCss(theme) {
    var builtIn = builtInThemeCss(theme);
    if (builtIn) {
      return Promise.resolve(builtIn);
    }
    return fetchThemeCss(theme).catch(function () {
      return backendThemeCss(theme);
    }).then(function (css) {
      var normalized = normalizeThemeCss(theme, css);
      if (!normalized) {
        throw new Error("CSS de tema sem variáveis SkyTools");
      }
      return normalized;
    });
  }

  function ensureThemeStyle() {
    var oldLink = document.getElementById("skytools-theme-link");
    if (oldLink) {
      oldLink.remove();
    }

    var style = document.getElementById("skytools-theme-style");
    if (!style) {
      style = document.createElement("style");
      style.id = "skytools-theme-style";
      style.type = "text/css";
    }
    document.head.appendChild(style);
    return style;
  }

  function injectThemeCss(theme, css) {
    var style = ensureThemeStyle();
    style.dataset.themeId = theme.id || DEFAULT_THEME;
    style.dataset.themeFile = safeThemeFile(theme.file);
    style.textContent = String(css || "");
    state.themeCss = String(css || "");
    state.themeAppliedId = theme.id || DEFAULT_THEME;
    state.themeVars = themeVarMapFromCss(css);
    if (!Object.keys(state.themeVars).length) {
      state.themeVars = builtInThemeVarMap(state.themeAppliedId);
    }
    document.documentElement.setAttribute("data-skytools-theme", theme.id || DEFAULT_THEME);
    document.head.appendChild(style);
    applyThemeVars(state.themeVars);
  }

  function ensureAppliedTheme() {
    document.documentElement.classList.add("skytools-theme-scope");
    document.documentElement.setAttribute("data-skytools-theme", state.themeId || DEFAULT_THEME);
    applyThemeVars();
    var style = document.getElementById("skytools-theme-style");
    if (state.themeCss && (!style || style.textContent !== state.themeCss || style.dataset.themeId !== state.themeAppliedId)) {
      var theme = themeById(state.themeAppliedId || state.themeId);
      injectThemeCss(theme, state.themeCss);
      return;
    }
    if (style) {
      document.head.appendChild(style);
    }
  }

  function fallbackToDefaultTheme() {
    if (!state.status || state.themeId === DEFAULT_THEME) {
      return;
    }
    state.themeId = DEFAULT_THEME;
    writeStoredTheme(DEFAULT_THEME);
    applyTheme(DEFAULT_THEME);
    renderPanelBody();
  }

  function applyTheme(themeId) {
    var theme = themeById(themeId || state.themeId);
    var requestId = state.themeRequestId + 1;
    state.themeRequestId = requestId;
    state.themeId = theme.id || DEFAULT_THEME;
    document.documentElement.classList.add("skytools-theme-scope");
    document.documentElement.setAttribute("data-skytools-theme", state.themeId);
    applyThemeVars(builtInThemeVarMap(state.themeId));

    return loadThemeCss(theme).then(function (css) {
      if (requestId !== state.themeRequestId) {
        return { success: true };
      }
      injectThemeCss(theme, css);
      ensureAppliedTheme();
      return { success: true, data: { id: theme.id, file: theme.file } };
    }, function (error) {
      if (requestId === state.themeRequestId) {
        fallbackToDefaultTheme();
      }
      return { success: false, error: String(error) };
    });
  }

  function syncThemesFromStatus(result) {
    var data = normalizeData(result) || {};
    var backendThemeId = String(data.selectedThemeId || data.SelectedThemeId || "").trim();
    var storedThemeId = String(readStoredTheme() || "").trim();
    state.themes = themeArray(result);

    if (backendThemeId && backendThemeId !== DEFAULT_THEME && hasTheme(backendThemeId)) {
      state.themeId = backendThemeId;
      writeStoredTheme(backendThemeId);
    } else if (storedThemeId && hasTheme(storedThemeId)) {
      state.themeId = storedThemeId;
    } else if (backendThemeId === DEFAULT_THEME && hasTheme(backendThemeId)) {
      state.themeId = backendThemeId;
      writeStoredTheme(backendThemeId);
    }

    if (!hasTheme(state.themeId)) {
      state.themeId = DEFAULT_THEME;
      writeStoredTheme(DEFAULT_THEME);
    }
    applyTheme(state.themeId);
  }

  function gameArray(result) {
    var data = normalizeData(result);
    if (Array.isArray(data)) {
      return data;
    }
    if (data && Array.isArray(data.games)) {
      return data.games;
    }
    return [];
  }

  function gameAppId(game) {
    return game.appId || game.appid || "";
  }

  function rememberGameName(appid, name) {
    if (!appid || !name || /^App(ID)?\s+\d+/i.test(name)) {
      return;
    }
    state.nameCache[String(appid)] = name;
  }

  function displayGameName(game) {
    var appid = gameAppId(game);
    var name = game.gameName || game.name || state.nameCache[String(appid)] || "";
    return name || ("AppID " + appid);
  }

  function apiId(api) {
    return canonicalApiId((api && (api.id || api.Id)) || "");
  }

  function canonicalApiId(id) {
    var value = String(id || "").trim();
    if (value.toLowerCase() === "sushi") {
      return "ryzen";
    }
    return value;
  }

  function defaultApiOrder() {
    return ["skyapi", "morrenus", "ryzen"];
  }

  function readStoredApiOrder() {
    try {
      var parsed = JSON.parse(localStorage.getItem(API_ORDER_STORAGE_KEY) || "[]");
      return Array.isArray(parsed) && parsed.length ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  function writeStoredApiOrder(order) {
    if (!Array.isArray(order) || !order.length) {
      return;
    }
    try {
      localStorage.setItem(API_ORDER_STORAGE_KEY, JSON.stringify(order));
    } catch (_) {
      // Steam WebView storage can be unavailable in rare contexts; backend persistence remains authoritative.
    }
  }

  function orderApis(apis, order) {
    var list = (apis || []).slice();
    var preferredOrder = Array.isArray(order) && order.length ? order : defaultApiOrder();
    var rank = {};
    preferredOrder.forEach(function (id, index) {
      rank[canonicalApiId(id).toLowerCase()] = index;
    });
    list.sort(function (left, right) {
      var leftRank = rank[apiId(left).toLowerCase()];
      var rightRank = rank[apiId(right).toLowerCase()];
      if (leftRank == null) leftRank = 9999;
      if (rightRank == null) rightRank = 9999;
      if (leftRank !== rightRank) return leftRank - rightRank;
      return 0;
    });
    return list;
  }

  function reorderApiOrder(dragId, targetId, afterTarget) {
    dragId = String(dragId || "");
    targetId = String(targetId || "");
    if (!dragId || !targetId || dragId === targetId) {
      return false;
    }
    var order = (state.apiOrder || []).slice();
    var from = order.indexOf(dragId);
    var to = order.indexOf(targetId);
    if (from < 0 || to < 0) {
      return false;
    }
    order.splice(from, 1);
    if (from < to) {
      to -= 1;
    }
    if (afterTarget) {
      to += 1;
    }
    order.splice(to, 0, dragId);
    state.apiOrder = order;
    return true;
  }

  function apiListFromData(value) {
    return Array.isArray(value) ? value : [];
  }

  function isValidApi(api) {
    if (!api || typeof api !== "object") {
      return false;
    }
    var id = String(api.id || api.Id || "").trim();
    var name = String(api.name || api.Name || "").trim();
    var url = String(api.urlTemplate || api.UrlTemplate || "").trim();
    return !!(id && name && url && url.indexOf("<appid>") >= 0);
  }

  function collectApiOrderFromDom(panel) {
    var rows = panel ? panel.querySelectorAll(".skytools-api-draggable[data-api-id]") : [];
    var order = [];
    for (var i = 0; i < rows.length; i += 1) {
      var id = canonicalApiId(rows[i].getAttribute("data-api-id") || "");
      if (id) {
        order.push(id);
      }
    }
    return order;
  }

  function updateNameCacheFromInstalled(result) {
    var list = gameArray(result);
    var map = {};
    for (var i = 0; i < list.length; i += 1) {
      var appid = String(gameAppId(list[i]) || "");
      if (appid) {
        map[appid] = true;
      }
      rememberGameName(appid, list[i].gameName || list[i].name || "");
    }
    state.installedMap = map;
    state.installedLoadedAt = Date.now();
    if (state.status) {
      var statusData = normalizeData(state.status);
      if (statusData) {
        statusData.installedCount = list.length;
      }
    }
    updateGameButton();
  }

  function isCurrentAppAdded() {
    var appid = String(appIdFromUrl() || state.appid || "");
    return !!(appid && state.installedMap[appid]);
  }

  function friendlyError(result) {
    if (!result) {
      return t("A ação falhou.");
    }
    return translateMessage(result.error || result.message || "A ação falhou.");
  }

  function setActivity(kind, title, detail) {
    state.activityKind = kind || "idle";
    state.activityTitle = title ? translateMessage(title) : "SkyTools";
    state.activityDetail = detail ? translateMessage(detail) : "";
    updateActivity();
  }

  function showToast(title, message, kind) {
    if (document.querySelector(".skytools-panel")) {
      return;
    }

    var previous = document.querySelector(".skytools-toast");
    if (previous) {
      previous.remove();
    }

    var toast = document.createElement("div");
    toast.className = "skytools-toast skytools-toast-" + (kind || "info");
    toast.innerHTML =
      '<div class="skytools-toast-icon">' + icon(kind === "error" ? "error" : kind === "success" ? "check" : "status") + "</div>" +
      '<div><strong></strong><span></span></div>';
    toast.querySelector("strong").textContent = translateMessage(title);
    toast.querySelector("span").textContent = translateMessage(message || "");
    document.body.appendChild(toast);
    window.setTimeout(function () {
      if (toast.parentNode) {
        toast.remove();
      }
    }, 5200);
  }

  function setBusy(title, detail) {
    state.busy = true;
    setActivity("busy", title || "Processando", detail || "Executando em segundo plano...");
    updateBusyState();
  }

  function clearBusy(title, detail, kind) {
    state.busy = false;
    if (title !== false) {
      setActivity(kind || "idle", title || "Pronto", detail || "Aguardando uma ação.");
    }
    updateBusyState();
  }

  function buttonTarget() {
    var selectors = [
      ".game_purchase_action",
      ".game_area_purchase_game",
      ".game_area_purchase",
      "#game_area_purchase",
      ".rightcol"
    ];
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node) {
        return node;
      }
    }
    return null;
  }

  function removeGameButton() {
    var old = document.querySelector(".skytools-game-button");
    if (old) {
      old.remove();
    }
  }

  function removeLegacyWebkitButton() {
    var old = document.querySelector("#skytools-add-button");
    if (old) {
      old.remove();
    }
    var oldStyle = document.querySelector("#skytools-style");
    if (oldStyle) {
      oldStyle.remove();
    }
  }

  function updateGameButton() {
    var button = document.querySelector(".skytools-game-button");
    if (!button) {
      return;
    }
    var appid = String(appIdFromUrl() || state.appid || "");
    var added = isCurrentAppAdded();
    var adding = !!(appid && state.addingAppId === appid);
    button.classList.toggle("skytools-game-button-remove", added && !adding);
    button.classList.toggle("skytools-game-button-loading", adding);
    button.disabled = adding || state.busy;
    button.setAttribute("aria-busy", adding ? "true" : "false");
    if (adding) {
      button.innerHTML = icon("spinner", "spin") + "<span>" + escapeHtml(t("Adicionando...")) + "</span>";
      button.title = t("Adicionando este jogo via SkyTools");
      return;
    }
    button.innerHTML = icon(added ? "trash" : "add") + "<span>" + escapeHtml(added ? t("Remover via SkyTools") : t("Adicionar via SkyTools")) + "</span>";
    button.title = added ? t("Remover este jogo da biblioteca SkyTools") : t("Adicionar este jogo via SkyTools");
  }

  function refreshInstalledCache(force) {
    if (state.installedLoading) {
      return state.installedPromise || Promise.resolve(state.installed);
    }
    if (!force && state.installed) {
      updateGameButton();
      return Promise.resolve(state.installed);
    }
    state.installedLoading = true;
    state.installedPromise = call("SkyToolsInstalled", {}).then(function (result) {
      state.installed = result;
      updateNameCacheFromInstalled(result);
      return result;
    }, function (error) {
      log("SkyToolsInstalled: " + (error && error.message ? error.message : String(error)));
      return state.installed;
    }).then(function (result) {
      state.installedLoading = false;
      state.installedPromise = null;
      return result;
    });
    return state.installedPromise;
  }

  function refreshFixGames(force) {
    if (state.fixGamesLoading) {
      return state.fixGamesPromise || Promise.resolve(state.fixGames);
    }
    if (!force && state.fixGames) {
      return Promise.resolve(state.fixGames);
    }
    state.fixGamesLoading = true;
    state.fixGamesPromise = call("SkyToolsSteamInstalled", {}).then(function (result) {
      state.fixGames = result;
      return result;
    }, function (error) {
      log("SkyToolsSteamInstalled: " + (error && error.message ? error.message : String(error)));
      state.fixGames = { success: false, error: error && error.message ? error.message : String(error) };
      return state.fixGames;
    }).then(function (result) {
      state.fixGamesLoading = false;
      state.fixGamesPromise = null;
      return result;
    });
    return state.fixGamesPromise;
  }

  function ensureGameButton() {
    var appid = appIdFromUrl();
    if (!appid) {
      removeGameButton();
      return;
    }

    state.appid = appid;
    state.appName = appNameFromPage();

    if (document.querySelector(".skytools-game-button")) {
      updateGameButton();
      return;
    }

    var target = buttonTarget();
    if (!target) {
      return;
    }

    var button = document.createElement("button");
    button.type = "button";
    button.className = "skytools-game-button";
    button.addEventListener("click", function () {
      if (button.disabled || state.addingAppId) {
        showToast("SkyTools", "Aguarde a adição terminar.", "info");
        return;
      }
      if (isCurrentAppAdded()) {
        removeCurrentGame();
      } else {
        addCurrentGame();
      }
    });
    updateGameButton();
    target.appendChild(button);
    updateGameButton();
    if (!state.installed && !state.installedLoading) {
      refreshInstalledCache(false);
    }
  }

  function ensureFloatingMenu() {
    if (!document.body || document.querySelector(".skytools-fab")) {
      return;
    }

    var button = document.createElement("button");
    button.type = "button";
    button.className = "skytools-fab";
    button.innerHTML = '<span class="skytools-fab-logo"></span><span>SkyTools</span>';
    button.title = "SkyTools Plugin";
    button.addEventListener("click", togglePanel);
    document.body.appendChild(button);
  }

  function closePanel() {
    var panel = document.querySelector(".skytools-panel");
    if (panel) {
      panel.remove();
    }
  }

  function togglePanel() {
    if (document.querySelector(".skytools-panel")) {
      closePanel();
      return;
    }
    openPanel();
  }

  function findActionButton(target) {
    var node = target;
    while (node && node !== document) {
      if (node.getAttribute && node.getAttribute("data-action")) {
        return node;
      }
      node = node.parentNode;
    }
    return null;
  }

  function findTabButton(target) {
    var node = target;
    while (node && node !== document) {
      if (node.getAttribute && node.getAttribute("data-tab")) {
        return node;
      }
      node = node.parentNode;
    }
    return null;
  }

  function actionCard(action, iconName, title, detail, primary, loading) {
    return [
      '<button type="button" class="skytools-action-card ' + (primary ? "skytools-primary-action" : "") + (loading ? " skytools-action-loading" : "") + '" data-action="' + action + '"' + (loading ? ' aria-busy="true" disabled' : "") + '>',
      '  <span class="skytools-action-icon">' + icon(iconName, loading ? "spin" : "") + '</span>',
      '  <span class="skytools-action-copy"><strong>' + escapeHtml(title) + '</strong><small>' + escapeHtml(detail) + '</small></span>',
      '</button>'
    ].join("");
  }

  function metric(label, value) {
    return '<div class="skytools-metric"><span>' + escapeHtml(label) + '</span><strong>' + escapeHtml(value) + '</strong></div>';
  }

  function statusMetrics() {
    var data = normalizeData(state.status) || {};
    var app = currentPayload();
    var installedCount = state.installed ? gameArray(state.installed).length : data.installedCount;
    return [
      metric("Jogo atual", app.appid ? app.name + " (" + app.appid + ")" : "Nenhum"),
      metric("Integracao", data.integration || data.configuredIntegration || "Detectando"),
      metric("Jogos na biblioteca", installedCount != null ? installedCount : "-")
    ].join("");
  }

  function renderInstalledList() {
    var list = gameArray(state.installed);
    var query = String(state.libraryQuery || "").toLowerCase();
    if (!list || !list.length) {
      return '<div class="skytools-empty">Nenhum jogo carregado ainda.</div>';
    }

    var rows = [];
    for (var i = 0; i < list.length; i += 1) {
      var game = list[i];
      var appid = gameAppId(game);
      var name = displayGameName(game);
      if (query && String(name).toLowerCase().indexOf(query) < 0 && String(appid).indexOf(query) < 0) {
        continue;
      }
      var dlcCount = Number(game.dlcCount || game.DlcCount || game.dlc_count || 0);
      var pill = dlcCount === 1 ? "1 DLC" : dlcCount > 1 ? (dlcCount + " DLCs") : "0 DLCs";
      rows.push([
        '<div class="skytools-list-row">',
        '  <div class="skytools-row-icon">' + icon("library") + '</div>',
        '  <div class="skytools-row-main" title="' + escapeHtml(name) + '"><strong>' + escapeHtml(name) + '</strong><span>AppID ' + escapeHtml(appid) + '</span></div>',
        '  <span class="skytools-pill">' + escapeHtml(pill) + '</span>',
        '  <button type="button" class="skytools-row-action" title="Remover da Steam" data-action="remove-game" data-appid="' + escapeHtml(appid) + '" data-name="' + escapeHtml(name) + '">' + icon("trash") + '</button>',
        '</div>'
      ].join(""));
    }
    return rows.length ? rows.join("") : '<div class="skytools-empty">Nenhum jogo encontrado com esse filtro.</div>';
  }

  function renderApisList() {
    var data = normalizeData(state.apis);
    if (!data) {
      return '<div class="skytools-empty">Carregando APIs...</div>';
    }

    var builtIn = apiListFromData(data.builtIn).filter(isValidApi);
    var custom = apiListFromData(data.custom).filter(isValidApi);
    var allApis = orderApis(builtIn.concat(custom), state.apiOrder || readStoredApiOrder() || data.apiOrder || data.ApiOrder || defaultApiOrder());
    state.apiOrder = allApis.map(function (api) { return apiId(api); }).filter(Boolean);

    var apiRows = allApis.map(function (api) {
      var id = api.id || api.Id || "";
      var name = api.name || api.Name || "API sem nome";
      var url = api.urlTemplate || api.UrlTemplate || "";
      var enabled = api.enabled !== false && api.Enabled !== false;
      var nativeApi = api.native === true || api.Native === true;
      var useProxy = api.useProxy === true || api.UseProxy === true;
      var success = api.successCode || api.SuccessCode || 200;
      var unavailable = api.unavailableCode || api.UnavailableCode || 404;
      var detail = t(enabled ? "Ativa" : "Desativada") + " · " + t(nativeApi ? "API padrão" : "API personalizada") + " · HTTP " + success + "/" + unavailable + (useProxy ? " · proxy" : "");
      return [
        '<div class="skytools-custom-api-row skytools-api-draggable ' + (state.apiForm && state.apiForm.id === id ? "selected" : "") + '" draggable="true" data-api-id="' + escapeHtml(id) + '">',
        '  <span class="skytools-drag-handle" title="Arrastar para ordenar">' + icon("api") + '</span>',
        '  <div class="skytools-row-main"><strong>' + escapeHtml(name) + '</strong><span>' + escapeHtml(url || "URL não configurada") + '</span><small>' + escapeHtml(detail) + '</small></div>',
        '  <div class="skytools-row-actions">',
        '    <button type="button" class="skytools-row-action" title="Editar API" data-action="api-edit" data-api-id="' + escapeHtml(id) + '">' + icon("pencil") + '</button>',
        '    <button type="button" class="skytools-row-action skytools-danger-action" title="Excluir API" data-action="api-delete" data-api-id="' + escapeHtml(id) + '">' + icon("trash") + '</button>',
        '  </div>',
        '</div>'
      ].join("");
    });

    var form = state.apiForm;
    var editor = "";
    if (form) {
      editor = [
        '<div class="skytools-api-editor">',
        '  <div class="skytools-card-head"><div><strong>' + escapeHtml(form.id ? "Editar API" : "Adicionar API") + '</strong><span>Use <appid> na URL. Use <apikey> quando a fonte exigir chave.</span></div><button type="button" data-action="api-cancel">' + icon("close") + '<span>Fechar</span></button></div>',
        '  <div class="skytools-form-row">',
        '    <div class="skytools-field skytools-grow"><label>Nome</label><input class="skytools-input" data-field="apiName" value="' + escapeHtml(form.name || "") + '"></div>',
        '    <label class="skytools-setting-toggle"><span><strong>Ativa</strong><small>Usar nas instalações.</small></span><input type="checkbox" data-field="apiEnabled"' + (form.enabled === false ? "" : " checked") + '></label>',
        '  </div>',
        '  <div class="skytools-field"><label>URL da API</label><input class="skytools-input" data-field="apiUrl" placeholder="https://exemplo.com/download?appid=<appid>&key=<apikey>" value="' + escapeHtml(form.urlTemplate || "") + '"></div>',
        '  <div class="skytools-form-row">',
        '    <div class="skytools-field skytools-grow"><label>API key</label><input class="skytools-input" type="password" data-field="apiKey" value="' + escapeHtml(form.apiKey || "") + '"></div>',
        '    <label class="skytools-setting-toggle"><span><strong>Proxy</strong><small>Encapsular URL.</small></span><input type="checkbox" data-field="apiUseProxy"' + (form.useProxy ? " checked" : "") + '></label>',
        '  </div>',
        '  <div class="skytools-field"><label>URL do proxy</label><input class="skytools-input" data-field="apiProxyUrl" placeholder="https://proxy.exemplo.com/?url=<url>" value="' + escapeHtml(form.proxyUrlTemplate || "") + '"></div>',
        '  <div class="skytools-form-row">',
        '    <div class="skytools-field"><label>HTTP sucesso</label><input class="skytools-input" type="number" min="100" max="599" data-field="apiSuccessCode" value="' + escapeHtml(form.successCode || 200) + '"></div>',
        '    <div class="skytools-field"><label>HTTP indisponível</label><input class="skytools-input" type="number" min="100" max="599" data-field="apiUnavailableCode" value="' + escapeHtml(form.unavailableCode || 404) + '"></div>',
        '  </div>',
        '  <div class="skytools-button-row">',
        '    <button type="button" data-action="api-save">' + icon("check") + '<span>Salvar API</span></button>',
        '  </div>',
        '</div>'
      ].join("");
    }

    return [
      '<div class="skytools-api-panel">',
      '  <section class="skytools-api-card">',
      '    <div class="skytools-card-head"><div><strong>APIs de download</strong><span>Arraste para definir a ordem de tentativa.</span></div><button type="button" data-action="api-new">' + icon("add") + '<span>Adicionar</span></button></div>',
      apiRows.length ? '<div class="skytools-custom-api-list">' + apiRows.join("") + '</div>' : '<div class="skytools-empty">Nenhuma API configurada.</div>',
      editor,
      '  </section>',
      '</div>'
    ].join("");
  }

  function sourceArray(result) {
    var data = normalizeData(result);
    if (Array.isArray(data)) return data;
    if (data && Array.isArray(data.sources)) return data.sources;
    return [];
  }

  function sourceUrl(source) {
    source = source || {};
    return source.downloadUrl || source.DownloadUrl || source.downloadURL || source.sourceUrl || source.SourceUrl || source.url || source.Url || source.href || source.link || "";
  }

  function looksLikeArchive(value) {
    return /\.(zip|rar|7z)(?:\?|$)/i.test(String(value || ""));
  }

  function translateFixText(value) {
    var text = String(value || "");
    if (!text) {
      return text;
    }
    return text
      .replace(/\bGen[eé]rica\b/gi, t("Genérica"))
      .replace(/\bGeneric\b/gi, t("Generic"))
      .replace(/\bOnline\b/gi, t("Online"));
  }

  function formatFixLabel(source) {
    source = source || {};
    if (source.displayName) return translateFixText(source.displayName);
    var name = source.name || source.title || source.fileName || source.provider || "Fonte";
    var type = translateFixText(source.type || "");
    var size = source.size || "";
    var provider = source.provider || "Sky";
    var label = name;
    if (type) label += " - " + type;
    if (size) label += " - " + size;
    if (provider) label += " (" + provider + ")";
    return label;
  }

  function renderFixResults() {
    var sources = sourceArray(state.fixResults);
    if (!sources.length) {
      return '<div class="skytools-empty">Nenhuma correção Sky carregada.</div>';
    }
    return sources.map(function (source, index) {
      var title = formatFixLabel(source);
      var detail = source.fileName || [source.provider, translateFixText(source.type), source.size].filter(Boolean).join(" · ");
      var url = sourceUrl(source);
      var canApply = looksLikeArchive(url) || looksLikeArchive(title);
      var actionButton = canApply
        ? '  <button type="button" class="skytools-row-action" title="Aplicar na pasta do jogo" data-action="fix-prepare" data-source-index="' + index + '">' + icon("check") + '</button>'
        : '  <button type="button" class="skytools-row-action" title="Pacote não suportado" disabled>' + icon("error") + '</button>';
      return [
        '<div class="skytools-list-row">',
        '  <div class="skytools-row-icon">' + icon("fixes") + '</div>',
        '  <div class="skytools-row-main"><strong>' + escapeHtml(title) + '</strong><span>' + escapeHtml(detail || url) + '</span></div>',
        actionButton,
        '</div>'
      ].join("");
    }).join("");
  }

  function renderFixGamePicker() {
    var list = gameArray(state.fixGames);
    var query = String(state.fixQuery || "").toLowerCase();
    var visibleLimit = Math.max(40, Number(state.fixVisibleCount || 80));
    if (!list.length) {
      if (state.fixGamesLoading) {
        return '<div class="skytools-empty">Carregando jogos instalados...</div>';
      }
      var error = state.fixGames && state.fixGames.error ? String(state.fixGames.error) : "";
      return '<div class="skytools-empty">' + escapeHtml(error || "Nenhum jogo instalado encontrado nas bibliotecas Steam.") + '</div>';
    }

    var rows = [];
    var matched = 0;
    for (var i = 0; i < list.length; i += 1) {
      var game = list[i];
      var appid = gameAppId(game);
      var name = displayGameName(game);
      if (query && (String(name).toLowerCase().indexOf(query) < 0 && String(appid).indexOf(query) < 0)) {
        continue;
      }
      matched += 1;
      if (rows.length >= visibleLimit) {
        continue;
      }
      var removeButton = game.hasAppliedFix
        ? '  <button type="button" class="skytools-row-action" title="Remover correção e verificar integridade" data-action="fix-remove" data-appid="' + escapeHtml(appid) + '" data-name="' + escapeHtml(name) + '">' + icon("trash") + '</button>'
        : "";
      rows.push([
        '<div class="skytools-list-row">',
        '  <div class="skytools-row-icon">' + icon("library") + '</div>',
        '  <div class="skytools-row-main"><strong>' + escapeHtml(name) + '</strong><span>AppID ' + escapeHtml(appid) + '</span></div>',
        removeButton,
        '  <button type="button" class="skytools-row-action" title="Buscar correções" data-action="fix-game" data-appid="' + escapeHtml(appid) + '" data-name="' + escapeHtml(name) + '" data-game-path="' + escapeHtml(game.gamePath || game.installPath || "") + '">' + icon("fixes") + '</button>',
        '</div>'
      ].join(""));
    }
    if (matched > rows.length) {
      rows.push('<button type="button" class="skytools-load-more" data-action="fix-load-more">Mostrar mais ' + escapeHtml(String(Math.min(120, matched - rows.length))) + ' de ' + escapeHtml(String(matched - rows.length)) + '</button>');
    }
    state.fixMatchedCount = matched;
    return rows.length ? rows.join("") : '<div class="skytools-empty">Nenhum jogo encontrado com esse filtro.</div>';
  }

  function renderBackupPanel() {
    var backup = state.backup;
    var games = backup && Array.isArray(backup.games) ? backup.games : [];
    return [
      '<div class="skytools-grid skytools-tight-grid">',
      actionCard("backup-export", "backup", "Exportar backup", "Salvar biblioteca em JSON", false),
      actionCard("backup-restore", "backup", "Restaurar ausentes", games.length ? (games.length + " jogo(s) carregado(s)") : "Carregue um backup", false),
      '</div>',
      '<div class="skytools-form">',
      '  <label>Arquivo de backup</label>',
      '  <label class="skytools-file-picker">' + icon("folder") + '<span>Escolher arquivo</span><small data-role="backup-file-name">Nenhum arquivo escolhido</small><input type="file" accept="application/json,.json" data-action="backup-file"></label>',
      '</div>',
      backup ? '<pre class="skytools-result">' + escapeHtml(JSON.stringify({ createdAt: backup.createdAt, games: games.slice(0, 20), total: games.length }, null, 2)) + '</pre>' : '<div class="skytools-empty">Nenhum backup carregado.</div>'
    ].join("");
  }

  function renderDiagnostics() {
    var result = state.lastResult || state.status;
    if (!result) {
      return '<div class="skytools-empty">Sem dados ainda.</div>';
    }
    return '<pre class="skytools-result">' + escapeHtml(JSON.stringify(result, null, 2)) + '</pre>';
  }

  function renderThemeOptions() {
    var themes = themeArray(state.status);
    state.themes = themes;
    var rows = [];
    for (var i = 0; i < themes.length; i += 1) {
      var theme = themes[i];
      rows.push(
        '<option value="' + escapeHtml(theme.id) + '"' + (String(theme.id) === String(state.themeId) ? " selected" : "") + '>' +
        escapeHtml(theme.name || theme.id) +
        '</option>'
      );
    }
    return rows.join("");
  }

  function renderLanguageOptions() {
    var rows = [];
    var current = normalizeLanguageId(state.languageMode);
    for (var i = 0; i < SUPPORTED_LANGUAGES.length; i += 1) {
      var language = SUPPORTED_LANGUAGES[i];
      rows.push(
        '<option value="' + escapeHtml(language.id) + '"' + (language.id === current ? " selected" : "") + '>' +
        escapeHtml(language.id === "auto" ? t(language.label) : language.label) +
        '</option>'
      );
    }
    return rows.join("");
  }

  function renderSettings() {
    return [
      '<div class="skytools-form">',
      '  <div class="skytools-field"><label>Idioma</label><select class="skytools-input" data-field="languageSelect">' + renderLanguageOptions() + '</select></div>',
      '  <div class="skytools-field"><label>Tema</label><select class="skytools-input" data-field="themeSelect">' + renderThemeOptions() + '</select></div>',
      '</div>',
      '<div class="skytools-grid skytools-tight-grid">',
      actionCard("integration-skytools", "plug", "Ativar SkyTools", "Instalar integração Steam", false),
      actionCard("integration-steamtools", "plug", "Ativar SteamTools", "Alternativa compatível", false),
      '</div>',
      renderDiagnostics()
    ].join("");
  }

  function tabMarkup(tab) {
    var app = currentPayload();
    if (tab === "biblioteca") {
      return [
        '<div class="skytools-section-head"><strong>Jogos instalados</strong><button data-action="installed" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-field"><label>Buscar na biblioteca</label><input class="skytools-input" data-field="librarySearch" placeholder="Digite nome ou AppID" value="' + escapeHtml(state.libraryQuery || "") + '"></div>',
        '<div class="skytools-list" data-role="installed-list">' + renderInstalledList() + '</div>'
      ].join("");
    }

    if (tab === "correcoes") {
      return [
        '<div class="skytools-section-head"><strong>Correções para jogo</strong><button data-action="refresh-fix-games" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-field"><label>Buscar jogo instalado</label><input class="skytools-input" data-field="fixSearch" placeholder="Digite nome ou AppID" value="' + escapeHtml(state.fixQuery || "") + '"></div>',
        '<div class="skytools-list skytools-scroll-list skytools-fix-game-list" data-role="fix-game-list">' + renderFixGamePicker() + '</div>',
        '<div class="skytools-section-head"><strong>' + escapeHtml(state.selectedFixGame ? ("Resultados para " + state.selectedFixGame.name) : "Resultados") + '</strong></div>',
        '<div class="skytools-list">' + renderFixResults() + '</div>'
      ].join("");
    }

    if (tab === "apis") {
      return [
        '<div class="skytools-section-head"><strong>APIs</strong><button data-action="apis" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-list">' + renderApisList() + '</div>'
      ].join("");
    }

    if (tab === "configuracoes") {
      return [
        '<div class="skytools-section-head"><strong>Configurações</strong><button data-action="status" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        renderSettings()
      ].join("");
    }

    if (tab === "backup") {
      return [
        '<div class="skytools-section-head"><strong>Backup</strong><button data-action="backup-export" type="button">' + icon("backup") + '<span>Exportar</span></button></div>',
        renderBackupPanel()
      ].join("");
    }

    return [
      '<div class="skytools-current">',
      '  <div class="skytools-current-art">' + icon("library") + '</div>',
      '  <div><span>App atual</span><strong>' + escapeHtml(app.appid ? app.name : "Nenhum jogo aberto") + '</strong><small>' + escapeHtml(app.appid ? "AppID " + app.appid : "Abra uma página de jogo para adicionar.") + '</small></div>',
      '</div>',
      '<div class="skytools-metrics">' + statusMetrics() + '</div>',
      '<div class="skytools-grid">',
      actionCard(
        "add",
        state.addingAppId && app.appid && state.addingAppId === String(app.appid) ? "spinner" : "add",
        state.addingAppId && app.appid && state.addingAppId === String(app.appid) ? "Adicionando..." : "Adicionar jogo",
        state.addingAppId && app.appid && state.addingAppId === String(app.appid) ? "Baixando e instalando manifests" : (app.appid ? "Instalar manifests na Steam" : "Disponível em páginas de jogo"),
        true,
        !!(state.addingAppId && app.appid && state.addingAppId === String(app.appid))
      ),
      actionCard("correcoes-tab", "fixes", "Correções", "Buscar por jogo instalado", false),
      '</div>'
    ].join("");
  }

  function panelMarkup() {
    return [
      '<div class="skytools-panel-shell">',
      '  <div class="skytools-panel-header">',
      '    <div class="skytools-brand"><span class="skytools-logo"></span><div><strong>SkyTools Plugin</strong><small>Steam integrado</small></div></div>',
      '    <div class="skytools-header-actions"><span class="skytools-status-dot"></span><button class="skytools-panel-close" type="button" title="Fechar">' + icon("close") + '</button></div>',
      '  </div>',
      '  <div class="skytools-tabs">',
      '    <button type="button" data-tab="inicio">Início</button>',
      '    <button type="button" data-tab="biblioteca">Biblioteca</button>',
      '    <button type="button" data-tab="correcoes">Correções</button>',
      '    <button type="button" data-tab="apis">APIs</button>',
      '    <button type="button" data-tab="backup">Backup</button>',
      '    <button type="button" data-tab="configuracoes">Configurações</button>',
      '  </div>',
      '  <div class="skytools-panel-body"></div>',
      '  <div class="skytools-activity">',
      '    <div class="skytools-activity-icon">' + icon("status") + '</div>',
      '    <div class="skytools-activity-copy"><strong></strong><span></span></div>',
      '    <div class="skytools-progress"><span></span></div>',
      '  </div>',
      '</div>'
    ].join("");
  }

  function updateTabs() {
    var panel = document.querySelector(".skytools-panel");
    if (!panel) {
      return;
    }

    var buttons = panel.querySelectorAll("[data-tab]");
    for (var i = 0; i < buttons.length; i += 1) {
      buttons[i].className = buttons[i].getAttribute("data-tab") === state.activeTab ? "active" : "";
    }
  }

  function resetPanelChromeText(panel) {
    if (!panel) {
      return;
    }
    var subtitle = panel.querySelector(".skytools-brand small");
    if (subtitle) {
      subtitle.textContent = "Steam integrado";
    }
    var close = panel.querySelector(".skytools-panel-close");
    if (close) {
      close.setAttribute("title", "Fechar");
    }
    var labels = {
      inicio: "Início",
      biblioteca: "Biblioteca",
      correcoes: "Correções",
      apis: "APIs",
      backup: "Backup",
      configuracoes: "Configurações"
    };
    var buttons = panel.querySelectorAll("[data-tab]");
    for (var i = 0; i < buttons.length; i += 1) {
      var key = buttons[i].getAttribute("data-tab") || "";
      if (labels[key]) {
        buttons[i].textContent = labels[key];
      }
    }
  }

  function updateActivity() {
    var panel = document.querySelector(".skytools-panel");
    if (!panel) {
      return;
    }

    var activity = panel.querySelector(".skytools-activity");
    var title = panel.querySelector(".skytools-activity-copy strong");
    var detail = panel.querySelector(".skytools-activity-copy span");
    var iconNode = panel.querySelector(".skytools-activity-icon");
    var dot = panel.querySelector(".skytools-status-dot");
    if (activity) {
      activity.className = "skytools-activity skytools-activity-" + state.activityKind;
    }
    if (title) {
      title.textContent = state.activityTitle;
    }
    if (detail) {
      detail.textContent = state.activityDetail;
    }
    if (iconNode) {
      iconNode.innerHTML = icon(state.activityKind === "busy" ? "spinner" : state.activityKind === "success" ? "check" : state.activityKind === "error" ? "error" : "status", state.activityKind === "busy" ? "spin" : "");
    }
    if (dot) {
      dot.className = "skytools-status-dot skytools-dot-" + state.activityKind;
    }
  }

  function updateBusyState() {
    var panel = document.querySelector(".skytools-panel");
    if (!panel) {
      return;
    }

    var actions = panel.querySelectorAll("[data-action]");
    for (var i = 0; i < actions.length; i += 1) {
      actions[i].disabled = state.busy;
    }
  }

  function renderPanelBody() {
    var panel = document.querySelector(".skytools-panel");
    if (!panel) {
      return;
    }
    var body = panel.querySelector(".skytools-panel-body");
    if (body) {
      body.innerHTML = tabMarkup(state.activeTab);
    }
    resetPanelChromeText(panel);
    updateTabs();
    updateActivity();
    updateBusyState();
    localizeDom(panel);
  }

  function renderResult(result, title) {
    state.lastResult = result;

    if (result && result.success === false) {
      setActivity("error", title || "Falha", friendlyError(result));
      showToast("SkyTools", friendlyError(result), "error");
      renderPanelBody();
      return;
    }

    var data = normalizeData(result);
    var detail = "Ação concluída.";
    if (Array.isArray(data)) {
      detail = translateMessage(data.length + " item(ns) encontrados.");
    } else if (data && data.installedCount != null) {
      detail = data.installedCount + " jogos adicionados. Integração: " + (data.integration || "-") + ".";
      if (data.appNameCacheCount != null) {
        detail += " Cache: " + data.appNameCacheCount + " nomes.";
      }
    } else if (data && data.manifestCount != null) {
      detail = "Manifests: " + data.manifestCount + ". DLCs: " + (data.dlcCount || 0) + ".";
    } else if (data && data.message) {
      detail = translateMessage(data.message);
    } else if (data && data.path) {
      detail = data.path;
    }

    setActivity("success", title || "Concluído", detail);
    showToast("SkyTools", detail, "success");
    renderPanelBody();
  }

  function runAction(title, method, payload, after) {
    if (state.busy) {
      showToast("SkyTools", "Aguarde a ação atual terminar.", "info");
      return Promise.resolve();
    }

    setBusy(title, method === "SkyToolsRepair" ? "Executando correção externa..." : "Executando em segundo plano.");
    return call(method, payload).then(function (result) {
      clearBusy();
      if (typeof after === "function" && result && result.success !== false) {
        return Promise.resolve(after(result)).then(function () {
          renderResult(result, title);
          return result;
        });
      }
      renderResult(result, title);
      return result;
    }, function (error) {
      clearBusy();
      var result = { success: false, error: error && error.message ? error.message : String(error) };
      log(result.error);
      renderResult(result, title);
      return result;
    });
  }

  function addCurrentGame() {
    var payload = currentPayload();
    if (!payload.appid) {
      showToast("SkyTools", "Abra a página de um jogo na loja Steam.", "error");
      return;
    }
    if (state.addingAppId) {
      showToast("SkyTools", "Aguarde a adição terminar.", "info");
      return Promise.resolve();
    }
    state.addingAppId = String(payload.appid);
    updateGameButton();
    renderPanelBody();
    return runAction("Adicionando jogo", "SkyToolsAddGame", payload, function () {
      return refreshInstalledCache(true).then(function () {
        state.installedMap[String(payload.appid)] = true;
        rememberGameName(payload.appid, payload.name);
        updateGameButton();
      });
    }).then(function (result) {
      state.addingAppId = "";
      updateGameButton();
      renderPanelBody();
      return result;
    }, function (error) {
      state.addingAppId = "";
      updateGameButton();
      renderPanelBody();
      throw error;
    });
  }

  function removeCurrentGame() {
    var payload = currentPayload();
    if (!payload.appid) {
      showToast("SkyTools", "Abra a página de um jogo na loja Steam.", "error");
      return;
    }
    return runAction("Removendo jogo", "SkyToolsRemoveGame", payload, function () {
      delete state.installedMap[String(payload.appid)];
      return refreshInstalledCache(true).then(function () {
        updateGameButton();
      });
    });
  }

  function loadStatus(render) {
    return call("SkyToolsStatus", {}).then(function (result) {
      state.status = result;
      syncThemesFromStatus(result);
      syncLanguageFromStatus(result);
      if (render !== false) {
        renderPanelBody();
      }
      return result;
    }, function (error) {
      state.status = { success: false, error: String(error) };
      if (render !== false) {
        renderPanelBody();
      }
    });
  }

  function readField(panel, name) {
    var input = panel && panel.querySelector('[data-field="' + name + '"]');
    if (!input) {
      return "";
    }
    if (input.type === "checkbox") {
      return input.checked;
    }
    return input.value || "";
  }

  function currentApiForm(panel) {
    var existing = state.apiForm || {};
    return {
      id: existing.id || "",
      native: existing.native === true,
      name: readField(panel, "apiName"),
      urlTemplate: readField(panel, "apiUrl"),
      apiKey: readField(panel, "apiKey"),
      enabled: readField(panel, "apiEnabled") !== false,
      useProxy: readField(panel, "apiUseProxy") === true,
      proxyUrlTemplate: readField(panel, "apiProxyUrl"),
      successCode: Number(readField(panel, "apiSuccessCode")) || 200,
      unavailableCode: Number(readField(panel, "apiUnavailableCode")) || 404
    };
  }

  function apiById(id) {
    var data = normalizeData(state.apis) || {};
    var builtIn = data.builtIn || [];
    var custom = data.custom || [];
    var all = builtIn.concat(custom);
    var wanted = canonicalApiId(id).toLowerCase();
    for (var i = 0; i < all.length; i += 1) {
      if (apiId(all[i]).toLowerCase() === wanted) {
        return all[i];
      }
    }
    return null;
  }

  function setApiOrderOnState(order) {
    var data = normalizeData(state.apis);
    if (data) {
      data.apiOrder = order.slice();
      data.ApiOrder = order.slice();
    }
  }

  function saveApiOrder(order) {
    var nextOrder = Array.isArray(order) && order.length ? order.slice() : (state.apiOrder || []).slice();
    if (!nextOrder.length) {
      return;
    }
    state.apiOrder = nextOrder;
    setApiOrderOnState(nextOrder);
    setActivity("busy", "Salvando ordem", "Atualizando prioridade das APIs...");
    log("SkyTools API order: " + nextOrder.join(","));
    call("SkyToolsSaveApiSettings", {
      apiOrder: nextOrder,
      ApiOrder: nextOrder,
      apiOrderText: nextOrder.join(","),
      apiOrderJson: JSON.stringify(nextOrder)
    }).then(function (result) {
      if (result && result.success === false) {
        renderResult(result, "Falha ao salvar ordem");
        return;
      }
      state.apis = result;
      state.apiOrder = nextOrder;
      writeStoredApiOrder(nextOrder);
      setApiOrderOnState(nextOrder);
      setActivity("success", "Ordem salva", "A prioridade das APIs foi atualizada.");
      renderPanelBody();
    }, function (error) {
      renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Falha ao salvar ordem");
    });
  }

  function openExternal(url) {
    url = String(url || "").trim();
    if (!url) {
      showToast("SkyTools", "Link indisponível.", "error");
      return;
    }
    window.open(url, "_blank");
  }

  function copyText(text) {
    text = String(text || "");
    if (!text) {
      showToast("SkyTools", "Link indisponível.", "error");
      return;
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () {
        showToast("SkyTools", "Link copiado.", "success");
      }, function () {
        window.prompt("Copie o link:", text);
      });
      return;
    }
    window.prompt("Copie o link:", text);
  }

  function loadFixSources(action, title, payload) {
    return runAction(title, "SkyToolsFixSources", payload, function (result) {
      state.fixResults = result;
      state.activeTab = "correcoes";
    });
  }

  function parseBackupFile(file) {
    if (!file) {
      return;
    }
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var data = JSON.parse(String(reader.result || "{}"));
        var games = Array.isArray(data.games) ? data.games : [];
        if (!games.length) {
          throw new Error("Backup sem jogos.");
        }
        state.backup = data;
        setActivity("success", "Backup carregado", games.length + " jogo(s) no arquivo.");
        renderPanelBody();
      } catch (error) {
        renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Backup inválido");
      }
    };
    reader.onerror = function () {
      renderResult({ success: false, error: "Não foi possível ler o arquivo." }, "Backup inválido");
    };
    reader.readAsText(file);
  }

  function restoreBackup() {
    if (!state.backup) {
      showToast("SkyTools", "Carregue um arquivo de backup primeiro.", "error");
      return;
    }
    return runAction("Restaurando backup", "SkyToolsBackupRestore", { backup: state.backup }, function () {
      return refreshInstalledCache(true);
    });
  }

  function ensureTabData(tab) {
    if (tab === "biblioteca" && !state.installed && !state.installedLoading) {
      setBusy("Carregando biblioteca", "Buscando jogos adicionados.");
      refreshInstalledCache(true).then(function (result) {
        clearBusy();
        state.installed = result;
        updateNameCacheFromInstalled(result);
        renderResult(result, "Biblioteca carregada");
      });
      return;
    }

    if (tab === "correcoes" && !state.fixGames && !state.fixGamesLoading) {
      setBusy("Carregando jogos instalados", "Lendo appmanifests da Steam.");
      refreshFixGames(true).then(function (result) {
        var count = gameArray(result).length;
        clearBusy("Jogos instalados carregados", count + " jogo(s) encontrados.", "success");
        renderPanelBody();
      }, function (error) {
        clearBusy(false);
        renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Falha ao carregar jogos instalados");
      });
      return;
    }

    if (tab === "apis" && !state.apisLoading) {
      state.apisLoading = true;
      runAction("Carregando APIs", "SkyToolsApis", {}, function (result) {
        state.apis = result;
      }).then(function () {
        state.apisLoading = false;
      });
    }
  }

  function openPanel() {
    closePanel();

    var panel = document.createElement("div");
    panel.className = "skytools-panel";
    panel.innerHTML = panelMarkup();
    document.body.appendChild(panel);

    panel.querySelector(".skytools-panel-close").addEventListener("click", closePanel);
    panel.addEventListener("click", function (event) {
      var tab = findTabButton(event.target);
      if (tab) {
        state.activeTab = tab.getAttribute("data-tab");
        renderPanelBody();
        ensureTabData(state.activeTab);
        return;
      }

      var button = findActionButton(event.target);
      if (!button) {
        return;
      }
      if (button.disabled) {
        return;
      }

      var action = button.getAttribute("data-action");
      var payload = currentPayload();
      if (action === "add") addCurrentGame();
      if (action === "correcoes-tab") {
        state.activeTab = "correcoes";
        renderPanelBody();
        ensureTabData("correcoes");
      }
      if (action === "refresh-fix-games") {
        state.fixVisibleCount = 80;
        runAction("Carregando jogos instalados", "SkyToolsSteamInstalled", {}, function (result) {
          state.fixGames = result;
          state.activeTab = "correcoes";
        });
      }
      if (action === "installed") runAction("Carregando biblioteca", "SkyToolsInstalled", {}, function (result) { state.installed = result; updateNameCacheFromInstalled(result); state.activeTab = "biblioteca"; });
      if (action === "remove-game") runAction("Removendo jogo", "SkyToolsRemoveGame", { appid: button.getAttribute("data-appid"), name: button.getAttribute("data-name") }, function () {
        delete state.installedMap[String(button.getAttribute("data-appid") || "")];
        return refreshInstalledCache(true);
      });
      if (action === "apis") runAction("Carregando APIs", "SkyToolsApis", {}, function (result) { state.apis = result; state.activeTab = "apis"; });
      if (action === "api-edit") {
        var selectedApi = apiById(button.getAttribute("data-api-id"));
        if (selectedApi) {
          state.apiForm = {
            id: selectedApi.id || selectedApi.Id || "",
            native: selectedApi.native === true || selectedApi.Native === true,
            name: selectedApi.name || selectedApi.Name || "",
            urlTemplate: selectedApi.urlTemplate || selectedApi.UrlTemplate || "",
            apiKey: selectedApi.apiKey || selectedApi.ApiKey || "",
            enabled: selectedApi.enabled !== false && selectedApi.Enabled !== false,
            useProxy: selectedApi.useProxy === true || selectedApi.UseProxy === true,
            proxyUrlTemplate: selectedApi.proxyUrlTemplate || selectedApi.ProxyUrlTemplate || "",
            successCode: selectedApi.successCode || selectedApi.SuccessCode || 200,
            unavailableCode: selectedApi.unavailableCode || selectedApi.UnavailableCode || 404
          };
          renderPanelBody();
        }
      }
      if (action === "api-delete") {
        if (state.busy) {
          showToast("SkyTools", "Aguarde a ação atual terminar.", "info");
          return;
        }
        setBusy("Excluindo API", "Executando em segundo plano.");
        call("SkyToolsDeleteApi", { id: canonicalApiId(button.getAttribute("data-api-id")) }).then(function (result) {
          clearBusy();
          if (result && result.success === false) {
            renderResult(result, "Excluindo API");
            return;
          }
          state.apiForm = null;
          state.apis = null;
          return call("SkyToolsApis", {}).then(function (apis) {
            state.apis = apis;
            renderResult(result, "Excluindo API");
          });
        }, function (error) {
          clearBusy();
          renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Excluindo API");
        });
      }
      if (action === "api-new") {
        var apiData = normalizeData(state.apis) || {};
        var customCount = (apiData.custom || []).length;
        state.apiForm = { id: "", native: false, name: "API personalizada " + (customCount + 1), urlTemplate: "", apiKey: "", enabled: true, useProxy: false, proxyUrlTemplate: "", successCode: 200, unavailableCode: 404 };
        renderPanelBody();
      }
      if (action === "api-cancel") { state.apiForm = null; renderPanelBody(); }
      if (action === "api-save") {
        if (state.busy) {
          showToast("SkyTools", "Aguarde a ação atual terminar.", "info");
          return;
        }
        var apiPayload = currentApiForm(panel);
        setBusy("Salvando API", "Executando em segundo plano.");
        call("SkyToolsSaveApi", apiPayload).then(function (result) {
          clearBusy();
          if (result && result.success === false) {
            renderResult(result, "Salvando API");
            return;
          }
          state.apiForm = null;
          state.apis = null;
          return call("SkyToolsApis", {}).then(function (apis) {
            state.apis = apis;
            renderResult(result, "Salvando API");
          });
        }, function (error) {
          clearBusy();
          renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Salvando API");
        });
      }
      if (action === "api-save-settings") runAction("Salvando preferências", "SkyToolsSaveApiSettings", { apiOrder: state.apiOrder || [] }, function (result) { state.apis = result; });
      if (action === "fixes") loadFixSources("fixes", "Buscando correções", payload);
      if (action === "online") loadFixSources("online", "Buscando correções Sky", payload);
      if (action === "denuvo") loadFixSources("denuvo", "Buscando correções Sky", payload);
      if (action === "fix-load-more") {
        var nextLimit = Math.max(80, Number(state.fixVisibleCount || 80));
        if (state.fixMatchedCount && nextLimit >= state.fixMatchedCount) {
          return;
        }
        state.fixVisibleCount = nextLimit + 120;
        var loadMoreList = panel.querySelector('[data-role="fix-game-list"]');
        if (loadMoreList) {
          loadMoreList.innerHTML = renderFixGamePicker();
          localizeDom(loadMoreList);
        }
      }
      if (action === "fix-open") openExternal(button.getAttribute("data-url"));
      if (action === "fix-copy") copyText(button.getAttribute("data-url"));
      if (action === "fix-game") {
        state.selectedFixGame = {
          appid: button.getAttribute("data-appid") || "",
          name: button.getAttribute("data-name") || "",
          gamePath: button.getAttribute("data-game-path") || ""
        };
        loadFixSources("fixes", "Buscando correções Sky", state.selectedFixGame);
      }
      if (action === "fix-remove") {
        var removeAppid = button.getAttribute("data-appid") || "";
        var removeName = button.getAttribute("data-name") || "";
        runAction("Removendo correção", "SkyToolsRemoveFix", {
          appid: removeAppid,
          name: removeName
        }, function (result) {
          var data = normalizeData(result) || {};
          var validateUrl = data.validateUrl || ("steam://validate/" + removeAppid);
          try {
            window.location.href = validateUrl;
          } catch (_) {}
          return refreshInstalledCache(true).then(function (fresh) {
            state.fixGames = fresh;
          });
        });
      }
      if (action === "fix-prepare") {
        var source = sourceArray(state.fixResults)[Number(button.getAttribute("data-source-index") || 0)];
        var selected = state.selectedFixGame || payload;
        var sourceJson = JSON.stringify(source || {});
        runAction("Aplicando Sky", "SkyToolsApplyFix", {
          appid: selected.appid,
          name: selected.name,
          gamePath: selected.gamePath || "",
          source: source || {},
          sourceJson: sourceJson,
          downloadUrl: sourceUrl(source || {}),
          sourceName: source && (source.name || source.title) || "",
          sourceType: source && source.type || "",
          sourceKind: source && source.kind || "",
          fileName: source && (source.fileName || source.filename || "") || "",
          displayName: source && source.displayName || "",
          provider: source && source.provider || "",
          size: source && source.size || ""
        }, function (result) {
          var data = normalizeData(result) || {};
          if (data.action === "copy" && data.url) {
            copyText(data.url);
          }
        });
      }
      if (action === "backup") { state.activeTab = "backup"; renderPanelBody(); }
      if (action === "backup-export") runAction("Exportando backup", "SkyToolsBackupExport", {});
      if (action === "backup-restore") restoreBackup();
      if (action === "integration-skytools") runAction("Ativando SkyTools", "SkyToolsIntegration", { target: "SkyTools" }, function (result) { state.status = result; });
      if (action === "integration-steamtools") runAction("Ativando SteamTools", "SkyToolsIntegration", { target: "SteamTools" }, function (result) { state.status = result; });
      if (action === "status") runAction("Coletando configurações", "SkyToolsStatus", {}, function (result) { state.status = result; syncThemesFromStatus(result); syncLanguageFromStatus(result); });
    });

    panel.addEventListener("change", function (event) {
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "languageSelect") {
        state.languageMode = normalizeLanguageId(event.target.value || DEFAULT_LANGUAGE);
        writeStoredLanguage(state.languageMode);
        updateGameButton();
        renderPanelBody();
        setBusy("Salvando idioma", "Executando em segundo plano.");
        call("SkyToolsSaveApiSettings", { selectedLanguage: state.languageMode, language: state.languageMode }).then(function (result) {
          clearBusy("Idioma aplicado", "Preferência salva.", "success");
          if (result && result.success === false) {
            setActivity("error", "Idioma aplicado", "Não foi possível salvar o idioma.");
          }
        }, function (error) {
          clearBusy(false);
          setActivity("error", "Idioma aplicado", error && error.message ? error.message : "Não foi possível salvar o idioma.");
        });
        return;
      }
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "themeSelect") {
        state.themeId = event.target.value || DEFAULT_THEME;
        writeStoredTheme(state.themeId);
        var selectedTheme = themeById(state.themeId);
        applyTheme(state.themeId).then(function (result) {
          if (result && result.success === false) {
            setActivity("error", "Tema não aplicado", result.error || "Voltando ao tema oficial.");
            return;
          }
          saveThemePreference(selectedTheme.id).then(function (saveResult) {
            if (saveResult && saveResult.success === false) {
              setActivity("error", "Tema aplicado", "Não foi possível salvar para a próxima inicialização.");
              return;
            }
            setActivity("success", "Tema aplicado", selectedTheme.name || "Tema selecionado.");
          });
        });
      }
      var actionNode = findActionButton(event.target);
      if (actionNode && actionNode.getAttribute("data-action") === "backup-file") {
        var fileNameNode = panel.querySelector('[data-role="backup-file-name"]');
        if (fileNameNode) {
          fileNameNode.textContent = actionNode.files && actionNode.files[0] ? actionNode.files[0].name : t("Nenhum arquivo escolhido");
        }
        parseBackupFile(actionNode.files && actionNode.files[0]);
      }
    });

    panel.addEventListener("input", function (event) {
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "fixSearch") {
        state.fixQuery = event.target.value || "";
        state.fixVisibleCount = 80;
        var fixList = panel.querySelector('[data-role="fix-game-list"]');
        if (fixList) {
          fixList.innerHTML = renderFixGamePicker();
          localizeDom(fixList);
        }
      }
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "librarySearch") {
        state.libraryQuery = event.target.value || "";
        var installedList = panel.querySelector('[data-role="installed-list"]');
        if (installedList) {
          installedList.innerHTML = renderInstalledList();
          localizeDom(installedList);
        }
      }
    });

    panel.addEventListener("scroll", function (event) {
      var target = event.target;
      if (!target || !target.getAttribute || target.getAttribute("data-role") !== "fix-game-list") {
        return;
      }
      if (target.scrollTop + target.clientHeight < target.scrollHeight - 72) {
        return;
      }
      var oldLimit = Number(state.fixVisibleCount || 80);
      if (state.fixMatchedCount && oldLimit >= state.fixMatchedCount) {
        return;
      }
      state.fixVisibleCount = oldLimit + 120;
      var oldTop = target.scrollTop;
      target.innerHTML = renderFixGamePicker();
      localizeDom(target);
      target.scrollTop = oldTop;
    }, true);

    panel.addEventListener("mousedown", function (event) {
      if (event.target && event.target.closest && event.target.closest(".skytools-row-actions,button,input,textarea,select")) {
        return;
      }
      var row = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      if (!row) {
        return;
      }
      row.draggable = true;
    });

    panel.addEventListener("mouseup", function (event) {
      var row = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      if (row) {
        row.draggable = true;
      }
    });

    panel.addEventListener("dragstart", function (event) {
      var row = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      if (!row || (event.target && event.target.closest && event.target.closest(".skytools-row-actions,button,input,textarea,select"))) {
        return;
      }
      row.draggable = true;
      state.draggingApiId = row.getAttribute("data-api-id") || "";
      state.pendingApiDrop = null;
      row.classList.add("dragging");
      if (event.dataTransfer) {
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("text/plain", state.draggingApiId);
      }
    });

    panel.addEventListener("dragover", function (event) {
      var target = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      var dragging = panel.querySelector(".skytools-api-draggable.dragging");
      if (!target || !dragging || target === dragging) {
        return;
      }
      event.preventDefault();
      if (event.dataTransfer) {
        event.dataTransfer.dropEffect = "move";
      }
      var rect = target.getBoundingClientRect();
      var afterTarget = event.clientY > rect.top + (rect.height / 2);
      state.pendingApiDrop = {
        targetId: target.getAttribute("data-api-id") || "",
        afterTarget: afterTarget
      };
      target.parentNode.insertBefore(dragging, afterTarget ? target.nextSibling : target);
    });

    panel.addEventListener("drop", function (event) {
      var dragging = panel.querySelector(".skytools-api-draggable.dragging");
      if (dragging) {
        event.preventDefault();
        var target = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
        if (target && target !== dragging && target.parentNode) {
          var rect = target.getBoundingClientRect();
          var afterTarget = event.clientY > rect.top + (rect.height / 2);
          state.pendingApiDrop = {
            targetId: target.getAttribute("data-api-id") || "",
            afterTarget: afterTarget
          };
          target.parentNode.insertBefore(dragging, afterTarget ? target.nextSibling : target);
        }
      }
    });

    panel.addEventListener("dragend", function () {
      var dragging = panel.querySelector(".skytools-api-draggable.dragging");
      if (!dragging) {
        return;
      }
      dragging.classList.remove("dragging");
      dragging.draggable = true;
      var order = collectApiOrderFromDom(panel);
      if (state.pendingApiDrop && state.pendingApiDrop.targetId) {
        if (reorderApiOrder(state.draggingApiId, state.pendingApiDrop.targetId, state.pendingApiDrop.afterTarget === true)) {
          order = (state.apiOrder || []).slice();
        }
      }
      state.draggingApiId = "";
      state.pendingApiDrop = null;
      state.draggingPointerId = null;
      saveApiOrder(order);
    });

    renderPanelBody();
    setActivity("busy", "Carregando status", "Sincronizando com o backend...");
    (state.status ? Promise.resolve(state.status) : loadStatus(true)).then(function () {
      if (!state.installed && state.activeTab === "biblioteca") {
        return refreshInstalledCache(false);
      }
      if (!state.fixGames && state.activeTab === "correcoes") {
        return refreshFixGames(false);
      }
      return state.activeTab === "correcoes" ? state.fixGames : state.installed;
    }).then(function () {
      renderPanelBody();
      if (!state.busy) {
        setActivity("idle", "Pronto", "SkyTools carregado.");
      }
      ensureTabData(state.activeTab);
    });
  }

  function tick() {
    ensureAppliedTheme();
    removeLegacyWebkitButton();
    ensureFloatingMenu();
    ensureGameButton();
    var payload = currentPayload();
    var changed = payload.appid !== state.appid || payload.name !== state.appName;
    state.appid = payload.appid;
    state.appName = payload.name;
    if (changed && document.querySelector(".skytools-panel")) {
      renderPanelBody();
    }
  }

  function boot() {
    log("SkyTools browser script loaded: " + location.href);
    state.lastUrl = location.href;
    applyTheme(state.themeId);
    loadStatus(false);
    tick();
    window.setInterval(function () {
      if (location.href !== state.lastUrl) {
        state.lastUrl = location.href;
        removeGameButton();
        ensureAppliedTheme();
        window.setTimeout(function () {
          ensureAppliedTheme();
          tick();
        }, 350);
      } else {
        tick();
      }
    }, 1800);

    var observer = new MutationObserver(function () {
      window.clearTimeout(observer._skytoolsTimer);
      observer._skytoolsTimer = window.setTimeout(function () {
        ensureAppliedTheme();
        tick();
      }, 350);
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();

