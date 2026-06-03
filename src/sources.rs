//! Dynamic sources: read an external file and extract (key, action) pairs by
//! regex, with optional find/replace rules. Port of the PowerShell Get-SourceItems.
//! Agnostic: works for keybindings.json (VSCode), a .vim, a .toml, anything.
use regex::{Regex, RegexBuilder};

use crate::config::Source;

/// Expand %VAR% and a leading ~, then normalise slashes to backslashes.
fn expand_path(p: &str) -> String {
    let re = Regex::new(r"%([^%]+)%").unwrap();
    let s = re
        .replace_all(p, |c: &regex::Captures| std::env::var(&c[1]).unwrap_or_default())
        .into_owned();
    let s = if let Some(rest) = s.strip_prefix('~') {
        format!("{}{}", std::env::var("USERPROFILE").unwrap_or_default(), rest)
    } else {
        s
    };
    s.replace('/', "\\")
}

/// Extract "key sep action" lines from the source file.
pub fn extract(src: &Source, cell_sep: &str) -> Vec<String> {
    let file = expand_path(&src.file);
    let path = std::path::Path::new(&file);
    if !path.exists() {
        let name = path
            .file_name()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_else(|| file.clone());
        return vec![format!("(source introuvable : {})", name)];
    }
    let text = match std::fs::read(path) {
        Ok(b) => String::from_utf8_lossy(&b).into_owned(),
        Err(_) => return vec!["(lecture impossible)".into()],
    };
    let re = match RegexBuilder::new(&src.regex)
        .case_insensitive(src.ignore_case)
        .dot_matches_new_line(true)
        .build()
    {
        Ok(r) => r,
        Err(_) => return vec!["(regex invalide)".into()],
    };

    let sep = src.sep.clone().unwrap_or_else(|| cell_sep.to_string());
    // Precompile the find/replace rules once.
    let rules: Vec<(Regex, &str)> = src
        .replace
        .iter()
        .filter_map(|r| Regex::new(&r.find).ok().map(|re| (re, r.to.as_str())))
        .collect();
    let apply = |mut s: String| -> String {
        for (re, to) in &rules {
            s = re.replace_all(&s, *to).into_owned();
        }
        s.trim().to_string()
    };

    let mut out = Vec::new();
    for caps in re.captures_iter(&text) {
        let k = apply(
            caps.get(src.key)
                .map(|m| m.as_str().trim().to_string())
                .unwrap_or_default(),
        );
        let a = apply(
            caps.get(src.action)
                .map(|m| m.as_str().trim().to_string())
                .unwrap_or_default(),
        );
        if k.is_empty() {
            continue;
        }
        out.push(if a.is_empty() {
            k
        } else {
            format!("{} {} {}", k, sep, a)
        });
        if src.limit > 0 && out.len() >= src.limit {
            break;
        }
    }
    if out.is_empty() {
        return vec!["(aucune correspondance regex)".into()];
    }
    out
}
