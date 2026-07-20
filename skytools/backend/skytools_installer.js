// SkyTools one-shot installer for Windows Script Host.
// Runs with Windows Script Host and uses only files under the plugin folder plus Steam folders.
(function () {
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  var shell = new ActiveXObject("WScript.Shell");

  function arg(index) {
    return WScript.Arguments.length > index ? String(WScript.Arguments.Item(index)) : "";
  }

  var dataRoot = arg(0);
  var steamPath = arg(1);
  var scriptDir = arg(2);
  var appId = arg(3);
  var gameName = arg(4);
  var preferred = arg(5) || "Automatic";
  var morrenusKey = arg(6);
  var resultPath = arg(7);
  if (morrenusKey === "-") morrenusKey = "";

  function combine(a, b) {
    if (!a) return b;
    return /[\\\/]$/.test(a) ? a + b : a + "\\" + b;
  }

  function ensureDir(path) {
    if (!path || fso.FolderExists(path)) return;
    var parent = fso.GetParentFolderName(path);
    if (parent && !fso.FolderExists(parent)) ensureDir(parent);
    if (!fso.FolderExists(path)) fso.CreateFolder(path);
  }

  function readText(path) {
    if (!fso.FileExists(path)) return "";
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 2;
    stream.Charset = "utf-8";
    stream.Open();
    stream.LoadFromFile(path);
    var text = stream.ReadText();
    stream.Close();
    return text;
  }

  function writeText(path, text) {
    ensureDir(fso.GetParentFolderName(path));
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 2;
    stream.Charset = "utf-8";
    stream.Open();
    stream.WriteText(String(text || ""));
    stream.SaveToFile(path, 2);
    stream.Close();
  }

  function writePlainText(path, text) {
    ensureDir(fso.GetParentFolderName(path));
    var file = fso.CreateTextFile(path, true, false);
    file.Write(String(text || ""));
    file.Close();
  }

  function writeBinary(path, bytes) {
    ensureDir(fso.GetParentFolderName(path));
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 1;
    stream.Open();
    stream.Write(bytes);
    stream.SaveToFile(path, 2);
    stream.Close();
  }

  function psQuote(value) {
    return "'" + String(value || "").replace(/'/g, "''") + "'";
  }

  function cleanText(value) {
    return String(value == null ? "" : value).replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
  }

  function isPlaceholderGameName(value, id) {
    var name = cleanText(value);
    var app = String(id || "");
    if (!name) return true;
    if (app && name === app) return true;
    if (app && name.toLowerCase() === ("appid " + app).toLowerCase()) return true;
    return /^appid\s+\d+$/i.test(name);
  }

  function removeTree(path) {
    try {
      if (fso.FolderExists(path)) fso.DeleteFolder(path, true);
      if (fso.FileExists(path)) fso.DeleteFile(path, true);
    } catch (_) {}
  }

  function jsonEscape(value) {
    return String(value == null ? "" : value)
      .replace(/\\/g, "\\\\")
      .replace(/"/g, "\\\"")
      .replace(/\r/g, "\\r")
      .replace(/\n/g, "\\n")
      .replace(/\t/g, "\\t");
  }

  function toJson(value) {
    var type = typeof value;
    if (value === null || value === undefined) return "null";
    if (type === "number" || type === "boolean") return String(value);
    if (type === "string") return "\"" + jsonEscape(value) + "\"";
    if (Object.prototype.toString.call(value) === "[object Array]") {
      var items = [];
      for (var i = 0; i < value.length; i += 1) items.push(toJson(value[i]));
      return "[" + items.join(",") + "]";
    }
    var props = [];
    for (var key in value) {
      if (Object.prototype.hasOwnProperty.call(value, key)) {
        props.push("\"" + jsonEscape(key) + "\":" + toJson(value[key]));
      }
    }
    return "{" + props.join(",") + "}";
  }

  function readJson(path, fallback) {
    try {
      var text = readText(path);
      if (!text) return fallback;
      return (new Function("return (" + text + ");"))();
    } catch (_) {
      return fallback;
    }
  }

  function writeResult(payload) {
    writeText(resultPath, toJson(payload));
  }

  function isRawGitHubUrl(url) {
    return /^https?:\/\/raw\.githubusercontent\.com\//i.test(String(url || ""));
  }

  function normalizeDownloadUrl(url) {
    return String(url || "").replace(/(raw\.githubusercontent\.com\/[^\/]+\/[^\/]+)\/refs\/heads\/main\//i, "$1/main/");
  }

  function retryUrl(url, attempt) {
    if (attempt <= 1 || !isRawGitHubUrl(url)) return url;
    return url + (url.indexOf("?") >= 0 ? "&" : "?") + "skytools_retry=" + attempt + "_" + new Date().getTime();
  }

  function shouldRetryDownload(status, url) {
    if (status === 0 || status === 408 || status === 425 || status === 429) return true;
    if (status >= 500 && status <= 599) return true;
    if (status === 404 && isRawGitHubUrl(url)) return true;
    return false;
  }

  function downloadOnce(url, headers, target) {
    var http = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
    try {
      http.setTimeouts(10000, 10000, 30000, 30000);
    } catch (_) {}
    http.open("GET", url, false);
    http.setRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
    http.setRequestHeader("Accept", "application/zip,application/octet-stream,*/*");
    if (headers) {
      for (var key in headers) {
        if (Object.prototype.hasOwnProperty.call(headers, key) && headers[key]) {
          http.setRequestHeader(key, headers[key]);
        }
      }
    }
    try {
      http.send();
    } catch (networkError) {
      var net = new Error("Falha de rede em " + url + ": " + (networkError && networkError.message ? networkError.message : String(networkError)));
      net.status = 0;
      throw net;
    }
    if (http.status < 200 || http.status >= 300) {
      var err = new Error("HTTP " + http.status + " em " + url);
      err.status = Number(http.status) || 0;
      throw err;
    }
    writeBinary(target, http.responseBody);
  }

  function download(url, headers, target) {
    var baseUrl = normalizeDownloadUrl(url);
    var attempts = isRawGitHubUrl(baseUrl) ? 4 : 3;
    var lastError = null;
    for (var attempt = 1; attempt <= attempts; attempt += 1) {
      var currentUrl = retryUrl(baseUrl, attempt);
      try {
        removeTree(target);
        downloadOnce(currentUrl, headers, target);
        return { attempts: attempt, url: currentUrl };
      } catch (error) {
        lastError = error;
        removeTree(target);
        if (attempt >= attempts || !shouldRetryDownload(Number(error.status) || 0, baseUrl)) {
          break;
        }
        WScript.Sleep(700 * attempt);
      }
    }
    var status = lastError && lastError.status ? ("HTTP " + lastError.status) : "falha";
    throw new Error(status + " em " + baseUrl + " ap\u00f3s " + attempts + " tentativa(s)");
  }

  function collectFiles(root, pattern, output) {
    if (!fso.FolderExists(root)) return output;
    var folder = fso.GetFolder(root);
    var files = new Enumerator(folder.Files);
    for (; !files.atEnd(); files.moveNext()) {
      var file = files.item();
      if (pattern.test(file.Name)) output.push(file.Path);
    }
    var folders = new Enumerator(folder.SubFolders);
    for (; !folders.atEnd(); folders.moveNext()) {
      collectFiles(folders.item().Path, pattern, output);
    }
    return output;
  }

  function copyFolderFromZip(zipPath, targetDir) {
    ensureDir(targetDir);
    var psCommand = [
      "$ErrorActionPreference='Stop'",
      "Expand-Archive -LiteralPath " + psQuote(zipPath) + " -DestinationPath " + psQuote(targetDir) + " -Force"
    ].join("; ");
    var exitCode = shell.Run(
      "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command " + '"' + psCommand.replace(/"/g, '\\"') + '"',
      7,
      true
    );
    if (exitCode === 0) {
      var psLuaFiles = collectFiles(targetDir, /\.lua$/i, []);
      var psManifestFiles = collectFiles(targetDir, /\.manifest$/i, []);
      if (psLuaFiles.length > 0 || psManifestFiles.length > 0) return;
    }

    var app = new ActiveXObject("Shell.Application");
    var source = app.NameSpace(zipPath);
    var target = app.NameSpace(targetDir);
    if (!source || !target) throw new Error("N\u00e3o foi poss\u00edvel abrir o pacote zip.");
    target.CopyHere(source.Items(), 4 | 16 | 512 | 1024);
    for (var i = 0; i < 120; i += 1) {
      WScript.Sleep(500);
      var luaFiles = collectFiles(targetDir, /\.lua$/i, []);
      var manifestFiles = collectFiles(targetDir, /\.manifest$/i, []);
      if (luaFiles.length > 0 || manifestFiles.length > 0) return;
    }
    throw new Error("A extra\u00e7\u00e3o do pacote demorou demais ou n\u00e3o gerou arquivos v\u00e1lidos.");
  }

  function chooseScript(luaFiles) {
    var exact = String(appId) + ".lua";
    var numeric = null;
    for (var i = 0; i < luaFiles.length; i += 1) {
      var name = fso.GetFileName(luaFiles[i]);
      if (name.toLowerCase() === exact.toLowerCase()) return luaFiles[i];
      if (!numeric && /^\d+\.lua$/i.test(name)) numeric = luaFiles[i];
    }
    return numeric || luaFiles[0] || "";
  }

  function disableSetManifestIdCalls(text) {
    return String(text || "").replace(/(^|\r?\n)([^\r\n]*setManifestid\s*\([^\r\n]*)/ig, "$1-- $2");
  }

  function countDlcs(text) {
    var count = 0;
    var regex = /addappid\s*\(\s*(\d+)/ig;
    var match;
    while ((match = regex.exec(String(text || ""))) !== null) {
      if (String(match[1]) !== String(appId)) count += 1;
    }
    return count;
  }

  function replaceAll(text, token, value) {
    return String(text || "").split(token).join(value || "");
  }

  function pad2(value) {
    value = String(value);
    return value.length < 2 ? "0" + value : value;
  }

  function isoNow() {
    var date = new Date();
    return date.getFullYear() + "-"
      + pad2(date.getMonth() + 1) + "-"
      + pad2(date.getDate()) + "T"
      + pad2(date.getHours()) + ":"
      + pad2(date.getMinutes()) + ":"
      + pad2(date.getSeconds());
  }

  function sourceUrl(api) {
    var url = replaceAll(api.urlTemplate, "<appid>", appId);
    url = replaceAll(url, "<moapikey>", morrenusKey);
    url = replaceAll(url, "<apikey>", api.apiKey || "");
    if (api.useProxy && api.proxyUrlTemplate && String(api.proxyUrlTemplate).indexOf("<url>") >= 0) {
      url = replaceAll(api.proxyUrlTemplate, "<url>", encodeURIComponent(url));
    }
    return normalizeDownloadUrl(url);
  }

  function isDisabled(settings, id) {
    var disabled = settings && settings.DisabledApiIds ? settings.DisabledApiIds : [];
    if (Object.prototype.toString.call(disabled) !== "[object Array]") return false;
    for (var i = 0; i < disabled.length; i += 1) {
      if (String(disabled[i]).toLowerCase() === String(id).toLowerCase()) return true;
    }
    return false;
  }

  function nativeOverride(settings, id) {
    var overrides = settings && settings.NativeManifestApis ? settings.NativeManifestApis : {};
    var item = overrides && (overrides[id] || overrides[String(id).toLowerCase()]);
    return item || {};
  }

  function nativeSource(settings, id, name, urlTemplate, apiKey) {
    var override = nativeOverride(settings, id);
    if (isDisabled(settings, id) || override.enabled === false) return null;
    var source = {
      id: id,
      name: override.name || name,
      apiKey: override.apiKey || apiKey || "",
      urlTemplate: override.urlTemplate || urlTemplate,
      useProxy: override.useProxy === true,
      proxyUrlTemplate: override.proxyUrlTemplate || ""
    };
    if (!source.urlTemplate || String(source.urlTemplate).indexOf("<appid>") < 0) return null;
    if (id === "morrenus" && !source.apiKey) return null;
    return source;
  }

  function builtInSources(settings) {
    var sources = [];
    var skyapi = nativeSource(settings, "skyapi", "SkyAPI", "https://raw.githubusercontent.com/skyflarefox/Skyapi/main/<appid>.zip", "");
    var morrenus = nativeSource(settings, "morrenus", "Morrenus", "https://hubcapmanifest.com/api/v1/manifest/<appid>?api_key=<moapikey>", morrenusKey);
    var sushi = nativeSource(settings, "sushi", "Sushi", "https://raw.githubusercontent.com/sushi-dev55-alt/sushitools-games-repo-alt/main/<appid>.zip", "");
    if (skyapi) sources.push(skyapi);
    if (morrenus) sources.push(morrenus);
    if (sushi) sources.push(sushi);
    return sources;
  }

  function orderSources(sources, settings) {
    var apiOrder = settings && settings.ApiOrder ? settings.ApiOrder : ["skyapi", "morrenus", "sushi"];
    if (Object.prototype.toString.call(apiOrder) !== "[object Array]") apiOrder = ["skyapi", "morrenus", "sushi"];
    var ranked = {};
    for (var r = 0; r < apiOrder.length; r += 1) {
      ranked[String(apiOrder[r]).toLowerCase()] = r;
    }
    sources.sort(function (left, right) {
      var leftRank = ranked[String(left.id).toLowerCase()];
      var rightRank = ranked[String(right.id).toLowerCase()];
      if (leftRank == null) leftRank = 9999;
      if (rightRank == null) rightRank = 9999;
      if (leftRank !== rightRank) return leftRank - rightRank;
      return 0;
    });
    return sources;
  }

  function loadSources() {
    var settings = readJson(combine(dataRoot, "settings.json"), {});
    var custom = settings && settings.CustomManifestApis ? settings.CustomManifestApis : [];
    var sources = builtInSources(settings);
    if (Object.prototype.toString.call(custom) === "[object Array]") {
      for (var i = 0; i < custom.length; i += 1) {
        var item = custom[i] || {};
        if (item.enabled === false || !item.urlTemplate || String(item.urlTemplate).indexOf("<appid>") < 0) continue;
        sources.push({
          id: item.id || ("custom-" + i),
          name: item.name || ("API " + (i + 1)),
          urlTemplate: item.urlTemplate,
          apiKey: item.apiKey || "",
          useProxy: item.useProxy === true,
          proxyUrlTemplate: item.proxyUrlTemplate || "",
          headers: item.headers || null
        });
      }
    }
    sources = orderSources(sources, settings);
    if (preferred && preferred !== "Automatic") {
      var ordered = [];
      for (var p = 0; p < sources.length; p += 1) {
        if (String(sources[p].id).toLowerCase() === String(preferred).toLowerCase()) ordered.push(sources[p]);
      }
      for (var q = 0; q < sources.length; q += 1) {
        if (String(sources[q].id).toLowerCase() !== String(preferred).toLowerCase()) ordered.push(sources[q]);
      }
      return ordered;
    }
    return sources;
  }

  function installFromZip(zipPath, sourceName) {
    var tempDir = combine(combine(dataRoot, "temp"), "manifest-" + appId + "-" + new Date().getTime());
    var installedFiles = [];
    var scriptDestination = "";
    var previousScriptBackup = "";
    try {
      copyFolderFromZip(zipPath, tempDir);
      var manifestFiles = collectFiles(tempDir, /\.manifest$/i, []);
      var luaFiles = collectFiles(tempDir, /\.lua$/i, []);
      if (manifestFiles.length === 0 && luaFiles.length === 0) throw new Error("O pacote n\u00e3o cont\u00e9m .manifest nem .lua.");
      var scriptSource = chooseScript(luaFiles);
      if (!scriptSource) throw new Error("Nenhum script .lua foi encontrado no pacote.");

      var depotCache = combine(steamPath, "depotcache");
      ensureDir(depotCache);
      ensureDir(scriptDir);

      var backupDir = combine(combine(combine(dataRoot, "manifest-backups"), appId), String(new Date().getTime()));
      for (var i = 0; i < manifestFiles.length; i += 1) {
        var dest = combine(depotCache, fso.GetFileName(manifestFiles[i]));
        var previous = "";
        if (fso.FileExists(dest)) {
          previous = combine(combine(backupDir, "manifests"), fso.GetFileName(dest));
          ensureDir(fso.GetParentFolderName(previous));
          fso.CopyFile(dest, previous, true);
        }
        fso.CopyFile(manifestFiles[i], dest, true);
        installedFiles.push({ InstalledPath: dest, PreviousBackup: previous });
      }

      scriptDestination = combine(scriptDir, appId + ".lua");
      if (fso.FileExists(scriptDestination)) {
        previousScriptBackup = combine(backupDir, fso.GetFileName(scriptDestination));
        ensureDir(fso.GetParentFolderName(previousScriptBackup));
        fso.CopyFile(scriptDestination, previousScriptBackup, true);
      }
      var scriptText = disableSetManifestIdCalls(readText(scriptSource));
      var dlcCount = countDlcs(scriptText);
      writePlainText(scriptDestination, scriptText);

      var recordsPath = combine(dataRoot, "manifest-installs.json");
      var records = readJson(recordsPath, []);
      if (Object.prototype.toString.call(records) !== "[object Array]") records = [];
      var kept = [];
      for (var r = 0; r < records.length; r += 1) {
        if (String((records[r] || {}).AppId || (records[r] || {}).appId || "") !== String(appId)) kept.push(records[r]);
      }
      var cleanGameName = isPlaceholderGameName(gameName, appId) ? "" : cleanText(gameName);
      kept.push({
        AppId: Number(appId),
        GameName: cleanGameName,
        SourceName: sourceName,
        InstalledAt: isoNow(),
        SourcePackage: sourceName,
        ScriptPath: scriptDestination,
        PreviousScriptBackup: previousScriptBackup,
        ManifestFiles: installedFiles
      });
      writeText(recordsPath, toJson(kept));

      var cachePath = combine(dataRoot, "skytools-app-name-cache.json");
      var cache = readJson(cachePath, {});
      if (!cache || typeof cache !== "object") cache = {};
      if (cleanGameName) {
        cache[String(appId)] = { AppId: Number(appId), Name: cleanGameName };
        writeText(cachePath, toJson(cache));
      }

      return {
        appId: Number(appId),
        gameName: cleanGameName || gameName,
        scriptPath: scriptDestination,
        manifestCount: manifestFiles.length,
        dlcCount: dlcCount,
        sourceName: sourceName
      };
    } finally {
      removeTree(tempDir);
    }
  }

  try {
    if (!dataRoot || !steamPath || !scriptDir || !appId || !resultPath) {
      throw new Error("Par\u00e2metros insuficientes para instalar o jogo.");
    }
    ensureDir(dataRoot);
    if (!fso.FolderExists(steamPath)) throw new Error("Steam n\u00e3o encontrada: " + steamPath);

    var tempZip = combine(combine(dataRoot, "temp"), appId + "-" + new Date().getTime() + ".zip");
    var sources = loadSources();
    var errors = [];
    var result = null;
    for (var s = 0; s < sources.length; s += 1) {
      try {
        download(sourceUrl(sources[s]), sources[s].headers, tempZip);
        result = installFromZip(tempZip, sources[s].name);
        break;
      } catch (sourceError) {
        errors.push(sources[s].name + ": " + sourceError.message);
        removeTree(tempZip);
      }
    }
    if (!result) {
      throw new Error("Nenhuma API retornou um pacote v\u00e1lido. " + errors.join(" | "));
    }
    removeTree(tempZip);
    writeResult({ success: true, data: result, error: "" });
  } catch (error) {
    writeResult({ success: false, error: error && error.message ? error.message : String(error) });
  }
})();
