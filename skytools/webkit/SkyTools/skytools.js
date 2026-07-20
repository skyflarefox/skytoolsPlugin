(function () {
  "use strict";

  var SKYTOOLS_UI_VERSION = "2026-07-14-restore-backup-ryuu-1";

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
      return Promise.reject(new Error("Millennium bridge indisponível"));
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
      var id = rows[i].getAttribute("data-api-id") || "";
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
      return "A ação falhou.";
    }
    return result.error || result.message || "A ação falhou.";
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
      var detail = (enabled ? "Ativa" : "Desativada") + " · " + (nativeApi ? "API padrão" : "API personalizada") + " · HTTP " + success + "/" + unavailable + (useProxy ? " · proxy" : "");
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

  function formatFixLabel(source) {
    source = source || {};
    if (source.displayName) return source.displayName;
    var name = source.name || source.title || source.fileName || source.provider || "Fonte";
    var type = source.type || "";
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
      var detail = source.fileName || [source.provider, source.type, source.size].filter(Boolean).join(" · ");
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

    if (tab === "diagnostico") {
      return [
        '<div class="skytools-section-head"><strong>Diagnóstico</strong><button data-action="status" type="button">' + icon("refresh") + '<span>Atualizar</span></button></div>',
        '<div class="skytools-grid skytools-tight-grid">',
        actionCard("integration-skytools", "plug", "Ativar SkyTools", "Instalar integração Steam", false),
        actionCard("integration-steamtools", "plug", "Ativar SteamTools", "Alternativa compatível", false),
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
      '  <div><span>App atual</span><strong>' + escapeHtml(app.appid ? app.name : "Nenhum jogo aberto") + '</strong><small>' + escapeHtml(app.appid ? "AppID " + app.appid : "Abra uma página de jogo para adicionar.") + '</small></div>',
      '</div>',
      '<div class="skytools-metrics">' + statusMetrics() + '</div>',
      '<div class="skytools-grid">',
      actionCard("add", "add", "Adicionar jogo", app.appid ? "Instalar manifests na Steam" : "Disponível em páginas de jogo", true),
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
      '    <button type="button" data-tab="diagnostico">Diagnóstico</button>',
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
    var detail = "Ação concluída.";
    if (Array.isArray(data)) {
      detail = data.length + " item(ns) encontrados.";
    } else if (data && data.installedCount != null) {
      detail = data.installedCount + " jogos adicionados. Integração: " + (data.integration || "-") + ".";
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
      if (action === "api-delete") runAction("Excluindo API", "SkyToolsDeleteApi", { id: button.getAttribute("data-api-id") }, function () { state.apis = null; return call("SkyToolsApis", {}).then(function (result) { state.apis = result; }); });
      if (action === "api-new") {
        var apiData = normalizeData(state.apis) || {};
        var customCount = (apiData.custom || []).length;
        state.apiForm = { id: "", native: false, name: "API personalizada " + (customCount + 1), urlTemplate: "", apiKey: "", enabled: true, useProxy: false, proxyUrlTemplate: "", successCode: 200, unavailableCode: 404 };
        renderPanelBody();
      }
      if (action === "api-cancel") { state.apiForm = null; renderPanelBody(); }
      if (action === "api-save") runAction("Salvando API", "SkyToolsSaveApi", currentApiForm(panel), function () { state.apiForm = null; state.apis = null; return call("SkyToolsApis", {}).then(function (result) { state.apis = result; }); });
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
        state.fixVisibleCount = 80;
        var fixList = panel.querySelector('[data-role="fix-game-list"]');
        if (fixList) {
          fixList.innerHTML = renderFixGamePicker();
        }
      }
      if (event.target && event.target.getAttribute && event.target.getAttribute("data-field") === "librarySearch") {
        state.libraryQuery = event.target.value || "";
        var installedList = panel.querySelector('[data-role="installed-list"]');
        if (installedList) {
          installedList.innerHTML = renderInstalledList();
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
