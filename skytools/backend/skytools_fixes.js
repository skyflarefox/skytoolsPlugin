// SkyTools GitHub fix-source lookup helper for Windows Script Host.
(function () {
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  var releasesApiRoot = "https://api.github.com/repos/skyflarefox/fix/releases";
  var legacyDownloadRoot = "https://github.com/skyflarefox/fix/releases/download/fix/";

  function arg(index) {
    return WScript.Arguments.length > index ? String(WScript.Arguments.Item(index)) : "";
  }

  function ensureDir(path) {
    if (!path || fso.FolderExists(path)) return;
    var parent = fso.GetParentFolderName(path);
    if (parent && !fso.FolderExists(parent)) ensureDir(parent);
    if (!fso.FolderExists(path)) fso.CreateFolder(path);
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

  function jsonEscape(value) {
    return String(value == null ? "" : value)
      .replace(/\\/g, "\\\\")
      .replace(/"/g, "\\\"")
      .replace(/\r/g, "\\r")
      .replace(/\n/g, "\\n")
      .replace(/\t/g, "\\t");
  }

  function parseJson(text, fallback) {
    try {
      return (new Function("return (" + String(text || "null") + ");"))();
    } catch (_) {
      return fallback;
    }
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

  function cleanName(value, appid) {
    var text = String(value || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
    if (!text || /^appid\s+\d+$/i.test(text) || text === String(appid || "")) {
      return "AppID " + String(appid || "");
    }
    return text;
  }

  function typeLabel(kind) {
    return kind === "online" ? "Online" : "Gen\u00e9rica";
  }

  function formatSize(bytes) {
    var value = Number(bytes || 0);
    if (!isFinite(value) || value <= 0) return "";
    var mb = value / 1024 / 1024;
    return mb.toFixed(1).replace(".", ",") + " MB";
  }

  function sendRequest(method, url, accept) {
    var classes = ["WinHttp.WinHttpRequest.5.1", "MSXML2.ServerXMLHTTP.6.0", "MSXML2.XMLHTTP.6.0"];
    for (var i = 0; i < classes.length; i += 1) {
      try {
        var currentUrl = url;
        for (var redirect = 0; redirect < 6; redirect += 1) {
          var http = new ActiveXObject(classes[i]);
          if (http.SetTimeouts) http.SetTimeouts(10000, 10000, 15000, 15000);
          http.open(method, currentUrl, false);
          if (http.setRequestHeader) {
            http.setRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
            http.setRequestHeader("Accept", accept || "*/*");
            http.setRequestHeader("X-GitHub-Api-Version", "2022-11-28");
          } else {
            http.SetRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
            http.SetRequestHeader("Accept", accept || "*/*");
            http.SetRequestHeader("X-GitHub-Api-Version", "2022-11-28");
          }
          http.send();
          var status = Number(http.status || http.Status || 0);
          var getHeader = function (name) {
            try {
              return http.getResponseHeader ? http.getResponseHeader(name) : http.GetResponseHeader(name);
            } catch (_) {
              return "";
            }
          };
          if ((status === 301 || status === 302 || status === 303 || status === 307 || status === 308) && getHeader("Location")) {
            currentUrl = getHeader("Location");
            if (currentUrl.indexOf("//") === 0) currentUrl = "https:" + currentUrl;
            continue;
          }
          if (status <= 0) break;
          return {
            status: status,
            text: String(http.responseText || http.ResponseText || ""),
            header: getHeader
          };
        }
      } catch (_) {
      }
    }
    return null;
  }

  function getJson(url) {
    var response = sendRequest("GET", url, "application/vnd.github+json");
    if (!response || response.status < 200 || response.status >= 300) return null;
    return parseJson(response.text || "null", null);
  }

  function headArchive(url) {
    var response = sendRequest("HEAD", url, "application/zip,*/*");
    if (!response || response.status < 200 || response.status >= 300) return null;
    var length = response.header("Content-Length") || "";
    return { sizeBytes: Number(length) || 0 };
  }

  function sourceJson(item) {
    return "{"
      + "\"name\":\"" + jsonEscape(item.name) + "\","
      + "\"displayName\":\"" + jsonEscape(item.displayName) + "\","
      + "\"type\":\"" + jsonEscape(item.type) + "\","
      + "\"kind\":\"" + jsonEscape(item.kind) + "\","
      + "\"provider\":\"Sky\","
      + "\"downloadUrl\":\"" + jsonEscape(item.downloadUrl) + "\","
      + "\"fileName\":\"" + jsonEscape(item.fileName) + "\","
      + "\"size\":\"" + jsonEscape(item.size) + "\","
      + "\"sizeBytes\":" + String(item.sizeBytes || 0) + ","
      + "\"action\":\"apply\""
      + "}";
  }

  function makeSource(appid, gameName, kind, asset) {
    var label = typeLabel(kind);
    var size = formatSize(asset.size || asset.sizeBytes || 0);
    var name = cleanName(gameName, appid);
    return {
      name: name,
      displayName: name + " - " + label + (size ? " - " + size : "") + " (Sky)",
      type: label,
      kind: kind,
      downloadUrl: asset.browser_download_url || asset.downloadUrl || "",
      fileName: asset.name || String(appid) + "_" + kind + ".zip",
      size: size,
      sizeBytes: Number(asset.size || asset.sizeBytes || 0) || 0
    };
  }

  function wantedKinds(requestedKind) {
    if (requestedKind === "online" || requestedKind === "generic") return [requestedKind];
    return ["online", "generic"];
  }

  function wantedFileMap(appid, kinds) {
    var map = {};
    for (var i = 0; i < kinds.length; i += 1) {
      map[(String(appid) + "_" + kinds[i] + ".zip").toLowerCase()] = kinds[i];
    }
    return map;
  }

  function foundAll(found, kinds) {
    for (var i = 0; i < kinds.length; i += 1) {
      if (!found[kinds[i]]) return false;
    }
    return true;
  }

  function collectMatchingAssets(assets, wanted, found) {
    if (!assets || !assets.length) return;
    for (var i = 0; i < assets.length; i += 1) {
      var asset = assets[i] || {};
      var assetName = String(asset.name || "").toLowerCase();
      var kind = wanted[assetName];
      if (kind && !found[kind]) {
        found[kind] = asset;
      }
    }
  }

  function scanReleaseAssets(release, wanted, found) {
    if (!release) return;
    collectMatchingAssets(release.assets || [], wanted, found);
    if (!release.assets_url) return;
    for (var page = 1; page <= 20; page += 1) {
      var assets = getJson(release.assets_url + "?per_page=100&page=" + page);
      if (!assets || !assets.length) return;
      collectMatchingAssets(assets, wanted, found);
    }
  }

  function findBundledAssets(appid, kinds) {
    var wanted = wantedFileMap(appid, kinds);
    var found = {};
    var indexPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "skytools_fix_index.json");
    var index = parseJson(readText(indexPath), null);
    var releases = index && index.releases ? index.releases : [];
    for (var i = 0; i < releases.length; i += 1) {
      scanReleaseAssets(releases[i], wanted, found);
      if (foundAll(found, kinds)) return found;
    }
    return found;
  }

  function findReleaseAssets(appid, kinds) {
    var wanted = wantedFileMap(appid, kinds);
    var found = {};
    for (var releasePage = 1; releasePage <= 20; releasePage += 1) {
      var releases = getJson(releasesApiRoot + "?per_page=100&page=" + releasePage);
      if (!releases || !releases.length) break;
      for (var i = 0; i < releases.length; i += 1) {
        scanReleaseAssets(releases[i], wanted, found);
        if (foundAll(found, kinds)) return found;
      }
    }
    return found;
  }

  function legacyAsset(appid, kind) {
    var fileName = String(appid) + "_" + kind + ".zip";
    var url = legacyDownloadRoot + fileName;
    var archive = headArchive(url);
    if (!archive) return null;
    return {
      name: fileName,
      browser_download_url: url,
      size: archive.sizeBytes
    };
  }

  function findSkyFixes(appid, gameName, requestedKind) {
    var kinds = wantedKinds(requestedKind);
    var found = findBundledAssets(appid, kinds);
    var sources = [];
    for (var i = 0; i < kinds.length; i += 1) {
      var kind = kinds[i];
      if (!found[kind]) {
        var legacy = legacyAsset(appid, kind);
        if (legacy) found[kind] = legacy;
      }
    }
    if (!foundAll(found, kinds)) {
      var releaseAssets = findReleaseAssets(appid, kinds);
      for (var key in releaseAssets) {
        if (releaseAssets.hasOwnProperty(key) && !found[key]) {
          found[key] = releaseAssets[key];
        }
      }
    }
    for (var j = 0; j < kinds.length; j += 1) {
      var sourceKind = kinds[j];
      var asset = found[sourceKind];
      if (asset) sources.push(makeSource(appid, gameName, sourceKind, asset));
    }
    return sources;
  }

  try {
    var resultPath = arg(0);
    var appid = arg(1);
    var gameName = arg(2);
    var kind = String(arg(3) || "").toLowerCase();
    var sources = findSkyFixes(appid, gameName, kind);
    var parts = [];
    for (var i = 0; i < sources.length; i += 1) parts.push(sourceJson(sources[i]));
    writeText(resultPath, "{\"success\":true,\"data\":{\"sources\":[" + parts.join(",") + "]},\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
