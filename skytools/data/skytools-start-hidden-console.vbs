Set shell = CreateObject("WScript.Shell")
worker = ""
root = ""
If WScript.Arguments.Count > 0 Then worker = WScript.Arguments.Item(0)
If WScript.Arguments.Count > 1 Then root = WScript.Arguments.Item(1)
If worker <> "" And root <> "" Then
  command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & worker & Chr(34) & " -Root " & Chr(34) & root & Chr(34)
  shell.Run command, 0, False
End If