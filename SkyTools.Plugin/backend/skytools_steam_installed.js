// SkyTools Steam appmanifest scanner for Windows Script Host.
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

  function readText(path) {
    var stream = new ActiveXObject("ADODB.Stream");
    stream.Type = 2;
    stream.Charset = "utf-8";
    stream.Open();
    stream.LoadFromFile(path);
    var text = stream.ReadText();
    stream.Close();
    return text;
  }

  function jsonEscape(value) {
    return String(value == null ? "" : value)
      .replace(/\\/g, "\\\\")
      .replace(/"/g, "\\\"")
      .replace(/\r/g, "\\r")
      .replace(/\n/g, "\\n")
      .replace(/\t/g, "\\t");
  }

  function acfValue(text, key) {
    var regex = new RegExp("\"" + key + "\"\\s+\"([^\"]*)\"", "i");
    var match = regex.exec(String(text || ""));
    return match ? String(match[1]).replace(/\\\\/g, "\\") : "";
  }

  function gameJson(item) {
    return "{"
      + "\"appId\":" + Number(item.appId) + ","
      + "\"gameName\":\"" + jsonEscape(item.gameName) + "\","
      + "\"name\":\"" + jsonEscape(item.gameName) + "\","
      + "\"fileName\":\"" + jsonEscape(item.fileName) + "\","
      + "\"fullPath\":\"" + jsonEscape(item.fullPath) + "\","
      + "\"manifestPath\":\"" + jsonEscape(item.manifestPath) + "\","
      + "\"gamePath\":\"" + jsonEscape(item.gamePath) + "\","
      + "\"installPath\":\"" + jsonEscape(item.gamePath) + "\","
      + "\"isDisabled\":false,"
      + "\"isSteamInstalled\":true,"
      + "\"imageUrl\":\"" + jsonEscape(item.imageUrl) + "\""
      + "}";
  }

  function scanSteamApps(steamapps, map) {
    if (!steamapps || !fso.FolderExists(steamapps)) return;
    var common = fso.BuildPath(steamapps, "common");
    var folder = fso.GetFolder(steamapps);
    var files = new Enumerator(folder.Files);
    for (; !files.atEnd(); files.moveNext()) {
      var file = files.item();
      var fileName = String(file.Name);
      var match = /^appmanifest_(\d+)\.acf$/i.exec(fileName);
      if (!match) continue;

      var appid = String(match[1]);
      if (map[appid]) continue;

      try {
        var text = readText(String(file.Path));
        var manifestAppid = acfValue(text, "appid") || appid;
        var installdir = acfValue(text, "installdir");
        if (!manifestAppid || !installdir) continue;

        var gamePath = fso.BuildPath(common, installdir);
        if (!fso.FolderExists(gamePath)) continue;

        var name = acfValue(text, "name") || ("AppID " + manifestAppid);
        map[String(manifestAppid)] = {
          appId: Number(manifestAppid),
          gameName: name,
          fileName: fileName,
          fullPath: String(file.Path),
          manifestPath: String(file.Path),
          gamePath: gamePath,
          imageUrl: "https://cdn.akamai.steamstatic.com/steam/apps/" + manifestAppid + "/header.jpg"
        };
      } catch (_) {
      }
    }
  }

  try {
    var resultPath = arg(0);
    if (!resultPath) throw new Error("Caminho de resultado ausente.");

    var map = {};
    for (var i = 1; i < WScript.Arguments.length; i += 1) {
      scanSteamApps(arg(i), map);
    }

    var ids = [];
    for (var id in map) {
      if (Object.prototype.hasOwnProperty.call(map, id)) ids.push(Number(id));
    }
    ids.sort(function (a, b) {
      var left = String(map[String(a)].gameName || "").toLowerCase();
      var right = String(map[String(b)].gameName || "").toLowerCase();
      return left < right ? -1 : left > right ? 1 : a - b;
    });

    var items = [];
    for (var j = 0; j < ids.length; j += 1) {
      items.push(gameJson(map[String(ids[j])]));
    }
    writeText(resultPath, "{\"success\":true,\"data\":[" + items.join(",") + "],\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
