# Show-QuickRef.ps1  (RESIDENT)
# Process leger qui reste en fond : WinForms charge une fois, fenetre pre-construite.
# Un hotkey global natif (RegisterHotKey) affiche/masque la fenetre instantanement.
# Se masque sur Echap, clic, perte de focus. Single-instance (mutex).
# Contrainte : la fenetre ne recouvre jamais le curseur de la souris.
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

# --- Lecture de la config ---
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$configPath = Join-Path $root 'config.json'

function Get-DefaultConfig {
    @{
        Title='Raccourcis'; Hotkey='Ctrl+Alt+W'; FontName='Consolas'; FontSize=13; Bold=$false
        Padding=26; LineSpacing=8; CloseOnFocusLost=$true
        Bg=@(24,24,28); Fg=@(235,235,235); Accent=@(96,230,150); Border=@(96,230,150)
        Lines=@('config.json introuvable, valeurs par defaut.')
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
        Title    = if ($j.title) { [string]$j.title } else { 'Raccourcis' }
        Hotkey   = if ($j.hotkey) { [string]$j.hotkey } else { 'Ctrl+Alt+W' }
        FontName = if ($j.font -and $j.font.name) { [string]$j.font.name } else { 'Consolas' }
        FontSize = if ($j.font -and $j.font.size) { [double]$j.font.size } else { 13 }
        Bold     = if ($j.font -and $null -ne $j.font.bold) { [bool]$j.font.bold } else { $false }
        Padding  = if ($null -ne $j.padding) { [int]$j.padding } else { 26 }
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
    $mods = $mods -bor 0x4000   # MOD_NOREPEAT : pas de re-declenchement si la touche reste enfoncee
    @{ Mods = [uint32]$mods; Vk = [uint32]$vk }
}

# --- Polices et couleurs ---
$bodyStyle = if ($cfg.Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
$bodyFont  = New-Object System.Drawing.Font($cfg.FontName, [single]$cfg.FontSize, $bodyStyle)
$titleFont = New-Object System.Drawing.Font($cfg.FontName, [single]($cfg.FontSize + 3), [System.Drawing.FontStyle]::Bold)
$colBg     = [System.Drawing.Color]::FromArgb($cfg.Bg[0],$cfg.Bg[1],$cfg.Bg[2])
$colFg     = [System.Drawing.Color]::FromArgb($cfg.Fg[0],$cfg.Fg[1],$cfg.Fg[2])
$colAccent = [System.Drawing.Color]::FromArgb($cfg.Accent[0],$cfg.Accent[1],$cfg.Accent[2])
$colBorder = [System.Drawing.Color]::FromArgb($cfg.Border[0],$cfg.Border[1],$cfg.Border[2])

# --- Dimensionnement au contenu ---
$measure   = [System.Drawing.Graphics]::FromImage((New-Object System.Drawing.Bitmap 1,1))
$titleSize = $measure.MeasureString($cfg.Title, $titleFont)
$maxLineW  = 0
foreach ($l in $cfg.Lines) { $w = $measure.MeasureString($l, $bodyFont).Width; if ($w -gt $maxLineW) { $maxLineW = $w } }
$measure.Dispose()
$pad     = $cfg.Padding
$lineH   = [int]$bodyFont.GetHeight()
$titleH  = [int]$titleFont.GetHeight()
$bigGap  = [int]($lineH * 0.8)
$winW = [int]([Math]::Ceiling([Math]::Max($titleSize.Width, $maxLineW))) + $pad * 2
$winH = $pad * 2 + $titleH + $bigGap + ($cfg.Lines.Count * ($lineH + $cfg.LineSpacing)) - $cfg.LineSpacing

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

$brushFg     = New-Object System.Drawing.SolidBrush ($colFg)
$brushAccent = New-Object System.Drawing.SolidBrush ($colAccent)
$penBorder   = New-Object System.Drawing.Pen ($colBorder, 1)
$textY = [int](($titleH))   # recalcule dans Paint via pad

$panel.Add_Paint({
    param($s,$e)
    $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $e.Graphics.Clear($colBg)
    $x = $pad; $y = $pad
    $e.Graphics.DrawString($cfg.Title, $titleFont, $brushAccent, [single]$x, [single]$y)
    $y += $titleH + $bigGap
    foreach ($l in $cfg.Lines) {
        $e.Graphics.DrawString($l, $bodyFont, $brushFg, [single]$x, [single]$y)
        $y += $lineH + $cfg.LineSpacing
    }
    $e.Graphics.DrawRectangle($penBorder, 0, 0, $panel.Width - 1, $panel.Height - 1)
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
        # Ignorer la desactivation parasite dans les ~300 ms suivant l'ouverture.
        if (([Environment]::TickCount - $state.shownAt) -gt 300) { $hud.Hide() }
    }.GetNewClosure())
}
# Ne jamais vraiment fermer la fenetre via la croix systeme : on masque.
$hud.Add_FormClosing({
    param($s,$e)
    if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) { $e.Cancel = $true; $hud.Hide() }
}.GetNewClosure())

# Forcer la creation du handle + 1er rendu hors ecran (pour que le 1er Show soit instantane).
$hud.Left = -32000; $hud.Top = -32000
$hud.Show(); $hud.Hide()

# --- Enregistrement du hotkey global ---
$hk = New-Object QuickRefHotkey
$hk.add_Pressed($toggle)
$parts = ConvertTo-Hotkey $cfg.Hotkey
$ok = $hk.Register($parts.Mods, $parts.Vk)
L ("hotkey '$($cfg.Hotkey)' (mods=$($parts.Mods) vk=$($parts.Vk)) register=" + $ok)
if (-not $ok) { L "ECHEC RegisterHotKey : combinaison probablement deja prise par une autre app." }

# --- Boucle de messages (garde le process vivant et capte le hotkey) ---
$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)

# Nettoyage (rarement atteint : le process est tue a la desinstallation)
try { $hk.Unregister() } catch {}
try { $mutex.ReleaseMutex() } catch {}
