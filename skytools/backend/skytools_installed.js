// SkyTools installed-script scanner for Windows Script Host.
// Original helper: scans Steam script folders and returns JSON to the Lua backend.
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

  function itemJson(item) {
    return "{"
      + "\"appId\":" + Number(item.appId) + ","
      + "\"fileName\":\"" + jsonEscape(item.fileName) + "\","
      + "\"fullPath\":\"" + jsonEscape(item.fullPath) + "\","
      + "\"scriptDirectory\":\"" + jsonEscape(item.scriptDirectory) + "\","
      + "\"dlcCount\":" + Number(item.dlcCount || 0) + ","
      + "\"isDisabled\":" + (item.isDisabled ? "true" : "false")
      + "}";
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

  function countDlcs(path, appid) {
    try {
      var text = readText(path);
      var regex = /addappid\s*\(\s*(\d+)/ig;
      var seen = {};
      var count = 0;
      var match;
      while ((match = regex.exec(text)) !== null) {
        var id = String(match[1]);
        if (id !== String(appid) && !seen[id]) {
          seen[id] = true;
          count += 1;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  function scanDir(directory, map) {
    if (!directory || !fso.FolderExists(directory)) return;
    var folder = fso.GetFolder(directory);
    var files = new Enumerator(folder.Files);
    for (; !files.atEnd(); files.moveNext()) {
      var file = files.item();
      var name = String(file.Name);
      var match = name.match(/^(\d+)\.lua(\.disabled)?$/i);
      if (!match) continue;
      var appid = String(match[1]);
      var item = {
        appId: Number(appid),
        fileName: name,
        fullPath: String(file.Path),
        scriptDirectory: directory,
        dlcCount: countDlcs(String(file.Path), appid),
        isDisabled: !!match[2]
      };
      if (!map[appid] || !item.isDisabled) {
        map[appid] = item;
      }
    }
  }

  try {
    var resultPath = arg(0);
    if (!resultPath) throw new Error("Caminho de resultado ausente.");
    var map = {};
    for (var i = 1; i < WScript.Arguments.length; i += 1) {
      scanDir(arg(i), map);
    }
    var ids = [];
    for (var id in map) {
      if (Object.prototype.hasOwnProperty.call(map, id)) ids.push(Number(id));
    }
    ids.sort(function (a, b) { return a - b; });
    var items = [];
    for (var j = 0; j < ids.length; j += 1) {
      items.push(itemJson(map[String(ids[j])]));
    }
    writeText(resultPath, "{\"success\":true,\"data\":[" + items.join(",") + "],\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
