# Show-QuickRef.ps1
# Fenetre sans bords qui affiche un aide-memoire (texte de config.json).
# Toggle : relancer le script alors que la fenetre est ouverte la ferme.
# Se ferme aussi sur Echap, clic, ou perte de focus.
# Contrainte : la fenetre ne recouvre jamais le curseur de la souris.
$ErrorActionPreference = 'Stop'

# DPI aware AVANT toute fenetre (sinon dimensionnement faux sur ecran HiDPI).
Add-Type -Namespace Native -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
try { [void][Native.Dpi]::SetProcessDPIAware() } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$TITLE_TAG = 'quickref-hud'

# --- TOGGLE via fichier PID (deterministe, inter-process) ---
# Au lancement : si une instance tourne deja, on la ferme et on sort (toggle OFF).
# Sinon on enregistre notre PID et on affiche la fenetre (toggle ON).
$pidFile = Join-Path $env:TEMP 'quickref.pid'
if (Test-Path $pidFile) {
    $oldPid = $null
    try { $oldPid = [int]((Get-Content $pidFile -Raw).Trim()) } catch {}
    $alive = $false
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        # Verifier que c'est bien un de nos process (powershell), pas un PID recycle.
        if ($proc -and $proc.ProcessName -match 'powershell|pwsh') { $alive = $true }
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    if ($alive) {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
        return   # toggle OFF : la fenetre etait ouverte, on l'a fermee
    }
}
Set-Content -Path $pidFile -Value $PID -Encoding ascii -NoNewline

# --- Lecture de la config ---
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$configPath = Join-Path $root 'config.json'

function Get-DefaultConfig {
    @{
        Title = 'Raccourcis'; FontName = 'Consolas'; FontSize = 13; Bold = $false
        Padding = 26; LineSpacing = 8; CloseOnFocusLost = $true
        Bg = @(24,24,28); Fg = @(235,235,235); Accent = @(96,230,150); Border = @(96,230,150)
        Lines = @('config.json introuvable, valeurs par defaut.')
    }
}

function Import-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return Get-DefaultConfig }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $raw   = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
        $j     = $raw | ConvertFrom-Json
    } catch { return Get-DefaultConfig }
    $col = { param($v,$d) if ($v) { @([int]$v[0],[int]$v[1],[int]$v[2]) } else { $d } }
    @{
        Title       = if ($j.title) { [string]$j.title } else { 'Raccourcis' }
        FontName    = if ($j.font -and $j.font.name) { [string]$j.font.name } else { 'Consolas' }
        FontSize    = if ($j.font -and $j.font.size) { [double]$j.font.size } else { 13 }
        Bold        = if ($j.font -and $null -ne $j.font.bold) { [bool]$j.font.bold } else { $false }
        Padding     = if ($null -ne $j.padding) { [int]$j.padding } else { 26 }
        LineSpacing = if ($null -ne $j.lineSpacing) { [int]$j.lineSpacing } else { 8 }
        CloseOnFocusLost = if ($null -ne $j.closeOnFocusLost) { [bool]$j.closeOnFocusLost } else { $true }
        Bg     = & $col $j.colors.background @(24,24,28)
        Fg     = & $col $j.colors.foreground @(235,235,235)
        Accent = & $col $j.colors.accent @(96,230,150)
        Border = & $col $j.colors.border @(96,230,150)
        Lines  = if ($j.lines) { @($j.lines) } else { @('(aucune ligne dans config.json)') }
    }
}

$cfg = Import-Config -Path $configPath

# --- Polices et couleurs ---
$bodyStyle  = if ($cfg.Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
$bodyFont   = New-Object System.Drawing.Font($cfg.FontName, [single]$cfg.FontSize, $bodyStyle)
$titleFont  = New-Object System.Drawing.Font($cfg.FontName, [single]($cfg.FontSize + 3), [System.Drawing.FontStyle]::Bold)
$colBg     = [System.Drawing.Color]::FromArgb($cfg.Bg[0],     $cfg.Bg[1],     $cfg.Bg[2])
$colFg     = [System.Drawing.Color]::FromArgb($cfg.Fg[0],     $cfg.Fg[1],     $cfg.Fg[2])
$colAccent = [System.Drawing.Color]::FromArgb($cfg.Accent[0], $cfg.Accent[1], $cfg.Accent[2])
$colBorder = [System.Drawing.Color]::FromArgb($cfg.Border[0], $cfg.Border[1], $cfg.Border[2])

# --- Mesure du contenu pour dimensionner la fenetre ---
$measure   = [System.Drawing.Graphics]::FromImage((New-Object System.Drawing.Bitmap 1,1))
$titleSize = $measure.MeasureString($cfg.Title, $titleFont)
$maxLineW  = 0
foreach ($l in $cfg.Lines) {
    $w = $measure.MeasureString($l, $bodyFont).Width
    if ($w -gt $maxLineW) { $maxLineW = $w }
}
$measure.Dispose()

$pad     = $cfg.Padding
$lineH   = [int]$bodyFont.GetHeight()
$titleH  = [int]$titleFont.GetHeight()
$bigGap  = [int]($lineH * 0.8)
$contentW = [int]([Math]::Ceiling([Math]::Max($titleSize.Width, $maxLineW)))
$winW = $contentW + $pad * 2
$winH = $pad * 2 + $titleH + $bigGap + ($cfg.Lines.Count * ($lineH + $cfg.LineSpacing)) - $cfg.LineSpacing

# --- Fenetre sans bords ---
$form = New-Object System.Windows.Forms.Form
$form.Text            = $TITLE_TAG
$form.FormBorderStyle = 'None'
$form.StartPosition   = 'Manual'
$form.ShowInTaskbar   = $false
$form.TopMost         = $true
$form.KeyPreview      = $true
$form.BackColor       = $colBg
$form.ClientSize      = New-Object System.Drawing.Size($winW, $winH)

$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = 'Fill'
$panel.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($panel, $true)
$form.Controls.Add($panel)

$brushFg     = New-Object System.Drawing.SolidBrush ($colFg)
$brushAccent = New-Object System.Drawing.SolidBrush ($colAccent)
$penBorder   = New-Object System.Drawing.Pen ($colBorder, 1)

$panel.Add_Paint({
    param($s, $e)
    $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $e.Graphics.Clear($colBg)
    $x = $pad
    $y = $pad
    $e.Graphics.DrawString($cfg.Title, $titleFont, $brushAccent, [single]$x, [single]$y)
    $y += $titleH + $bigGap
    foreach ($l in $cfg.Lines) {
        $e.Graphics.DrawString($l, $bodyFont, $brushFg, [single]$x, [single]$y)
        $y += $lineH + $cfg.LineSpacing
    }
    # liseret pour distinguer la fenetre du fond
    $e.Graphics.DrawRectangle($penBorder, 0, 0, $panel.Width - 1, $panel.Height - 1)
}.GetNewClosure())

# --- Positionnement : sur l'ecran de la souris, sans recouvrir le curseur ---
$form.Add_Load({
    $cursor = [System.Windows.Forms.Cursor]::Position
    $wa = [System.Windows.Forms.Screen]::FromPoint($cursor).WorkingArea
    $m = 16   # marge depuis les bords
    # Candidats : centre d'abord, puis les 4 coins. On garde le 1er qui ne contient pas le curseur.
    $cx = $wa.X + [int](($wa.Width  - $winW) / 2)
    $cy = $wa.Y + [int](($wa.Height - $winH) / 2)
    $candidates = @(
        @{ X = $cx;                    Y = $cy },
        @{ X = $wa.X + $m;             Y = $wa.Y + $m },
        @{ X = $wa.Right - $winW - $m; Y = $wa.Y + $m },
        @{ X = $wa.X + $m;             Y = $wa.Bottom - $winH - $m },
        @{ X = $wa.Right - $winW - $m; Y = $wa.Bottom - $winH - $m }
    )
    $chosen = $candidates[0]
    foreach ($c in $candidates) {
        $contient = ($cursor.X -ge $c.X) -and ($cursor.X -le ($c.X + $winW)) -and
                    ($cursor.Y -ge $c.Y) -and ($cursor.Y -le ($c.Y + $winH))
        if (-not $contient) { $chosen = $c; break }
    }
    $form.Left = $chosen.X
    $form.Top  = $chosen.Y
    $form.Activate()
}.GetNewClosure())

# --- Fermeture : Echap, clic, perte de focus ---
$closeIt = { $form.Close() }.GetNewClosure()
$form.Add_KeyDown({ param($s,$e) if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() } }.GetNewClosure())
$panel.Add_Click($closeIt)
$form.Add_Click($closeIt)
if ($cfg.CloseOnFocusLost -and $env:QUICKREF_NO_AUTOCLOSE -ne '1') {
    $form.Add_Deactivate($closeIt)
}

# --- Nettoyer le fichier PID a la fermeture (seulement si c'est le notre) ---
$form.Add_FormClosing({
    if (Test-Path $pidFile) {
        $cur = $null
        try { $cur = [int]((Get-Content $pidFile -Raw).Trim()) } catch {}
        if ($cur -eq $PID) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
    }
}.GetNewClosure())

[System.Windows.Forms.Application]::Run($form)
