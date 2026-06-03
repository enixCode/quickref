// install.rs - startup bootstrap helpers for quickref.
// No install/uninstall sub-commands; distribution is handled by cargo-dist.

use std::path::PathBuf;

use winreg::enums::{HKEY_CURRENT_USER, KEY_WRITE};
use winreg::RegKey;

const RUN_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Run";
const VALUE_NAME: &str = "quickref";

/// Returns %APPDATA%\quickref, or "." as fallback.
pub fn config_dir() -> PathBuf {
    let base = std::env::var("APPDATA").unwrap_or_else(|_| ".".into());
    PathBuf::from(base).join("quickref")
}

/// If config_dir()/config.json does not exist, create the dir and write the
/// embedded default config. Errors are silently ignored.
pub fn ensure_default_config() {
    let dir = config_dir();
    let cfg_path = dir.join("config.json");
    if cfg_path.exists() {
        return;
    }
    let _ = std::fs::create_dir_all(&dir);
    let default_cfg = include_str!("../config.json");
    let _ = std::fs::write(&cfg_path, default_cfg);
}

/// Write HKCU\Software\Microsoft\Windows\CurrentVersion\Run -> quickref = "<exe>".
/// Errors are silently ignored.
pub fn ensure_autostart() {
    let exe = match std::env::current_exe() {
        Ok(p) => p,
        Err(_) => return,
    };
    let value = format!("\"{}\"", exe.display());
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    if let Ok((key, _)) = hkcu.create_subkey_with_flags(RUN_KEY, KEY_WRITE) {
        let _ = key.set_value(VALUE_NAME, &value);
    }
}

