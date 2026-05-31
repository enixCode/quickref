# Show-QuickRef.ps1  (RESIDENT, WPF)
# Process leger qui reste en fond. Un hotkey global natif (RegisterHotKey) affiche/masque
# une fenetre WPF sans bords contenant une GRILLE (lignes x colonnes) definie dans config.json.
# WPF gere la mise en page (Grid natif) : pas de calcul pixel, pas de crash de layout.
# Se masque sur Echap, clic, perte de focus. Single-instance (mutex).
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'quickref-resident.log'
function L($m) { try { "[$([DateTime]::Now.ToString('HH:mm:ss'))] $m" | Add-Content $log } catch {} }

# --- Single instance ---
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'quickref-resident-singleton', [ref]$createdNew)
if (-not $createdNew) { return }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# --- Chemins + auto-update ---
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$configPath = Join-Path $root 'config.json'
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

# --- Lecture config ---
function Get-Cfg {
    $def = @{
        Hotkey='Ctrl+Alt+W'; FontName='Consolas'; FontSize=13; Separator='='; CloseOnFocusLost=$true
        Footer=''; Bg='#181820'; Fg='#D2D2D6'; Accent='#60E696'; Border='#60E696'
        Rows=1; Cols=1; Cells=@(@{ Row=0; Col=0; Title='QUICKREF'; Items=@('config.json introuvable') })
    }
    if (-not (Test-Path $configPath)) { return $def }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($configPath)
        $j = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    } catch { return $def }
    $hex = { param($v,$d) if ($v -and $v.Count -eq 3) { '#{0:X2}{1:X2}{2:X2}' -f [int]$v[0],[int]$v[1],[int]$v[2] } else { $d } }
    $cells = @()
    $rows = 1; $cols = 1
    if ($j.grid -and $j.grid.cells) {
        foreach ($c in $j.grid.cells) {
            $cells += @{
                Row=[int]$c.row; Col=[int]$c.col
                Title=[string]$c.title
                Items=@(if ($c.items) { $c.items | ForEach-Object { [string]$_ } })
            }
        }
        $rows = if ($j.grid.rows) { [int]$j.grid.rows } else { (($cells.Row | Measure-Object -Maximum).Maximum + 1) }
        $cols = if ($j.grid.cols) { [int]$j.grid.cols } else { (($cells.Col | Measure-Object -Maximum).Maximum + 1) }
    }
    @{
        Hotkey   = if ($j.hotkey) { [string]$j.hotkey } else { 'Ctrl+Alt+W' }
        FontName = if ($j.font.name) { [string]$j.font.name } else { 'Consolas' }
        FontSize = if ($j.font.size) { [double]$j.font.size } else { 13 }
        Separator = if ($j.separator) { [string]$j.separator } else { '=' }
        CloseOnFocusLost = if ($null -ne $j.closeOnFocusLost) { [bool]$j.closeOnFocusLost } else { $true }
        Footer = if ($j.footer) { [string]$j.footer } else { '' }
        Bg = & $hex $j.colors.background '#181820'
        Fg = & $hex $j.colors.foreground '#D2D2D6'
        Accent = & $hex $j.colors.accent '#60E696'
        Border = & $hex $j.colors.border '#60E696'
        Rows = $rows; Cols = $cols; Cells = $cells
    }
}
$cfg = Get-Cfg

L "config lue : grille $($cfg.Rows)x$($cfg.Cols), $($cfg.Cells.Count) cellules"

# --- Couleurs WPF ---
function Brush([string]$hex) {
    [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}
$brBg     = Brush $cfg.Bg
$brFg     = Brush $cfg.Fg
$brAccent = Brush $cfg.Accent
$brBorder = Brush $cfg.Border
$brFoot   = Brush '#9696A0'
$fontFamily = [System.Windows.Media.FontFamily]::new($cfg.FontName)

# --- Fenetre WPF sans bords ---
$win = New-Object System.Windows.Window
$win.Title       = 'quickref-hud'
$win.WindowStyle = 'None'
$win.ResizeMode  = 'NoResize'
$win.AllowsTransparency = $true
$win.Background  = 'Transparent'
$win.ShowInTaskbar = $false
$win.Topmost     = $true
$win.SizeToContent = 'WidthAndHeight'
$win.WindowStartupLocation = 'Manual'

# Bordure + fond
$root = New-Object System.Windows.Controls.Border
$root.Background = $brBg
$root.BorderBrush = $brBorder
$root.BorderThickness = 1
$root.Padding = 24
$root.CornerRadius = 8
$win.Content = $root

$outer = New-Object System.Windows.Controls.StackPanel
$root.Child = $outer

# --- La grille ---
$grid = New-Object System.Windows.Controls.Grid
for ($c = 0; $c -lt $cfg.Cols; $c++) {
    $cd = New-Object System.Windows.Controls.ColumnDefinition
    $cd.Width = 'Auto'
    $grid.ColumnDefinitions.Add($cd)
}
for ($r = 0; $r -lt $cfg.Rows; $r++) {
    $rd = New-Object System.Windows.Controls.RowDefinition
    $rd.Height = 'Auto'
    $grid.RowDefinitions.Add($rd)
}

$sep = $cfg.Separator
foreach ($cell in $cfg.Cells) {
    if ($cell.Row -ge $cfg.Rows -or $cell.Col -ge $cfg.Cols) { continue }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '0,0,46,22'

    if ($cell.Title) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $cell.Title
        $t.Foreground = $brAccent
        $t.FontFamily = $fontFamily
        $t.FontSize = $cfg.FontSize + 2
        $t.FontWeight = 'Bold'
        $t.Margin = '0,0,0,8'
        [void]$sp.Children.Add($t)
    }

    foreach ($item in $cell.Items) {
        $line = New-Object System.Windows.Controls.TextBlock
        $line.FontFamily = $fontFamily
        $line.FontSize = $cfg.FontSize
        $line.Margin = '0,0,0,5'
        $idx = $item.IndexOf($sep)
        if ($idx -ge 0) {
            $key = $item.Substring(0, $idx).TrimEnd()
            $act = $item.Substring($idx + $sep.Length).TrimStart()
            $rk = New-Object System.Windows.Documents.Run($key + '  ')
            $rk.Foreground = $brAccent
            $rk.FontWeight = 'Bold'
            $ra = New-Object System.Windows.Documents.Run($act)
            $ra.Foreground = $brFg
            [void]$line.Inlines.Add($rk)
            [void]$line.Inlines.Add($ra)
        } else {
            $line.Text = $item
            $line.Foreground = $brFg
        }
        [void]$sp.Children.Add($line)
    }

    [System.Windows.Controls.Grid]::SetRow($sp, $cell.Row)
    [System.Windows.Controls.Grid]::SetColumn($sp, $cell.Col)
    [void]$grid.Children.Add($sp)
}
[void]$outer.Children.Add($grid)

# --- Footer ---
if ($cfg.Footer) {
    $f = New-Object System.Windows.Controls.TextBlock
    $f.Text = $cfg.Footer
    $f.Foreground = $brFoot
    $f.FontFamily = $fontFamily
    $f.FontSize = [Math]::Max(9, $cfg.FontSize - 3)
    $f.FontStyle = 'Italic'
    $f.Margin = '0,6,0,0'
    [void]$outer.Children.Add($f)
}

L 'fenetre WPF construite'

# --- Parse hotkey ---
function ConvertTo-Hotkey([string]$s) {
    $mods = 0; $vk = 0
    foreach ($p in ($s -split '\+')) {
        $t = $p.Trim().ToLower()
        if     ($t -eq 'ctrl' -or $t -eq 'control') { $mods = $mods -bor 2 }
        elseif ($t -eq 'alt')   { $mods = $mods -bor 1 }
        elseif ($t -eq 'shift') { $mods = $mods -bor 4 }
        elseif ($t -eq 'win')   { $mods = $mods -bor 8 }
        else {
            $k = $p.Trim().ToUpper()
            if ($k -eq 'SPACE') { $vk = 0x20 }
            elseif ($k.Length -eq 1) { $vk = [int][char]$k }
            elseif ($k -match '^F([1-9]|1[0-2])$') { $vk = 0x70 + [int]$k.Substring(1) - 1 }
        }
    }
    @{ Mods = ($mods -bor 0x4000); Vk = $vk }
}

# --- Fenetre-message C# qui capte le hotkey global (pattern eprouve) ---
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class QuickRefHotkey : NativeWindow {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mod, uint vk);
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

Add-Type -AssemblyName System.Windows.Forms

# --- Placement en PIXELS physiques via Win32 (coherent quel que soit le DPI) ---
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class QrPos {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public struct RECT { public int L, T, R, B; }
    public const uint NOSIZE = 0x0001, NOZORDER = 0x0004, SHOWWINDOW = 0x0040;
    public static void Move(IntPtr h, int x, int y) { SetWindowPos(h, IntPtr.Zero, x, y, 0, 0, NOSIZE | NOZORDER | SHOWWINDOW); }
    public static int W(IntPtr h) { RECT r; GetWindowRect(h, out r); return r.R - r.L; }
    public static int H(IntPtr h) { RECT r; GetWindowRect(h, out r); return r.B - r.T; }
}
'@

function Move-AwayFromCursor {
    # Tout en pixels physiques : Cursor/Screen et la taille fenetre (GetWindowRect).
    $hwnd = $script:hudHwnd
    $pt  = [System.Windows.Forms.Cursor]::Position
    $scr = [System.Windows.Forms.Screen]::FromPoint($pt).WorkingArea
    $w = [QrPos]::W($hwnd); $h = [QrPos]::H($hwnd)
    if ($w -le 0) { $w = 600 }; if ($h -le 0) { $h = 300 }
    $m = 16
    $cx = $scr.X + [int](($scr.Width - $w)/2)
    $cy = $scr.Y + [int](($scr.Height - $h)/2)
    $cands = @(
        @{X=$cx;Y=$cy}, @{X=$scr.X+$m;Y=$scr.Y+$m},
        @{X=$scr.Right-$w-$m;Y=$scr.Y+$m},
        @{X=$scr.X+$m;Y=$scr.Bottom-$h-$m},
        @{X=$scr.Right-$w-$m;Y=$scr.Bottom-$h-$m}
    )
    $ch = $cands[0]
    foreach ($c in $cands) {
        $in = ($pt.X -ge $c.X) -and ($pt.X -le ($c.X+$w)) -and ($pt.Y -ge $c.Y) -and ($pt.Y -le ($c.Y+$h))
        if (-not $in) { $ch = $c; break }
    }
    [QrPos]::Move($hwnd, [int]$ch.X, [int]$ch.Y)
}

# --- Etat + toggle ---
$state = @{ shownAt = 0 }
$toggle = {
    if ($win.IsVisible) {
        $win.Hide()
    } else {
        $win.Show()
        Move-AwayFromCursor
        $state.shownAt = [Environment]::TickCount
        $win.Activate()
    }
}.GetNewClosure()

# --- Fermeture : Echap, clic, perte de focus ---
$win.Add_KeyDown({ if ($_.Key -eq 'Escape') { $win.Hide() } }.GetNewClosure())
$win.Add_MouseDown({ $win.Hide() }.GetNewClosure())
if ($cfg.CloseOnFocusLost) {
    $win.Add_Deactivated({
        if (([Environment]::TickCount - $state.shownAt) -gt 300) { $win.Hide() }
    }.GetNewClosure())
}

# Construire le layout une fois hors ecran pour un 1er affichage instantane,
# et recuperer le handle natif (pour le positionnement en pixels via Win32).
$win.Left = -32000; $win.Top = -32000
$win.Show()
$script:hudHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($win)).Handle
$win.Hide()

# --- Hotkey global : la fenetre-message C# appelle $toggle a chaque appui ---
$hk = New-Object QuickRefHotkey
$hk.add_Pressed($toggle)
$p = ConvertTo-Hotkey $cfg.Hotkey
$ok = $hk.Register([uint32]$p.Mods, [uint32]$p.Vk)
L "hotkey '$($cfg.Hotkey)' mods=$($p.Mods) vk=$($p.Vk) register=$ok"

# --- Boucle de messages WPF (pompe aussi les messages de la fenetre-message) ---
[System.Windows.Threading.Dispatcher]::Run()

try { $hk.Unregister() } catch {}
try { $mutex.ReleaseMutex() } catch {}
