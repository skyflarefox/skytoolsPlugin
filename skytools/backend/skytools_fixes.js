// SkyTools Ryuu fix-source lookup helper for Windows Script Host.
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

  function cleanHtml(value) {
    return String(value || "")
      .replace(/<[^>]+>/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/\s+/g, " ")
      .replace(/^\s+|\s+$/g, "");
  }

  function normalize(value) {
    return cleanHtml(value)
      .toLowerCase()
      .replace(/\.(zip|rar|7z)$/i, "")
      .replace(/\b(bypass|online|fix|repair|steam|generic|tested|unstable|voices38|crackonly|crack|freetp|v\d+)\b/gi, " ")
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
    http.setRequestHeader("Accept", "text/html,application/xhtml+xml,*/*");
    http.send();
    if (http.status < 200 || http.status >= 300) throw new Error("HTTP " + http.status);
    return String(http.responseText || "");
  }

  function fileNameFromUrl(url) {
    var path = String(url || "").split("?")[0].replace(/\\/g, "/");
    var name = path.substring(path.lastIndexOf("/") + 1);
    try {
      return decodeURIComponent(name);
    } catch (_) {
      return name;
    }
  }

  function supportedArchive(url) {
    return /\.(zip|rar|7z)(?:\?|$)/i.test(String(url || ""));
  }

  function inferType(name, badges) {
    var text = String(name || "").toLowerCase();
    for (var i = 0; i < badges.length; i += 1) {
      var badge = String(badges[i] || "").toLowerCase();
      if (badge === "online") return "Online";
      if (badge === "bypass") return "Bypass";
    }
    if (/\bonline\b|freetp/i.test(text)) return "Online";
    if (/\bbypass\b/i.test(text)) return "Bypass";
    return "Fix";
  }

  function extractBadges(segment) {
    var badges = [];
    var seen = {};
    var regex = /<span\s+[^>]*data-badge-key=["']([^"']+)["'][^>]*>([\s\S]*?)<\/span>/ig;
    var match;
    while ((match = regex.exec(segment)) !== null) {
      var value = cleanHtml(match[1] || match[2]);
      var key = value.toLowerCase();
      if (value && !seen[key]) {
        seen[key] = true;
        badges.push(value);
      }
    }
    return badges;
  }

  function extractUrl(openTag, segment) {
    var match = /data-dl-href=["']([^"']+)["']/i.exec(openTag);
    if (!match) {
      match = /<a\s+[^>]*href=["']([^"']+)["']/i.exec(segment);
    }
    return match ? absoluteUrl(match[1]) : "";
  }

  function sourceJson(item) {
    return "{"
      + "\"name\":\"" + jsonEscape(item.name) + "\","
      + "\"type\":\"" + jsonEscape(item.type) + "\","
      + "\"provider\":\"Ryuu\","
      + "\"downloadUrl\":\"" + jsonEscape(item.downloadUrl) + "\","
      + "\"size\":\"" + jsonEscape(item.size) + "\","
      + "\"action\":\"apply\""
      + "}";
  }

  function parseRyuu(html, appid, gameName) {
    var gameKey = normalize(gameName);
    var cards = [];
    var cardRegex = /<div\s+class=["']game-card["']\s+id=["']game-(\d+)["']([^>]*)>/ig;
    var match;
    while ((match = cardRegex.exec(html)) !== null) {
      cards.push({
        index: match.index,
        openTag: match[0],
        appid: String(match[1]),
        attrs: match[2] || ""
      });
    }

    var sources = [];
    var seen = {};
    for (var c = 0; c < cards.length; c += 1) {
      var card = cards[c];
      var cardEnd = c + 1 < cards.length ? cards[c + 1].index : html.length;
      var cardHtml = html.substring(card.index, cardEnd);
      var nameMatch = /data-name=["']([^"']+)["']/i.exec(card.attrs);
      var siteName = cleanHtml(nameMatch ? nameMatch[1] : "");
      var matchesCard = card.appid === String(appid) || (gameKey && normalize(siteName).indexOf(gameKey) >= 0);

      var itemRegex = /<div\s+class=["'](?:fix-item(?:\s[^"']*)?|[^"']*\sfix-item(?:\s[^"']*)?)["'][^>]*>/ig;
      var items = [];
      var itemMatch;
      while ((itemMatch = itemRegex.exec(cardHtml)) !== null) {
        items.push({ index: itemMatch.index, openTag: itemMatch[0] });
      }

      for (var i = 0; i < items.length; i += 1) {
        var item = items[i];
        var itemEnd = i + 1 < items.length ? items[i + 1].index : cardHtml.length;
        var segment = cardHtml.substring(item.index, itemEnd);
        var url = extractUrl(item.openTag, segment);
        if (!supportedArchive(url)) continue;
        var nameNode = /<div\s+class=["']fix-name["']>([\s\S]*?)<\/div>/i.exec(segment);
        var title = cleanHtml(nameNode ? nameNode[1] : "") || fileNameFromUrl(url);
        var key = normalize(title);
        if (!matchesCard && gameKey && key.indexOf(gameKey) < 0) continue;
        if (seen[url]) continue;
        seen[url] = true;

        var sizeNode = /<div\s+class=["']fix-size["']>([\s\S]*?)<\/div>/i.exec(segment);
        var badges = extractBadges(segment);
        sources.push({
          name: title || ("Ryuu Fix " + (sources.length + 1)),
          type: inferType(title, badges),
          downloadUrl: url,
          size: cleanHtml(sizeNode ? sizeNode[1] : "")
        });
      }
    }

    return sources;
  }

  try {
    var resultPath = arg(0);
    var appid = arg(1);
    var gameName = arg(2);
    var html = downloadText("https://generator.ryuu.lol/fixes");
    var sources = parseRyuu(html, appid, gameName);
    var parts = [];
    for (var i = 0; i < sources.length; i += 1) parts.push(sourceJson(sources[i]));
    writeText(resultPath, "{\"success\":true,\"data\":{\"sources\":[" + parts.join(",") + "]},\"error\":\"\"}");
  } catch (error) {
    writeText(arg(0), "{\"success\":false,\"error\":\"" + jsonEscape(error && error.message ? error.message : String(error)) + "\"}");
  }
})();
