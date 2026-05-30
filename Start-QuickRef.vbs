' Start-QuickRef.vbs
' Demarre le resident quickref en silence (sans fenetre console), en -Sta (requis WinForms).
Set sh = CreateObject("WScript.Shell")
root = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
script = root & "src\Show-QuickRef.ps1"
sh.Run "powershell.exe -NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & script & """", 0, False
