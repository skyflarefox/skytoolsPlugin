// SkyTools GitHub fix-source lookup helper for Windows Script Host.
(function () {
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  var repoRawRoot = "https://github.com/skyflarefox/fix/releases/download/fix/";

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

  function headArchive(url) {
    var http = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
    http.open("HEAD", url, false);
    http.setRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
    http.setRequestHeader("Accept", "application/zip,*/*");
    http.send();
    if (http.status < 200 || http.status >= 300) return null;
    var length = http.getResponseHeader("Content-Length") || "";
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

  function findSkyFixes(appid, gameName, requestedKind) {
    var kinds = requestedKind === "online" || requestedKind === "generic"
      ? [requestedKind]
      : ["online", "generic"];
    var name = cleanName(gameName, appid);
    var sources = [];
    for (var i = 0; i < kinds.length; i += 1) {
      var kind = kinds[i];
      var fileName = String(appid) + "_" + kind + ".zip";
      var url = repoRawRoot + fileName;
      var archive = headArchive(url);
      if (!archive) continue;

      var label = typeLabel(kind);
      var size = formatSize(archive.sizeBytes);
      sources.push({
        name: name,
        displayName: name + " - " + label + (size ? " - " + size : "") + " (Sky)",
        type: label,
        kind: kind,
        downloadUrl: url,
        fileName: fileName,
        size: size,
        sizeBytes: archive.sizeBytes
      });
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
