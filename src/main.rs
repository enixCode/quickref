// quickref - global hotkey HUD (egui/eframe, Windows)
// -----------------------------------------------------------------
// IMPORTANT: GlobalHotKeyManager is created on the main thread BEFORE
// eframe::run_native and kept alive for the whole run. A background
// thread pumps hotkey events and wakes the egui loop via request_repaint,
// so the resident reacts to the hotkey even while the window is hidden,
// without busy-spinning.
// -----------------------------------------------------------------
#![windows_subsystem = "windows"]

mod app;
mod config;
mod install;
mod positioning;
mod sources;

use std::sync::atomic::Ordering;

use eframe::egui::{Vec2, ViewportBuilder};
use global_hotkey::{
    hotkey::{Code, HotKey, Modifiers},
    GlobalHotKeyEvent, GlobalHotKeyManager, HotKeyState,
};

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() -> eframe::Result<()> {
    let dev = std::env::args().any(|a| a == "--dev");
    if !dev {
        install::ensure_default_config();
        install::ensure_autostart();
        install::spawn_updater();
    }
    let mut cfg = config::load_config();
    let mut version = VERSION.to_string();
    if dev {
        cfg.colors.accent = [255, 165, 0];
        cfg.footer = format!("[ MODE DEV ]    {}", cfg.footer);
        version = format!("{} DEV", VERSION);
    }
    run_resident(cfg, version)
}

fn run_resident(cfg: config::Config, version: String) -> eframe::Result<()> {
    // Register the global hotkey on the main thread, keep the manager alive.
    let manager = GlobalHotKeyManager::new().expect("Failed to create GlobalHotKeyManager");
    let hotkey = parse_hotkey(&cfg.hotkey)
        .unwrap_or_else(|| HotKey::new(Some(Modifiers::CONTROL | Modifiers::ALT), Code::KeyW));
    manager.register(hotkey).expect("Failed to register hotkey");
    let hotkey_id = hotkey.id();

    let native_options = eframe::NativeOptions {
        viewport: ViewportBuilder::default()
            .with_title("quickref-hud")
            .with_decorations(false)
            .with_resizable(false)
            .with_always_on_top()
            // Opaque (no transparency -> avoids Windows egui #4451 black window).
            .with_transparent(false)
            .with_visible(false) // starts hidden
            .with_inner_size(Vec2::new(1000.0, 560.0))
            .with_taskbar(false),
        ..Default::default()
    };

    let res = eframe::run_native(
        "quickref-hud",
        native_options,
        Box::new(move |cc| {
            // Load the configured font (e.g. Consolas) for all text.
            app::install_font(&cc.egui_ctx, &cfg.font.name);
            // Background pump: wake the egui loop on each hotkey press.
            let signal = std::sync::Arc::new(app::HotkeySignal::default());
            let ctx = cc.egui_ctx.clone();
            let sig = signal.clone();
            std::thread::spawn(move || {
                let rx = GlobalHotKeyEvent::receiver();
                while let Ok(ev) = rx.recv() {
                    if ev.id == hotkey_id && ev.state == HotKeyState::Pressed {
                        sig.toggles.fetch_add(1, Ordering::SeqCst);
                        ctx.request_repaint();
                    }
                }
            });
            Ok(Box::new(app::QuickRefApp::new(cfg, version, signal)))
        }),
    );

    drop(manager); // keep the registration alive until the run is over
    res
}

/// Parse "Ctrl+Alt+W" into a HotKey (modifiers + a single key).
fn parse_hotkey(s: &str) -> Option<HotKey> {
    let mut mods = Modifiers::empty();
    let mut code: Option<Code> = None;
    for part in s.split('+') {
        match part.trim().to_lowercase().as_str() {
            "ctrl" | "control" => mods |= Modifiers::CONTROL,
            "alt" => mods |= Modifiers::ALT,
            "shift" => mods |= Modifiers::SHIFT,
            "win" | "super" | "meta" => mods |= Modifiers::SUPER,
            other => code = parse_key_code(other),
        }
    }
    code.map(|c| {
        if mods.is_empty() {
            HotKey::new(None, c)
        } else {
            HotKey::new(Some(mods), c)
        }
    })
}

fn parse_key_code(s: &str) -> Option<Code> {
    if s.len() == 1 {
        return match s.chars().next().unwrap() {
            'a' => Some(Code::KeyA),
            'b' => Some(Code::KeyB),
            'c' => Some(Code::KeyC),
            'd' => Some(Code::KeyD),
            'e' => Some(Code::KeyE),
            'f' => Some(Code::KeyF),
            'g' => Some(Code::KeyG),
            'h' => Some(Code::KeyH),
            'i' => Some(Code::KeyI),
            'j' => Some(Code::KeyJ),
            'k' => Some(Code::KeyK),
            'l' => Some(Code::KeyL),
            'm' => Some(Code::KeyM),
            'n' => Some(Code::KeyN),
            'o' => Some(Code::KeyO),
            'p' => Some(Code::KeyP),
            'q' => Some(Code::KeyQ),
            'r' => Some(Code::KeyR),
            's' => Some(Code::KeyS),
            't' => Some(Code::KeyT),
            'u' => Some(Code::KeyU),
            'v' => Some(Code::KeyV),
            'w' => Some(Code::KeyW),
            'x' => Some(Code::KeyX),
            'y' => Some(Code::KeyY),
            'z' => Some(Code::KeyZ),
            '0' => Some(Code::Digit0),
            '1' => Some(Code::Digit1),
            '2' => Some(Code::Digit2),
            '3' => Some(Code::Digit3),
            '4' => Some(Code::Digit4),
            '5' => Some(Code::Digit5),
            '6' => Some(Code::Digit6),
            '7' => Some(Code::Digit7),
            '8' => Some(Code::Digit8),
            '9' => Some(Code::Digit9),
            _ => None,
        };
    }
    if let Some(rest) = s.strip_prefix('f') {
        if let Ok(n) = rest.parse::<u8>() {
            return match n {
                1 => Some(Code::F1),
                2 => Some(Code::F2),
                3 => Some(Code::F3),
                4 => Some(Code::F4),
                5 => Some(Code::F5),
                6 => Some(Code::F6),
                7 => Some(Code::F7),
                8 => Some(Code::F8),
                9 => Some(Code::F9),
                10 => Some(Code::F10),
                11 => Some(Code::F11),
                12 => Some(Code::F12),
                _ => None,
            };
        }
    }
    match s {
        "space" => Some(Code::Space),
        "tab" => Some(Code::Tab),
        "enter" | "return" => Some(Code::Enter),
        _ => None,
    }
}
