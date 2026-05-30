# Show-QuickRef.ps1  (RESIDENT)
# Process leger qui reste en fond : WinForms charge une fois, fenetre pre-construite.
# Un hotkey global natif (RegisterHotKey) affiche/masque la fenetre instantanement.
# Affiche une GRILLE libre (lignes x colonnes) definie dans config.json.
# Chaque raccourci est auto-style : la touche (avant le separateur) en couleur d'accent,
# l'action en gris. Se masque sur Echap, clic, perte de focus. Single-instance (mutex).
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'quickref-resident.log'
function L($m) { try { "[$([DateTime]::Now.ToString('HH:mm:ss'))] $m" | Add-Content $log } catch {} }

# --- Single instance : si un resident tourne deja, on sort. ---
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'quickref-resident-singleton', [ref]$createdNew)
if (-not $createdNew) { return }

# --- DPI aware AVANT toute fenetre ---
Add-Type -Namespace Native -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
try { [void][Native.Dpi]::SetProcessDPIAware() } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Fenetre native qui capte le hotkey global (WM_HOTKEY) ---
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class QuickRefHotkey : NativeWindow {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public const int WM_HOTKEY = 0x0312;
    public event Action Pressed;
    public QuickRefHotkey() { this.CreateHandle(new CreateParams()); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && Pressed != null) { Pressed(); }
        base.WndProc(ref m);
    }
    public bool Register(uint mod, uint vk) { return RegisterHotKey(this.Handle, 1, mod, vk); }
    public void Unregister() { UnregisterHotKey(this.Handle, 1); }
}
'@

# --- Chemins ---
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$configPath = Join-Path $root 'config.json'

# --- Auto-update au demarrage (sauf si on vient d'etre relance par une mise a jour) ---
if ($env:QUICKREF_SKIP_UPDATE -ne '1') {
    try {
        . (Join-Path $here 'AutoUpdate.ps1')
        if (Invoke-QuickRefAutoUpdate -Root $root) {
            L 'auto-update applique -> relancement'
            try { $mutex.ReleaseMutex() } catch {}
            $env:QUICKREF_SKIP_UPDATE = '1'
            Start-Process wscript.exe -ArgumentList ('"' + (Join-Path $root 'Start-QuickRef.vbs') + '"')
            return
        }
    } catch {}
}

# --- Lecture de la config ---
function Get-DefaultConfig {
    @{
        Title='Raccourcis'; Hotkey='Ctrl+Alt+W'; FontName='Consolas'; FontSize=12
        Padding=24; LineSpacing=7; ColGap=46; RowGap=22; Separator='='; CloseOnFocusLost=$true
        Bg=@(24,24,28); Fg=@(210,210,214); Accent=@(96,230,150); Border=@(96,230,150)
        Footer=''
        Grid=@(
            @{ Row=0; Col=0; Title='QUICKREF'; Items=@('config.json introuvable','valeurs par defaut') }
        )
        Rows=1; Cols=1
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

    # Construire la liste des cellules : prioritaire = grid.cells ; sinon fallback "lines".
    $cells = @()
    $rows = 1; $cols = 1
    if ($j.grid -and $j.grid.cells) {
        foreach ($c in $j.grid.cells) {
            $items = @()
            if ($c.items) { $items = @($c.items | ForEach-Object { [string]$_ }) }
            $cells += @{
                Row   = if ($null -ne $c.row) { [int]$c.row } else { 0 }
                Col   = if ($null -ne $c.col) { [int]$c.col } else { 0 }
                Title = if ($c.title) { [string]$c.title } else { '' }
                Items = $items
            }
        }
        $rows = if ($null -ne $j.grid.rows) { [int]$j.grid.rows } else { ($cells | ForEach-Object { $_.Row } | Measure-Object -Maximum).Maximum + 1 }
        $cols = if ($null -ne $j.grid.cols) { [int]$j.grid.cols } else { ($cells | ForEach-Object { $_.Col } | Measure-Object -Maximum).Maximum + 1 }
    } elseif ($j.lines) {
        # Compat ancienne version : une seule colonne de lignes.
        $cells += @{ Row=0; Col=0; Title=(if ($j.title) { [string]$j.title } else { 'Raccourcis' }); Items=@($j.lines | ForEach-Object { [string]$_ }) }
        $rows = 1; $cols = 1
    } else {
        return Get-DefaultConfig
    }

    @{
        Title    = if ($j.title) { [string]$j.title } else { 'Raccourcis' }
        Hotkey   = if ($j.hotkey) { [string]$j.hotkey } else { 'Ctrl+Alt+W' }
        FontName = if ($j.font -and $j.font.name) { [string]$j.font.name } else { 'Consolas' }
        FontSize = if ($j.font -and $j.font.size) { [double]$j.font.size } else { 12 }
        Padding  = if ($null -ne $j.padding) { [int]$j.padding } else { 24 }
        LineSpacing = if ($null -ne $j.lineSpacing) { [int]$j.lineSpacing } else { 7 }
        ColGap   = if ($j.grid -and $null -ne $j.grid.colGap) { [int]$j.grid.colGap } else { 46 }
        RowGap   = if ($j.grid -and $null -ne $j.grid.rowGap) { [int]$j.grid.rowGap } else { 22 }
        Separator = if ($j.separator) { [string]$j.separator } else { '=' }
        CloseOnFocusLost = if ($null -ne $j.closeOnFocusLost) { [bool]$j.closeOnFocusLost } else { $true }
        Footer   = if ($j.footer) { [string]$j.footer } else { '' }
        Bg     = & $col $j.colors.background @(24,24,28)
        Fg     = & $col $j.colors.foreground @(210,210,214)
        Accent = & $col $j.colors.accent @(96,230,150)
        Border = & $col $j.colors.border @(96,230,150)
        Grid   = $cells
        Rows   = $rows
        Cols   = $cols
    }
}
$cfg = Import-Config -Path $configPath

# --- Parse du hotkey ("Ctrl+Alt+W" -> modificateurs + code touche) ---
function ConvertTo-Hotkey {
    param([string]$s)
    $mods = 0; $vk = 0
    foreach ($p in ($s -split '\+')) {
        $t = $p.Trim().ToLower()
        if     ($t -eq 'ctrl' -or $t -eq 'control') { $mods = $mods -bor 2 }
        elseif ($t -eq 'alt')                       { $mods = $mods -bor 1 }
        elseif ($t -eq 'shift')                     { $mods = $mods -bor 4 }
        elseif ($t -eq 'win')                       { $mods = $mods -bor 8 }
        else {
            $k = $p.Trim().ToUpper()
            if ($k -eq 'SPACE') { $vk = 0x20 }
            elseif ($k.Length -eq 1) { $vk = [int][char]$k }
            elseif ($k -match '^F([1-9]|1[0-2])$') { $vk = 0x70 + [int]$k.Substring(1) - 1 }
        }
    }
    $mods = $mods -bor 0x4000   # MOD_NOREPEAT
    @{ Mods = [uint32]$mods; Vk = [uint32]$vk }
}

# --- Polices et couleurs ---
$bodyFont  = New-Object System.Drawing.Font($cfg.FontName, [single]$cfg.FontSize, [System.Drawing.FontStyle]::Regular)
$keyFont   = New-Object System.Drawing.Font($cfg.FontName, [single]$cfg.FontSize, [System.Drawing.FontStyle]::Bold)
$titleFont = New-Object System.Drawing.Font($cfg.FontName, [single]($cfg.FontSize + 2), [System.Drawing.FontStyle]::Bold)
$footFont  = New-Object System.Drawing.Font($cfg.FontName, [single]([Math]::Max(8, $cfg.FontSize - 2)), [System.Drawing.FontStyle]::Italic)
$colBg     = [System.Drawing.Color]::FromArgb($cfg.Bg[0],$cfg.Bg[1],$cfg.Bg[2])
$colFg     = [System.Drawing.Color]::FromArgb($cfg.Fg[0],$cfg.Fg[1],$cfg.Fg[2])
$colAccent = [System.Drawing.Color]::FromArgb($cfg.Accent[0],$cfg.Accent[1],$cfg.Accent[2])
$colBorder = [System.Drawing.Color]::FromArgb($cfg.Border[0],$cfg.Border[1],$cfg.Border[2])
$brushFg     = New-Object System.Drawing.SolidBrush ($colFg)
$brushKey    = New-Object System.Drawing.SolidBrush ($colAccent)
$brushTitle  = New-Object System.Drawing.SolidBrush ($colAccent)
$brushFoot   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150,150,156))
$penBorder   = New-Object System.Drawing.Pen ($colBorder, 1)

# --- Helper : couper un item "touche = action" en (key, action) ---
function Split-Item {
    param([string]$text)
    $sep = $cfg.Separator
    $idx = $text.IndexOf($sep)
    if ($idx -lt 0) { return @{ Key=$text; Action='' } }
    @{ Key = $text.Substring(0, $idx).TrimEnd(); Action = $text.Substring($idx + $sep.Length).TrimStart() }
}

# --- Mesures de base ---
$measure = [System.Drawing.Graphics]::FromImage((New-Object System.Drawing.Bitmap 1,1))
function Measure-W { param($t,$f) [int][Math]::Ceiling($measure.MeasureString($t, $f).Width) }
$lineH  = [int]$bodyFont.GetHeight()
$titleH = [int]$titleFont.GetHeight()
$footH  = if ($cfg.Footer) { [int]$footFont.GetHeight() + 8 } else { 0 }
$bigGap = [int]($lineH * 0.7)
$keySpace = Measure-W '  ' $keyFont   # espace entre touche et action

# --- Calcul du layout de la grille (une fois) ---
$rows = [int]$cfg.Rows; $cols = [int]$cfg.Cols
$colW = New-Object 'int[]' $cols
$rowH = New-Object 'int[]' $rows
foreach ($cell in $cfg.Grid) {
    $r = [int]$cell.Row; $c = [int]$cell.Col
    if ($r -ge $rows -or $c -ge $cols -or $r -lt 0 -or $c -lt 0) { continue }
    # largeur cellule
    $w = Measure-W $cell.Title $titleFont
    foreach ($it in $cell.Items) {
        $parts = Split-Item $it
        $iw = (Measure-W $parts.Key $keyFont) + $keySpace + (Measure-W $parts.Action $bodyFont)
        if ($iw -gt $w) { $w = $iw }
    }
    if ($w -gt $colW[$c]) { $colW[$c] = $w }
    # hauteur cellule
    $h = $titleH + $bigGap + ($cell.Items.Count * ($lineH + $cfg.LineSpacing))
    if ($cell.Items.Count -gt 0) { $h -= $cfg.LineSpacing }
    if ($h -gt $rowH[$r]) { $rowH[$r] = $h }
}
$measure.Dispose()

$pad = $cfg.Padding
$sumColW = 0; for ($i=0; $i -lt $cols; $i++) { $sumColW += $colW[$i] }
$sumRowH = 0; for ($i=0; $i -lt $rows; $i++) { $sumRowH += $rowH[$i] }
$winW = $pad * 2 + $sumColW + ($cfg.ColGap * [Math]::Max(0, $cols - 1))
$winH = $pad * 2 + $sumRowH + ($cfg.RowGap * [Math]::Max(0, $rows - 1)) + $footH

# origines de colonnes/lignes (precalcul)
$colX = New-Object 'int[]' $cols
$rowY = New-Object 'int[]' $rows
$acc = $pad; for ($i=0; $i -lt $cols; $i++) { $colX[$i] = $acc; $acc += $colW[$i] + $cfg.ColGap }
$acc = $pad; for ($i=0; $i -lt $rows; $i++) { $rowY[$i] = $acc; $acc += $rowH[$i] + $cfg.RowGap }

# --- Fenetre HUD (pre-construite, masquee) ---
$hud = New-Object System.Windows.Forms.Form
$hud.Text            = 'quickref-hud'
$hud.FormBorderStyle = 'None'
$hud.StartPosition   = 'Manual'
$hud.ShowInTaskbar   = $false
$hud.TopMost         = $true
$hud.KeyPreview      = $true
$hud.BackColor       = $colBg
$hud.ClientSize      = New-Object System.Drawing.Size($winW, $winH)

$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = 'Fill'
$panel.GetType().GetProperty('DoubleBuffered',[Reflection.BindingFlags]'Instance,NonPublic').SetValue($panel,$true)
$hud.Controls.Add($panel)

$panel.Add_Paint({
    param($s,$e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear($colBg)
    foreach ($cell in $cfg.Grid) {
        $r = [int]$cell.Row; $c = [int]$cell.Col
        if ($r -ge $rows -or $c -ge $cols -or $r -lt 0 -or $c -lt 0) { continue }
        $x = $colX[$c]; $y = $rowY[$r]
        # titre de cellule
        if ($cell.Title) { $g.DrawString($cell.Title, $titleFont, $brushTitle, [single]$x, [single]$y) }
        $yy = $y + $titleH + $bigGap
        foreach ($it in $cell.Items) {
            $parts = Split-Item $it
            $g.DrawString($parts.Key, $keyFont, $brushKey, [single]$x, [single]$yy)
            if ($parts.Action) {
                $kw = (Measure-W $parts.Key $keyFont) + $keySpace
                $g.DrawString($parts.Action, $bodyFont, $brushFg, [single]($x + $kw), [single]$yy)
            }
            $yy += $lineH + $cfg.LineSpacing
        }
    }
    if ($cfg.Footer) {
        $g.DrawString($cfg.Footer, $footFont, $brushFoot, [single]$pad, [single]($panel.Height - $footH + 2))
    }
    $g.DrawRectangle($penBorder, 0, 0, $panel.Width - 1, $panel.Height - 1)
}.GetNewClosure())

# Etat partage (anti-fermeture parasite juste apres l'ouverture)
$state = @{ shownAt = 0 }

# --- Placement : ecran de la souris, sans recouvrir le curseur ---
function Move-AwayFromCursor {
    $cur = [System.Windows.Forms.Cursor]::Position
    $wa = [System.Windows.Forms.Screen]::FromPoint($cur).WorkingArea
    $m = 16
    $cx = $wa.X + [int](($wa.Width - $winW)/2)
    $cy = $wa.Y + [int](($wa.Height - $winH)/2)
    $cands = @(
        @{X=$cx;Y=$cy},
        @{X=$wa.X+$m;Y=$wa.Y+$m},
        @{X=$wa.Right-$winW-$m;Y=$wa.Y+$m},
        @{X=$wa.X+$m;Y=$wa.Bottom-$winH-$m},
        @{X=$wa.Right-$winW-$m;Y=$wa.Bottom-$winH-$m}
    )
    $chosen = $cands[0]
    foreach ($c in $cands) {
        $in = ($cur.X -ge $c.X) -and ($cur.X -le ($c.X+$winW)) -and ($cur.Y -ge $c.Y) -and ($cur.Y -le ($c.Y+$winH))
        if (-not $in) { $chosen = $c; break }
    }
    $hud.Left = $chosen.X; $hud.Top = $chosen.Y
}

# --- Toggle (appele par le hotkey) : Show/Hide, instantane ---
$toggle = {
    if ($hud.Visible) {
        $hud.Hide()
    } else {
        Move-AwayFromCursor
        $state.shownAt = [Environment]::TickCount
        $hud.Show()
        $hud.BringToFront()
        $hud.Activate()
    }
}.GetNewClosure()

# --- Masquage : Echap, clic, perte de focus ---
$hideIt = { $hud.Hide() }.GetNewClosure()
$hud.Add_KeyDown({ param($s,$e) if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $hud.Hide() } }.GetNewClosure())
$panel.Add_Click($hideIt)
$hud.Add_Click($hideIt)
if ($cfg.CloseOnFocusLost) {
    $hud.Add_Deactivate({
        if (([Environment]::TickCount - $state.shownAt) -gt 300) { $hud.Hide() }
    }.GetNewClosure())
}
$hud.Add_FormClosing({
    param($s,$e)
    if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) { $e.Cancel = $true; $hud.Hide() }
}.GetNewClosure())

# Forcer la creation du handle + 1er rendu hors ecran (1er Show instantane).
$hud.Left = -32000; $hud.Top = -32000
$hud.Show(); $hud.Hide()

# --- Enregistrement du hotkey global ---
$hk = New-Object QuickRefHotkey
$hk.add_Pressed($toggle)
$parts = ConvertTo-Hotkey $cfg.Hotkey
$ok = $hk.Register($parts.Mods, $parts.Vk)
L ("hotkey '$($cfg.Hotkey)' (mods=$($parts.Mods) vk=$($parts.Vk)) register=$ok grille=$($cfg.Rows)x$($cfg.Cols) cellules=$($cfg.Grid.Count) taille=${winW}x${winH}")
if (-not $ok) { L "ECHEC RegisterHotKey : combinaison probablement deja prise par une autre app." }

# --- Boucle de messages ---
$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)

try { $hk.Unregister() } catch {}
try { $mutex.ReleaseMutex() } catch {}
