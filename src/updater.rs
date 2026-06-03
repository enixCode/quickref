//! Auto-update via github.com UNIQUEMENT (jamais api.github.com, pas d'auth, pas
//! de token). Marche donc meme pour quelqu'un qui n'est pas authentifie, ou sur
//! un reseau ou l'API GitHub est bloquee (cas reel observe). Tout est defensif :
//! la moindre erreur / hors-ligne => pas de mise a jour, l'app continue.
use std::io::Read;
use std::time::Duration;

const REPO: &str = "enixCode/quickref";
const ASSET: &str = "quickref-x86_64-pc-windows-msvc.zip";

/// Renvoie true si une mise a jour a ete appliquee (l'appelant relance + sort).
pub fn maybe_update(current: &str) -> bool {
    try_update(current).unwrap_or(false)
}

fn try_update(current: &str) -> Option<bool> {
    // 1. Derniere version via la redirection github.com de /releases/latest
    //    -> /releases/tag/vX.Y.Z (aucune API, aucun token).
    let resp = ureq::AgentBuilder::new()
        .build()
        .get(&format!("https://github.com/{REPO}/releases/latest"))
        .set("User-Agent", "quickref")
        .timeout(Duration::from_secs(6))
        .call()
        .ok()?;
    let final_url = resp.get_url().to_string();
    let latest = final_url
        .rsplit('/')
        .next()?
        .trim_start_matches('v')
        .trim();
    if !is_newer(latest, current) {
        return Some(false);
    }

    // 2. Telecharger le zip de la release depuis github.com (suit la redirection
    //    vers le CDN tout seul).
    let resp = ureq::AgentBuilder::new()
        .build()
        .get(&format!("https://github.com/{REPO}/releases/latest/download/{ASSET}"))
        .set("User-Agent", "quickref")
        .timeout(Duration::from_secs(90))
        .call()
        .ok()?;
    let mut zip_bytes = Vec::new();
    resp.into_reader().read_to_end(&mut zip_bytes).ok()?;

    // 3. Extraire quickref.exe du zip (cherche l'entree qui finit par ce nom,
    //    qu'elle soit a la racine ou dans un sous-dossier).
    let mut archive = zip::ZipArchive::new(std::io::Cursor::new(zip_bytes)).ok()?;
    let mut exe_bytes = Vec::new();
    let mut found = false;
    for i in 0..archive.len() {
        let mut entry = archive.by_index(i).ok()?;
        if entry.name().replace('\\', "/").ends_with("quickref.exe") {
            entry.read_to_end(&mut exe_bytes).ok()?;
            found = true;
            break;
        }
    }
    if !found || exe_bytes.len() < 100_000 {
        return Some(false);
    }

    // 4. Ecrire en temp et remplacer l'exe en cours.
    let tmp = std::env::temp_dir().join("quickref-update-new.exe");
    std::fs::write(&tmp, &exe_bytes).ok()?;
    self_replace::self_replace(&tmp).ok()?;
    let _ = std::fs::remove_file(&tmp);
    Some(true)
}

fn is_newer(latest: &str, current: &str) -> bool {
    parse(latest) > parse(current)
}

fn parse(v: &str) -> (u32, u32, u32) {
    let mut it = v.split('.').map(|x| x.trim().parse::<u32>().unwrap_or(0));
    (
        it.next().unwrap_or(0),
        it.next().unwrap_or(0),
        it.next().unwrap_or(0),
    )
}
