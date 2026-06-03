// QuickRef app: eframe 0.34 App trait.
//   - logic(): runs every frame (even hidden). Hotkey toggle, Escape, focus-lost,
//     and Win32 sizing (monitor work area minus a margin) + rounded region.
//   - ui():    runs only while visible. Paints the grid centered in the window,
//     and measures the content block for centering.
//   - clear_color(): opaque background (no transparency -> avoids egui #4451).
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use eframe::egui::{self, Color32, FontId, RichText, ViewportCommand};
use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use windows::Win32::Foundation::HWND;

use crate::config::Config;
use crate::positioning::place_monitor;

fn rgb(a: [u8; 3]) -> Color32 {
    Color32::from_rgb(a[0], a[1], a[2])
}

/// Load the configured font (e.g. Consolas) and use it for all text.
pub fn install_font(ctx: &egui::Context, name: &str) {
    let Some(path) = font_file_for(name) else {
        return;
    };
    let Ok(bytes) = std::fs::read(&path) else {
        return;
    };
    let mut fonts = egui::FontDefinitions::default();
    fonts
        .font_data
        .insert("user".to_owned(), Arc::new(egui::FontData::from_owned(bytes)));
    for fam in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
        fonts.families.entry(fam).or_default().insert(0, "user".to_owned());
    }
    ctx.set_fonts(fonts);
}

/// Resolve a font name to a file under C:\Windows\Fonts (best effort).
fn font_file_for(name: &str) -> Option<std::path::PathBuf> {
    let dir = std::path::Path::new(r"C:\Windows\Fonts");
    let lower = name.to_lowercase();
    let mut candidates: Vec<String> = Vec::new();
    match lower.as_str() {
        "consolas" => candidates.push("consola.ttf".into()),
        "cascadia code" => candidates.push("CascadiaCode.ttf".into()),
        "cascadia mono" => candidates.push("CascadiaMono.ttf".into()),
        _ => {}
    }
    candidates.push(format!("{name}.ttf"));
    candidates.push(format!("{lower}.ttf"));
    candidates.into_iter().map(|c| dir.join(c)).find(|p| p.exists())
}

/// Set by the global-hotkey pump thread, read on the UI thread.
/// One increment per hotkey press; the UI thread folds parity into visibility.
#[derive(Default)]
pub struct HotkeySignal {
    pub toggles: AtomicU32,
}

pub struct QuickRefApp {
    cfg: Config,
    version: String,
    visible: bool,
    /// Window sized off-screen yet?
    sized: bool,
    /// Window moved on-screen yet?
    positioned: bool,
    frames_shown: u32,
    /// Measured content block size, used to center it in the window.
    block_size: egui::Vec2,
    shown_at: Instant,
    /// Debounce guard so hotkey auto-repeat can't desync show/hide.
    last_toggle: Instant,
    signal: Arc<HotkeySignal>,
}

impl QuickRefApp {
    pub fn new(cfg: Config, version: String, signal: Arc<HotkeySignal>) -> Self {
        Self {
            cfg,
            version,
            visible: false,
            sized: false,
            positioned: false,
            frames_shown: 0,
            block_size: egui::Vec2::ZERO,
            shown_at: Instant::now() - Duration::from_secs(10),
            last_toggle: Instant::now() - Duration::from_secs(10),
            signal,
        }
    }

    fn hwnd(frame: &eframe::Frame) -> Option<HWND> {
        let wh = frame.window_handle().ok()?;
        match wh.as_raw() {
            RawWindowHandle::Win32(h) => Some(HWND(h.hwnd.get() as *mut _)),
            _ => None,
        }
    }

    fn show(&mut self, ctx: &egui::Context) {
        self.visible = true;
        self.sized = false;
        self.positioned = false;
        self.frames_shown = 0;
        self.shown_at = Instant::now();
        // Park off-screen so the size + centering pass is invisible, then reveal.
        ctx.send_viewport_cmd(ViewportCommand::OuterPosition(egui::pos2(-32000.0, -32000.0)));
        ctx.send_viewport_cmd(ViewportCommand::Visible(true));
        ctx.send_viewport_cmd(ViewportCommand::Focus);
    }

    fn hide(&mut self, ctx: &egui::Context) {
        self.visible = false;
        ctx.send_viewport_cmd(ViewportCommand::Visible(false));
    }
}

impl eframe::App for QuickRefApp {
    fn clear_color(&self, _v: &egui::Visuals) -> [f32; 4] {
        rgb(self.cfg.colors.background).to_normalized_gamma_f32()
    }

    fn logic(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        // 1. Hotkey toggle (pumped by the background thread). Debounced so key
        //    auto-repeat can't desync the show/hide state and trap the user.
        let pending = self.signal.toggles.swap(0, Ordering::SeqCst) > 0;
        if pending && self.last_toggle.elapsed() > Duration::from_millis(250) {
            self.last_toggle = Instant::now();
            if self.visible {
                self.hide(ctx);
            } else {
                self.show(ctx);
            }
        }

        // 2. Escape -> hide.
        if self.visible && ctx.input(|i| i.key_pressed(egui::Key::Escape)) {
            self.hide(ctx);
        }

        // 2b. Click anywhere -> hide (always-available manual dismiss).
        if self.visible
            && self.shown_at.elapsed() > Duration::from_millis(200)
            && ctx.input(|i| i.pointer.any_pressed())
        {
            self.hide(ctx);
        }

        // 3. Focus lost -> hide (300 ms guard against the show event itself).
        if self.visible
            && self.cfg.close_on_focus_lost
            && self.shown_at.elapsed() > Duration::from_millis(300)
            && !ctx.input(|i| i.focused)
        {
            self.hide(ctx);
        }

        // 4. Size the window to the monitor (minus margin) off-screen, let the
        //    content center over a couple of frames, then move it on-screen.
        if self.visible {
            self.frames_shown += 1;
            if let Some(hwnd) = Self::hwnd(frame) {
                if !self.sized {
                    place_monitor(hwnd, self.cfg.screen_margin, false);
                    self.sized = true;
                } else if !self.positioned && self.frames_shown >= 3 {
                    place_monitor(hwnd, self.cfg.screen_margin, true);
                    self.positioned = true;
                }
            }
            // Keep frames coming while shown (centering convergence + Esc/focus).
            ctx.request_repaint();
        }
        // While hidden we do NOT request repaint: the loop sleeps until the pump
        // thread wakes it on the next hotkey press (light resident).
    }

    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        let accent = rgb(self.cfg.colors.accent);
        let fg = rgb(self.cfg.colors.foreground);
        let foot = Color32::from_rgb(150, 150, 160);

        let sep = self.cfg.separator.clone();
        let footer = self.cfg.footer.clone();
        let version = self.version.clone();
        let fs = self.cfg.font.size;
        let title_fs = fs + 2.0;
        let foot_fs = (fs - 3.0).max(9.0);
        let line_sp = self.cfg.line_spacing;
        let rows = self.cfg.grid.rows as usize;
        let cols = self.cfg.grid.cols as usize;
        let col_gap = self.cfg.grid.col_gap;
        let row_gap = self.cfg.grid.row_gap;

        // Center the measured block (previous frame) in the full window.
        let avail = ui.available_size();
        let left = if self.block_size.x > 1.0 {
            ((avail.x - self.block_size.x) * 0.5).max(0.0)
        } else {
            0.0
        };
        let top = if self.block_size.y > 1.0 {
            ((avail.y - self.block_size.y) * 0.5).max(0.0)
        } else {
            0.0
        };
        if top > 0.0 {
            ui.add_space(top);
        }

        let block = ui
            .horizontal(|ui| {
                if left > 0.0 {
                    ui.add_space(left);
                }
                ui.vertical(|ui| {
                    ui.spacing_mut().item_spacing.y = line_sp;

                    let grid = egui::Grid::new("main_grid")
                        .num_columns(cols)
                        .spacing([col_gap, row_gap])
                        .show(ui, |ui| {
                            for r in 0..rows {
                                for c in 0..cols {
                                    let cell = self
                                        .cfg
                                        .grid
                                        .cells
                                        .iter()
                                        .find(|x| x.row as usize == r && x.col as usize == c);
                                    ui.vertical(|ui| {
                                        ui.spacing_mut().item_spacing.y = line_sp;
                                        if let Some(cell) = cell {
                                            if !cell.title.is_empty() {
                                                ui.label(
                                                    RichText::new(&cell.title)
                                                        .color(accent)
                                                        .strong()
                                                        .font(FontId::proportional(title_fs)),
                                                );
                                            }
                                            for it in &cell.lines {
                                                render_item(ui, it, &sep, accent, fg, fs);
                                            }
                                        }
                                    });
                                }
                                ui.end_row();
                            }
                        });

                    let w = grid.response.rect.width().max(1.0);
                    ui.add_space(6.0);
                    if !footer.is_empty() {
                        ui.label(
                            RichText::new(&footer)
                                .color(foot)
                                .italics()
                                .font(FontId::proportional(foot_fs)),
                        );
                    }
                    ui.allocate_ui_with_layout(
                        egui::vec2(w, foot_fs + 6.0),
                        egui::Layout::right_to_left(egui::Align::Center),
                        |ui| {
                            ui.label(
                                RichText::new(format!("v{version}"))
                                    .color(foot)
                                    .font(FontId::proportional(foot_fs)),
                            );
                        },
                    );
                })
                .response
                .rect
            })
            .inner;

        // Remember the block size for next-frame centering.
        self.block_size = block.size();

        // Rounded border in the configured border color, flush with the window
        // edge and matching its Win32 rounded clip (16 px physical -> points).
        let bw = self.cfg.border_width;
        if bw > 0.0 {
            let ppp = ui.ctx().pixels_per_point();
            let rad = ((16.0 / ppp).round() as i32).clamp(0, 255) as u8;
            let rect = ui.ctx().content_rect();
            ui.painter().rect_stroke(
                rect,
                egui::CornerRadius::same(rad),
                egui::Stroke::new(bw, rgb(self.cfg.colors.border)),
                egui::StrokeKind::Inside,
            );
        }
    }
}

/// Render one "key SEP action" line: key in accent+bold, action in foreground.
fn render_item(ui: &mut egui::Ui, item: &str, sep: &str, accent: Color32, fg: Color32, fs: f32) {
    if let Some(idx) = item.find(sep) {
        let key = item[..idx].trim_end();
        let action = item[idx + sep.len()..].trim_start();
        ui.horizontal(|ui| {
            ui.spacing_mut().item_spacing.x = 4.0;
            ui.label(RichText::new(key).color(accent).strong().font(FontId::monospace(fs)));
            ui.label(RichText::new(action).color(fg).font(FontId::monospace(fs)));
        });
    } else {
        ui.label(RichText::new(item).color(fg).font(FontId::monospace(fs)));
    }
}
