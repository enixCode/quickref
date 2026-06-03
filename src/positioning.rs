//! Win32 sizing/positioning. The HUD fills the work area of the monitor under
//! the cursor, inset by a margin, in physical pixels (DPI-correct). Also clips
//! the window to a rounded rect.
use windows::Win32::Foundation::{HWND, POINT};
use windows::Win32::Graphics::Gdi::{
    CreateRoundRectRgn, GetMonitorInfoW, MonitorFromPoint, SetWindowRgn, MONITORINFOEXW,
    MONITOR_DEFAULTTONEAREST,
};
use windows::Win32::UI::WindowsAndMessaging::{
    GetCursorPos, SetWindowPos, SWP_NOZORDER, SWP_SHOWWINDOW,
};

/// Size the window to the cursor's monitor work area, inset by `margin` physical
/// pixels on every side, and round its corners. When `onscreen` is false the
/// window is parked off-screen (same size) so a centering pass stays invisible.
pub fn place_monitor(hwnd: HWND, margin: i32, onscreen: bool) {
    unsafe {
        let mut cursor = POINT::default();
        if GetCursorPos(&mut cursor).is_err() {
            return;
        }
        let hmon = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
        let mut mi = MONITORINFOEXW::default();
        mi.monitorInfo.cbSize = std::mem::size_of::<MONITORINFOEXW>() as u32;
        if !GetMonitorInfoW(hmon, &mut mi.monitorInfo).as_bool() {
            return;
        }

        let wa = mi.monitorInfo.rcWork; // work area, physical pixels
        let m = margin.max(0);
        let w = (wa.right - wa.left - 2 * m).max(100);
        let h = (wa.bottom - wa.top - 2 * m).max(100);
        let (x, y) = if onscreen {
            (wa.left + m, wa.top + m)
        } else {
            (-32000, -32000)
        };

        let _ = SetWindowPos(hwnd, None, x, y, w, h, SWP_NOZORDER | SWP_SHOWWINDOW);

        let r = 16i32;
        let hrgn = CreateRoundRectRgn(0, 0, w, h, r * 2, r * 2);
        if !hrgn.is_invalid() {
            let _ = SetWindowRgn(hwnd, Some(hrgn), true);
        }
    }
}
