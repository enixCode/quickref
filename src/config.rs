use serde::Deserialize;

// ---------------------------------------------------------------------------
// Schema - everything optional with serde defaults, unknown fields ignored.
// ---------------------------------------------------------------------------

fn default_hotkey() -> String {
    "Ctrl+Alt+W".into()
}
fn default_separator() -> String {
    "=".into()
}
fn default_close_on_focus_lost() -> bool {
    true
}
fn default_font() -> FontConfig {
    FontConfig::default()
}
fn default_padding() -> f32 {
    24.0
}
fn default_line_spacing() -> f32 {
    7.0
}
fn default_colors() -> Colors {
    Colors::default()
}
fn default_grid() -> Grid {
    Grid::default()
}
fn default_screen_margin() -> i32 {
    64
}
fn default_border_width() -> f32 {
    2.0
}

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    #[serde(default)]
    pub title: String,
    #[serde(default = "default_hotkey")]
    pub hotkey: String,
    #[serde(default = "default_font")]
    pub font: FontConfig,
    #[serde(default = "default_padding")]
    pub padding: f32,
    #[serde(rename = "lineSpacing", default = "default_line_spacing")]
    pub line_spacing: f32,
    #[serde(default = "default_separator")]
    pub separator: String,
    #[serde(rename = "closeOnFocusLost", default = "default_close_on_focus_lost")]
    pub close_on_focus_lost: bool,
    #[serde(default)]
    pub footer: String,
    #[serde(default = "default_colors")]
    pub colors: Colors,
    #[serde(default = "default_grid")]
    pub grid: Grid,
    #[serde(rename = "screenMargin", default = "default_screen_margin")]
    pub screen_margin: i32,
    #[serde(rename = "borderWidth", default = "default_border_width")]
    pub border_width: f32,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            title: String::new(),
            hotkey: default_hotkey(),
            font: FontConfig::default(),
            padding: 24.0,
            line_spacing: 7.0,
            separator: default_separator(),
            close_on_focus_lost: true,
            footer: String::new(),
            colors: Colors::default(),
            grid: Grid::default(),
            screen_margin: 64,
            border_width: 2.0,
        }
    }
}

fn default_font_name() -> String {
    "Consolas".into()
}
fn default_font_size() -> f32 {
    13.0
}

#[derive(Debug, Deserialize, Clone)]
pub struct FontConfig {
    #[serde(default = "default_font_name")]
    pub name: String,
    #[serde(default = "default_font_size")]
    pub size: f32,
}

impl Default for FontConfig {
    fn default() -> Self {
        FontConfig {
            name: default_font_name(),
            size: default_font_size(),
        }
    }
}

fn default_bg() -> [u8; 3] {
    [24, 24, 28]
}
fn default_fg() -> [u8; 3] {
    [210, 210, 214]
}
fn default_accent() -> [u8; 3] {
    [96, 230, 150]
}
fn default_border() -> [u8; 3] {
    [96, 230, 150]
}

#[derive(Debug, Deserialize, Clone)]
pub struct Colors {
    #[serde(default = "default_bg")]
    pub background: [u8; 3],
    #[serde(default = "default_fg")]
    pub foreground: [u8; 3],
    #[serde(default = "default_accent")]
    pub accent: [u8; 3],
    #[serde(default = "default_border")]
    pub border: [u8; 3],
}

impl Default for Colors {
    fn default() -> Self {
        Colors {
            background: default_bg(),
            foreground: default_fg(),
            accent: default_accent(),
            border: default_border(),
        }
    }
}

fn default_rows() -> u32 {
    1
}
fn default_cols() -> u32 {
    1
}
fn default_col_gap() -> f32 {
    46.0
}
fn default_row_gap() -> f32 {
    22.0
}

#[derive(Debug, Deserialize, Clone)]
pub struct Grid {
    #[serde(default = "default_rows")]
    pub rows: u32,
    #[serde(default = "default_cols")]
    pub cols: u32,
    #[serde(rename = "colGap", default = "default_col_gap")]
    pub col_gap: f32,
    #[serde(rename = "rowGap", default = "default_row_gap")]
    pub row_gap: f32,
    #[serde(default)]
    pub cells: Vec<Cell>,
}

impl Default for Grid {
    fn default() -> Self {
        Grid {
            rows: 1,
            cols: 1,
            col_gap: 46.0,
            row_gap: 22.0,
            cells: vec![Cell {
                row: 0,
                col: 0,
                title: "QUICKREF".into(),
                items: vec!["config.json introuvable".into()],
                source: None,
                sources: Vec::new(),
                lines: Vec::new(),
            }],
        }
    }
}

/// A find/replace rule applied to a captured key/action (regex find -> to).
#[derive(Debug, Deserialize, Clone)]
pub struct Replace {
    pub find: String,
    #[serde(default)]
    pub to: String,
}

fn group_key() -> usize {
    1
}
fn group_action() -> usize {
    2
}
fn default_true() -> bool {
    true
}

/// A dynamic source: read `file`, extract (key, action) by `regex`.
#[derive(Debug, Deserialize, Clone)]
pub struct Source {
    pub file: String,
    pub regex: String,
    #[serde(default = "group_key")]
    pub key: usize,
    #[serde(default = "group_action")]
    pub action: usize,
    #[serde(default)]
    pub sep: Option<String>,
    /// 0 = no limit.
    #[serde(default)]
    pub limit: usize,
    #[serde(rename = "ignoreCase", default = "default_true")]
    pub ignore_case: bool,
    #[serde(default)]
    pub replace: Vec<Replace>,
}

/// A single grid cell. Static `items` plus optional dynamic `source`/`sources`.
#[derive(Debug, Deserialize, Clone)]
pub struct Cell {
    #[serde(default)]
    pub row: u32,
    #[serde(default)]
    pub col: u32,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub items: Vec<String>,
    #[serde(default)]
    pub source: Option<Source>,
    #[serde(default)]
    pub sources: Vec<Source>,
    /// Computed at load: static items + dynamic source lines.
    #[serde(skip)]
    pub lines: Vec<String>,
}

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

/// Try to load config from the file adjacent to the exe, then fall back to
/// ./config.json (dev), then return defaults.
pub fn load_config() -> Config {
    let mut cfg = load_raw();
    compute_lines(&mut cfg);
    cfg
}

/// Fill each cell's `lines` = static items + dynamic source lines (read once).
fn compute_lines(cfg: &mut Config) {
    let sep = cfg.separator.clone();
    for cell in &mut cfg.grid.cells {
        let mut lines = cell.items.clone();
        if let Some(s) = &cell.source {
            lines.extend(crate::sources::extract(s, &sep));
        }
        for s in &cell.sources {
            lines.extend(crate::sources::extract(s, &sep));
        }
        cell.lines = lines;
    }
}

fn load_raw() -> Config {
    // 1) Next to the exe
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let p = dir.join("config.json");
            if p.exists() {
                if let Ok(cfg) = load_from(&p) {
                    return cfg;
                }
            }
        }
    }
    // 2) %APPDATA%\quickref\config.json
    let p = crate::install::config_dir().join("config.json");
    if p.exists() {
        if let Ok(cfg) = load_from(&p) {
            return cfg;
        }
    }
    // 3) Embedded default (compile-time)
    if let Ok(cfg) = serde_json::from_str::<Config>(include_str!("../config.json")) {
        return cfg;
    }
    // 4) Struct default
    Config::default()
}

fn load_from(path: &std::path::Path) -> Result<Config, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(path)?;
    // Strip UTF-8 BOM if present
    let s = if bytes.starts_with(b"\xef\xbb\xbf") {
        std::str::from_utf8(&bytes[3..])?
    } else {
        std::str::from_utf8(&bytes)?
    };
    let cfg: Config = serde_json::from_str(s)?;
    Ok(cfg)
}
