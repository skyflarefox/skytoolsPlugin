(function () {
  "use strict";

  var SKYTOOLS_UI_VERSION = "2026-07-14-stable-cache-1";

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
  var state = {
    lastUrl: "",
    appid: "",
    appName: "",
    busy: false,
    activeTab: "inicio",
    status: null,
    installed: null,
    installedMap: {},
    installedLoadedAt: 0,
    installedLoading: false,
    nameCache: {},
    apis: null,
    apiForm: null,
    apiOrder: null,
    draggingApiId: "",
    installedPromise: null,
    backup: null,
    fixResults: null,
    fixQuery: "",
    selectedFixGame: null,
    lastResult: null,
    activityTitle: "Pronto",
    activityDetail: "Aguardando uma acao.",
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

  function call(method, payload) {
    if (typeof Millennium === "undefined" || typeof Millennium.callServerMethod !== "function") {
      return Promise.reject(new Error("Millennium bridge indisponivel"));
    }
    return Millennium.callServerMethod(PLUGIN_ID, method, payload || {}).then(parseResponse);
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
    return String((api && (api.id || api.Id)) || "");
  }

  function defaultApiOrder() {
    return ["skyapi", "morrenus", "sushi"];
  }

  function orderApis(apis, order) {
    var list = (apis || []).slice();
    var preferredOrder = Array.isArray(order) && order.length ? order : defaultApiOrder();
    var rank = {};
    preferredOrder.forEach(function (id, index) {
      rank[String(id).toLowerCase()] = index;
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
      return "A acao falhou.";
    }
    return result.error || result.message || "A acao falhou.";
  }

  function setActivity(kind, title, detail) {
    state.activityKind = kind || "idle";
    state.activityTitle = title || "SkyTools";
    state.activityDetail = detail || "";
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
    toast.querySelector("strong").textContent = title;
    toast.querySelector("span").textContent = message || "";
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

  function clearBusy() {
    state.busy = false;
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
    var added = isCurrentAppAdded();
    button.classList.toggle("skytools-game-button-remove", added);
    button.innerHTML = icon(added ? "trash" : "add") + "<span>" + (added ? "Remover via SkyTools" : "Adicionar via SkyTools") + "</span>";
    button.title = added ? "Remover este jogo da biblioteca SkyTools" : "Adicionar este jogo via SkyTools";
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

  function actionCard(action, iconName, title, detail, primary) {
    return [
      '<button type="button" class="skytools-action-card ' + (primary ? "skytools-primary-action" : "") + '" data-action="' + action + '">',
      '  <span class="skytools-action-icon">' + icon(iconName) + '</span>',
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
    if (!list || !list.length) {
      return '<div class="skytools-empty">Nenhum jogo carregado ainda.</div>';
    }

    return list.map(function (game) {
      var appid = gameAppId(game);
      var name = displayGameName(game);
      var dlcCount = Number(game.dlcCount || game.DlcCount || game.dlc_count || 0);
      var pill = dlcCount === 1 ? "1 DLC" : dlcCount > 1 ? (dlcCount + " DLCs") : "0 DLCs";
      return [
        '<div class="skytools-list-row">',
        '  <div class="skytools-row-icon">' + icon("library") + '</div>',
        '  <div class="skytools-row-main" title="' + escapeHtml(name) + '"><strong>' + escapeHtml(name) + '</strong><span>AppID ' + escapeHtml(appid) + '</span></div>',
        '  <span class="skytools-pill">' + escapeHtml(pill) + '</span>',
        '  <button type="button" class="skytools-row-action" title="Remover da Steam" data-action="remove-game" data-appid="' + escapeHtml(appid) + '" data-name="' + escapeHtml(name) + '">' + icon("trash") + '</button>',
        '</div>'
      ].join("");
    }).join("");
  }

  function renderApisList() {
    var data = normalizeData(state.apis);
    if (!data) {
      return '<div class="skytools-empty">Carregando APIs...</div>';
    }

    var builtIn = data.builtIn || [];
    var custom = data.custom || [];
    var allApis = orderApis(builtIn.concat(custom), data.apiOrder || data.ApiOrder || state.apiOrder || defaultApiOrder());
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
      var detail = (enabled ? "Ativa" : "Desativada") + " · " + (nativeApi ? "API padrao" : "API personalizada") + " · HTTP " + success + "/" + unavailable + (useProxy ? " · proxy" : "");
      return [
        '<div class="skytools-custom-api-row skytools-api-draggable ' + (state.apiForm && state.apiForm.id === id ? "selected" : "") + '" data-api-id="' + escapeHtml(id) + '">',
        '  <div class="skytools-row-icon">' + icon("api") + '</div>',
        '  <div class="skytools-row-main"><strong>' + escapeHtml(name) + '</strong><span>' + escapeHtml(url || "URL nao configurada") + '</span><small>' + escapeHtml(detail) + '</small></div>',
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
        '    <div class="skytools-field"><label>HTTP indisponivel</label><input class="skytools-input" type="number" min="100" max="599" data-field="apiUnavailableCode" value="' + escapeHtml(form.unavailableCode || 404) + '"></div>',
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
    return source.downloadUrl || source.sourceUrl || source.url || "";
  }

  function renderFixResults() {
    var sources = sourceArray(state.fixResults);
    if (!sources.length) {
      return '<div class="skytools-empty">Nenhuma correcao carregada.</div>';
    }
    return sources.map(function (source, index) {
      var title = source.name || source.title || source.provider || "Fonte";
      var detail = [source.provider, source.type, source.size].filter(Boolean).join(" · ");
      var url = sourceUrl(source);
      var provider = String(source.provider || "").toLowerCase();
      var action = source.action || (provider.indexOf("online") >= 0 ? "copy" : provider.indexOf("ryuu") >= 0 ? "apply" : "open");
      var actionButton = action === "copy"
        ? '  <button type="button" class="skytools-row-action" title="Copiar link" data-action="fix-copy" data-url="' + escapeHtml(url) + '">' + icon("online") + '</button>'
        : action === "apply"
          ? '  <button type="button" class="skytools-row-action" title="Aplicar na pasta do jogo" data-action="fix-prepare" data-source-index="' + index + '">' + icon("check") + '</button>'
          : '  <button type="button" class="skytools-row-action" title="Abrir fonte" data-action="fix-open" data-url="' + escapeHtml(url) + '">' + icon("online") + '</button>';
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
    var list = gameArray(state.installed);
    var query = String(state.fixQuery || "").toLowerCase();
    if (!list.length) {
      return '<div class="skytools-empty">Carregando jogos instalados...</div>';
    }

    var rows = [];
    for (var i = 0; i < list.length; i += 1) {
      var game = list[i];
      var appid = gameAppId(game);
      var name = displayGameName(game);
      if (query && (String(name).toLowerCase().indexOf(query) < 0 && String(appid).indexOf(query) < 0)) {
        continue;
      }
      rows.push([
        '<div class="skytools-list-row">',
        '  <div class="skytools-row-icon">' + icon("library") + '</div>',
        '  <div class="skytools-row-main"><strong>' + escapeHtml(name) + '</strong><span>AppID ' + escapeHtml(appid) + '</span></div>',
        '  <button type="button" class="skytools-row-action" title="Buscar correcoes" data-action="fix-game" data-appid="' + escapeHtml(appid) + '" data-name="' + escapeHtml(name) + '" data-game-path="' + escapeHtml(game.gamePath || game.installPath || "") + '">' + icon("fixes") + '</button>',
        '</div>'
      ].join(""));
      if (rows.length >= 12) {
        break;
      }
    }
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
      '  <input class="skytools-input" type="file" accept="application/json,.json" data-action="backup-file">',
      '</div>',
      backup ? '<pre class="skytools-result">' + escapeHtml(JSON.stringify({ createdAt: backup.createdAt, games: games.slice(0, 20), total: games.length }, null, 2)) + '</pre>' : '<div class="skytools-empty">Nenhum backup carregado.</div>'
    ].join("");
  }

  function renderDiagnostics() {
    var result = state.lastResult || state.status;
    if (!result) {
      return '<div class="skytools-empty">Sem diagnostico ainda.</div>';
    }
    return '<pre class="skytools-result">' + escapeHtml(JSON.stringify(result, null, 2)) + '</pre>';
  }

  function tabMarkup(tab) {
    var app = currentPayload();
    if (tab === "biblioteca") {
      return [
        '<div class="skytools-section-head"><strong>Jogos instalados</strong><button data-action="installed" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-list">' + renderInstalledList() + '</div>'
      ].join("");
    }

    if (tab === "correcoes") {
      return [
        '<div class="skytools-section-head"><strong>Correcoes para jogo</strong><button data-action="refresh-fix-games" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-field"><label>Buscar jogo instalado</label><input class="skytools-input" data-field="fixSearch" placeholder="Digite nome ou AppID" value="' + escapeHtml(state.fixQuery || "") + '"></div>',
        '<div class="skytools-list">' + renderFixGamePicker() + '</div>',
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

    if (tab === "diagnostico") {
      return [
        '<div class="skytools-section-head"><strong>Diagnostico</strong><button data-action="status" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-grid skytools-tight-grid">',
        actionCard("integration-skytools", "plug", "Ativar SkyTools", "Instalar integracao Steam", false),
        actionCard("integration-steamtools", "plug", "Ativar SteamTools", "Alternativa compativel", false),
        '</div>',
        renderDiagnostics()
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
      '  <div><span>App atual</span><strong>' + escapeHtml(app.appid ? app.name : "Nenhum jogo aberto") + '</strong><small>' + escapeHtml(app.appid ? "AppID " + app.appid : "Abra uma pagina de jogo para adicionar.") + '</small></div>',
      '</div>',
      '<div class="skytools-metrics">' + statusMetrics() + '</div>',
      '<div class="skytools-grid">',
      actionCard("add", "add", "Adicionar jogo", app.appid ? "Instalar manifests na Steam" : "Disponivel em paginas de jogo", true),
      actionCard("correcoes-tab", "fixes", "Correcoes", "Buscar por jogo instalado", false),
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
      '    <button type="button" data-tab="inicio">Inicio</button>',
      '    <button type="button" data-tab="biblioteca">Biblioteca</button>',
      '    <button type="button" data-tab="correcoes">Correcoes</button>',
      '    <button type="button" data-tab="apis">APIs</button>',
      '    <button type="button" data-tab="backup">Backup</button>',
      '    <button type="button" data-tab="diagnostico">Diagnostico</button>',
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
    updateTabs();
    updateActivity();
    updateBusyState();
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
    var detail = "Acao concluida.";
    if (Array.isArray(data)) {
      detail = data.length + " item(ns) encontrados.";
    } else if (data && data.installedCount != null) {
      detail = data.installedCount + " jogos adicionados. Integracao: " + (data.integration || "-") + ".";
      if (data.appNameCacheCount != null) {
        detail += " Cache: " + data.appNameCacheCount + " nomes.";
      }
    } else if (data && data.manifestCount != null) {
      detail = "Manifests: " + data.manifestCount + ". DLCs: " + (data.dlcCount || 0) + ".";
    } else if (data && data.message) {
      detail = data.message;
    } else if (data && data.path) {
      detail = data.path;
    }

    setActivity("success", title || "Concluido", detail);
    showToast("SkyTools", detail, "success");
    renderPanelBody();
  }

  function runAction(title, method, payload, after) {
    if (state.busy) {
      showToast("SkyTools", "Aguarde a acao atual terminar.", "info");
      return Promise.resolve();
    }

    setBusy(title, method === "SkyToolsRepair" ? "Executando correcao externa..." : "Executando em segundo plano.");
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
      showToast("SkyTools", "Abra a pagina de um jogo na loja Steam.", "error");
      return;
    }
    return runAction("Adicionando jogo", "SkyToolsAddGame", payload, function () {
      return refreshInstalledCache(true).then(function () {
        state.installedMap[String(payload.appid)] = true;
        rememberGameName(payload.appid, payload.name);
        updateGameButton();
      });
    });
  }

  function removeCurrentGame() {
    var payload = currentPayload();
    if (!payload.appid) {
      showToast("SkyTools", "Abra a pagina de um jogo na loja Steam.", "error");
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
    for (var i = 0; i < all.length; i += 1) {
      if (String(all[i].id || all[i].Id || "") === String(id || "")) {
        return all[i];
      }
    }
    return null;
  }

  function saveApiOrder() {
    if (!state.apiOrder || !state.apiOrder.length) {
      return;
    }
    setActivity("busy", "Salvando ordem", "Atualizando prioridade das APIs...");
    call("SkyToolsSaveApiSettings", { apiOrder: state.apiOrder }).then(function (result) {
      state.apis = result;
      setActivity("success", "Ordem salva", "A prioridade das APIs foi atualizada.");
      renderPanelBody();
    }, function (error) {
      renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Falha ao salvar ordem");
    });
  }

  function openExternal(url) {
    url = String(url || "").trim();
    if (!url) {
      showToast("SkyTools", "Link indisponivel.", "error");
      return;
    }
    window.open(url, "_blank");
  }

  function copyText(text) {
    text = String(text || "");
    if (!text) {
      showToast("SkyTools", "Link indisponivel.", "error");
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
    return runAction(title, action === "online" ? "SkyToolsOnlineFix" : action === "denuvo" ? "SkyToolsDenuvoFix" : "SkyToolsFixSources", payload, function (result) {
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
        renderResult({ success: false, error: error && error.message ? error.message : String(error) }, "Backup invalido");
      }
    };
    reader.onerror = function () {
      renderResult({ success: false, error: "Nao foi possivel ler o arquivo." }, "Backup invalido");
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
    if ((tab === "biblioteca" || tab === "correcoes") && !state.installed && !state.installedLoading) {
      setBusy("Carregando biblioteca", "Buscando jogos adicionados.");
      refreshInstalledCache(true).then(function (result) {
        clearBusy();
        state.installed = result;
        updateNameCacheFromInstalled(result);
        if (tab === "biblioteca") {
          renderResult(result, "Biblioteca carregada");
        } else {
          renderPanelBody();
        }
      });
      return;
    }

    if (tab === "apis" && !state.apis) {
      runAction("Carregando APIs", "SkyToolsApis", {}, function (result) {
        state.apis = result;
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

      var action = button.getAttribute("data-action");
      var payload = currentPayload();
      if (action === "add") addCurrentGame();
      if (action === "correcoes-tab") {
        state.activeTab = "correcoes";
        renderPanelBody();
        ensureTabData("correcoes");
      }
      if (action === "refresh-fix-games") {
        runAction("Carregando jogos", "SkyToolsInstalled", {}, function (result) {
          state.installed = result;
          updateNameCacheFromInstalled(result);
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
      if (action === "api-delete") runAction("Excluindo API", "SkyToolsDeleteApi", { id: button.getAttribute("data-api-id") }, function () { state.apis = null; return call("SkyToolsApis", {}).then(function (result) { state.apis = result; }); });
      if (action === "api-new") {
        var apiData = normalizeData(state.apis) || {};
        var customCount = (apiData.custom || []).length;
        state.apiForm = { id: "", native: false, name: "API personalizada " + (customCount + 1), urlTemplate: "", apiKey: "", enabled: true, useProxy: false, proxyUrlTemplate: "", successCode: 200, unavailableCode: 404 };
        renderPanelBody();
      }
      if (action === "api-cancel") { state.apiForm = null; renderPanelBody(); }
      if (action === "api-save") runAction("Salvando API", "SkyToolsSaveApi", currentApiForm(panel), function () { state.apiForm = null; state.apis = null; return call("SkyToolsApis", {}).then(function (result) { state.apis = result; }); });
      if (action === "api-save-settings") runAction("Salvando preferencias", "SkyToolsSaveApiSettings", { apiOrder: state.apiOrder || [] }, function (result) { state.apis = result; });
      if (action === "fixes") loadFixSources("fixes", "Buscando correcoes", payload);
      if (action === "online") loadFixSources("online", "Buscando correcao online", payload);
      if (action === "denuvo") loadFixSources("denuvo", "Buscando correcao Denuvo", payload);
      if (action === "fix-open") openExternal(button.getAttribute("data-url"));
      if (action === "fix-copy") copyText(button.getAttribute("data-url"));
      if (action === "fix-game") {
        state.selectedFixGame = {
          appid: button.getAttribute("data-appid") || "",
          name: button.getAttribute("data-name") || "",
          gamePath: button.getAttribute("data-game-path") || ""
        };
        loadFixSources("fixes", "Buscando correcoes", state.selectedFixGame);
      }
      if (action === "fix-prepare") {
        var source = sourceArray(state.fixResults)[Number(button.getAttribute("data-source-index") || 0)];
        var selected = state.selectedFixGame || payload;
        runAction("Aplicando Ryuu", "SkyToolsApplyFix", { appid: selected.appid, name: selected.name, gamePath: selected.gamePath || "", source: source || {} }, function (result) {
          var data = normalizeData(result) || {};
          if (data.action === "copy" && data.url) {
            copyText(data.url);
          } else if (data.url && data.message && data.message.indexOf("iniciada") < 0) {
            openExternal(data.url);
          }
        });
      }
      if (action === "backup") { state.activeTab = "backup"; renderPanelBody(); }
      if (action === "backup-export") runAction("Exportando backup", "SkyToolsBackupExport", {});
      if (action === "backup-restore") restoreBackup();
      if (action === "integration-skytools") runAction("Ativando SkyTools", "SkyToolsIntegration", { target: "SkyTools" }, function (result) { state.status = result; });
      if (action === "integration-steamtools") runAction("Ativando SteamTools", "SkyToolsIntegration", { target: "SteamTools" }, function (result) { state.status = result; });
      if (action === "status") runAction("Coletando diagnostico", "SkyToolsStatus", {}, function (result) { state.status = result; });
    });

    panel.addEventListener("change", function (event) {
      var actionNode = findActionButton(event.target);
      if (actionNode && actionNode.getAttribute("data-action") === "backup-file") {
        parseBackupFile(actionNode.files && actionNode.files[0]);
      }
    });

    panel.addEventListener("input", function (event) {
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "fixSearch") {
        state.fixQuery = event.target.value || "";
        renderPanelBody();
      }
    });

    panel.addEventListener("pointerdown", function (event) {
      if (event.target && event.target.closest && event.target.closest("button,input,select,textarea")) {
        return;
      }
      var row = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      if (!row) {
        return;
      }
      state.draggingApiId = row.getAttribute("data-api-id") || "";
      row.classList.add("dragging");
      try {
        row.setPointerCapture(event.pointerId);
      } catch (_) {}
    });

    panel.addEventListener("pointerover", function (event) {
      if (!state.draggingApiId) {
        return;
      }
      var row = event.target && event.target.closest ? event.target.closest(".skytools-api-draggable") : null;
      if (!row) {
        return;
      }
      var targetId = row.getAttribute("data-api-id") || "";
      var rect = row.getBoundingClientRect();
      var afterTarget = event.clientY > rect.top + (rect.height / 2);
      if (targetId && targetId !== state.draggingApiId && reorderApiOrder(state.draggingApiId, targetId, afterTarget)) {
        var dragged = panel.querySelector('.skytools-api-draggable[data-api-id="' + state.draggingApiId + '"]');
        if (dragged && row.parentNode) {
          row.parentNode.insertBefore(dragged, afterTarget ? row.nextSibling : row);
        }
      }
    });

    panel.addEventListener("pointerup", function () {
      if (!state.draggingApiId) {
        return;
      }
      var rows = panel.querySelectorAll(".skytools-api-draggable.dragging");
      for (var i = 0; i < rows.length; i += 1) {
        rows[i].classList.remove("dragging");
      }
      state.draggingApiId = "";
      saveApiOrder();
    });

    panel.addEventListener("pointercancel", function () {
      state.draggingApiId = "";
      renderPanelBody();
    });

    renderPanelBody();
    setActivity("busy", "Carregando status", "Sincronizando com o backend...");
    (state.status ? Promise.resolve(state.status) : loadStatus(true)).then(function () {
      if (!state.installed && (state.activeTab === "biblioteca" || state.activeTab === "correcoes")) {
        return refreshInstalledCache(false);
      }
      return state.installed;
    }).then(function () {
      renderPanelBody();
      if (!state.busy) {
        setActivity("idle", "Pronto", "SkyTools carregado.");
      }
      ensureTabData(state.activeTab);
    });
  }

  function tick() {
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
    tick();
    window.setInterval(function () {
      if (location.href !== state.lastUrl) {
        state.lastUrl = location.href;
        removeGameButton();
        window.setTimeout(tick, 350);
      } else {
        tick();
      }
    }, 1800);

    var observer = new MutationObserver(function () {
      window.clearTimeout(observer._skytoolsTimer);
      observer._skytoolsTimer = window.setTimeout(tick, 350);
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
