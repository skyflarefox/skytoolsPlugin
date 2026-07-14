// SkyTools fix-source lookup helper. Original lightweight parser for Ryuu fix listings.
(function () {
  var fso = new ActiveXObject("Scripting.FileSystemObject");

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

  function decodeHtml(value) {
    return String(value || "")
      .replace(/<[^>]+>/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, " ")
      .replace(/^\s+|\s+$/g, "");
  }

  function normalize(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/\.(zip|rar|7z)$/i, "")
      .replace(/\b(bypass|online|fix|repair|steam|generic|tested|unstable|crack|freetp|v\d+)\b/gi, " ")
      .replace(/[^a-z0-9]+/g, " ")
      .replace(/\s+/g, " ")
      .replace(/^\s+|\s+$/g, "");
  }

  function absoluteUrl(url) {
    var value = /^https?:\/\//i.test(url)
      ? url
      : url.charAt(0) === "/"
        ? "https://generator.ryuu.lol" + url
        : "https://generator.ryuu.lol/" + url;
    return value.replace(/ /g, "%20");
  }

  function downloadText(url) {
    var http = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
    http.open("GET", url, false);
    http.setRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
    http.setRequestHeader("Accept", "text/html,*/*");
    http.send();
    if (http.status < 200 || http.status >= 300) throw new Error("HTTP " + http.status);
    return String(http.responseText || "");
  }

  function sourceJson(item) {
    return "{"
      + "\"name\":\"" + jsonEscape(item.name) + "\","
      + "\"type\":\"" + jsonEscape(item.type) + "\","
      + "\"provider\":\"Ryuu\","
      + "\"downloadUrl\":\"" + jsonEscape(item.downloadUrl) + "\","
      + "\"size\":\"\""
      + "}";
  }

  try {
    var resultPath = arg(0);
    var appid = arg(1);
    var gameName = arg(2);
    var gameKey = normalize(gameName);
    var html = downloadText("https://generator.ryuu.lol/fixes");
    var seen = {};
    var sources = [];
    var linkRegex = /<a\s+[^>]*href=["']([^"']+\.(?:zip|rar|7z)(?:\?[^"']*)?)["'][^>]*>([\s\S]*?)<\/a>/ig;
    var match;
    while ((match = linkRegex.exec(html)) !== null && sources.length < 12) {
      var url = absoluteUrl(match[1]);
      var title = decodeHtml(match[2]) || decodeURIComponent(url.split("/").pop());
      var key = normalize(title + " " + url);
      var matchesApp = appid && (title.indexOf(appid) >= 0 || url.indexOf(appid) >= 0);
      var matchesName = gameKey && key.indexOf(gameKey) >= 0;
      if (!matchesApp && !matchesName) continue;
      if (seen[url]) continue;
      seen[url] = true;
      sources.push({
        name: title || ("Fix " + (sources.length + 1)),
        type: /online|freetp/i.test(title + " " + url) ? "Online" : /bypass/i.test(title + " " + url) ? "Bypass" : "Fix",
        downloadUrl: url
      });
    }
    var parts = [];
    for (var i = 0; i < sources.length; i += 1) parts.push(sourceJson(sources[i]));
    writeText(resultPath, "{\"success\":true,\"data\":{\"sources\":[" + parts.join(",") + "]},\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
