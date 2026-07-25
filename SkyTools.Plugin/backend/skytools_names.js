// SkyTools app-name resolver. Receives result path followed by AppIDs.
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

  function uniqueAppIds() {
    var seen = {};
    var ids = [];
    for (var i = 1; i < WScript.Arguments.length; i += 1) {
      var id = String(arg(i)).replace(/\D/g, "");
      if (id && !seen[id]) {
        seen[id] = true;
        ids.push(id);
      }
    }
    return ids;
  }

  function fetchNames(ids) {
    var names = {};
    if (!ids.length) return names;
    for (var i = 0; i < ids.length; i += 1) {
      var id = ids[i];
      var http = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
      var url = "https://store.steampowered.com/api/appdetails?filters=basic&appids=" + encodeURIComponent(id);
      http.open("GET", url, false);
      http.setRequestHeader("User-Agent", "SkyToolsPlugin/1.0");
      http.setRequestHeader("Accept", "application/json,*/*");
      try {
        http.send();
      } catch (_) {
        continue;
      }
      if (http.status < 200 || http.status >= 300) continue;
      var data = {};
      try {
        data = (new Function("return (" + String(http.responseText || "{}") + ");"))();
      } catch (_) {
        data = {};
      }
      var item = data && data[id] ? data[id] : null;
      var name = item && item.data && item.data.name ? String(item.data.name) : "";
      if (name) names[id] = name;
    }
    return names;
  }

  try {
    var resultPath = arg(0);
    var ids = uniqueAppIds();
    var names = fetchNames(ids);
    var parts = [];
    for (var id in names) {
      if (Object.prototype.hasOwnProperty.call(names, id)) {
        parts.push("\"" + jsonEscape(id) + "\":\"" + jsonEscape(names[id]) + "\"");
      }
    }
    writeText(resultPath, "{\"success\":true,\"data\":{" + parts.join(",") + "},\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
