// Included in the guarded window_manager source overlay. Keep the saved
// placement, styles and frameless state together across the whole transition.
void WindowManager::SetFullScreen(const flutter::EncodableMap& args) {
  const bool fullscreen =
      std::get<bool>(args.at(flutter::EncodableValue("isFullScreen")));
  if (fullscreen == g_is_window_fullscreen) return;
  const HWND window = GetMainWindow();
  // The playback frame plugin applies taskbar and Z-order state after the
  // bounds change. This overlay only owns bounds/restoration.

  auto restore = [&] {
    g_is_window_fullscreen = false;
    title_bar_style_ = g_title_bar_style_before_fullscreen;
    is_frameless_ = g_frameless_before_fullscreen;
    ::SetWindowLongPtr(window, GWL_STYLE, g_style_before_fullscreen);
    // Restore synchronously: a posted SC_MAXIMIZE can otherwise run during
    // the next fullscreen transition and replace its monitor-sized bounds.
    ::SetWindowPlacement(window, &g_placement_before_fullscreen);
    ::SetWindowPos(window, nullptr, g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.top,
                   g_frame_before_fullscreen.right - g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.bottom - g_frame_before_fullscreen.top,
                   SWP_NOACTIVATE | SWP_NOZORDER | SWP_FRAMECHANGED);
  };

  if (!fullscreen) {
    restore();
    return;
  }

  MONITORINFO monitor{};
  monitor.cbSize = sizeof(monitor);
  g_placement_before_fullscreen.length = sizeof(WINDOWPLACEMENT);
  if (!::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                        &monitor) ||
      !::GetWindowRect(window, &g_frame_before_fullscreen) ||
      !::GetWindowPlacement(window, &g_placement_before_fullscreen)) {
    return;
  }
  g_style_before_fullscreen = ::GetWindowLong(window, GWL_STYLE);
  g_title_bar_style_before_fullscreen = title_bar_style_;
  g_frameless_before_fullscreen = is_frameless_;
  g_is_window_fullscreen = true;
  is_frameless_ = true;
  ::SetLastError(ERROR_SUCCESS);
  if ((!::SetWindowLongPtr(window, GWL_STYLE,
                           g_style_before_fullscreen &
                               ~(WS_OVERLAPPEDWINDOW | WS_MAXIMIZE)) &&
       ::GetLastError() != ERROR_SUCCESS) ||
      !::SetWindowPos(window, HWND_TOP, monitor.rcMonitor.left,
                      monitor.rcMonitor.top,
                      monitor.rcMonitor.right - monitor.rcMonitor.left,
                      monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                      SWP_NOOWNERZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)) {
    restore();
  }
}
