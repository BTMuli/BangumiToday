// Dart imports:
import 'dart:convert';
import 'dart:ffi';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

enum _TrayResourceType { menu, menuItem, trayIcon, image }

/// 将托盘资源登记在主窗口上，供热重启后的新 isolate 回收。
///
/// nativeapi 使用 Dart Finalizer，热重启时不保证执行；原生句柄表和主窗口
/// 则会继续存活。登记数据也必须放在原生内存中，不能只保存在 Dart 单例里。
class WindowsTrayResources {
  static const _propertyName = 'BangumiToday.DesktopTrayResources.v1';

  HWND? _window;
  final _entries = <int, List<int>>{};

  /// 在启动新的消息泵前注销旧回调并释放上一轮的资源。
  Future<void> recover() async {
    _window = HWND(Pointer.fromAddress(await windowManager.getId()));
    dispose();
  }

  void rememberMenu(Menu menu) =>
      _remember(_TrayResourceType.menu, menu.nativeHandle);

  void rememberMenuItem(MenuItem item, {ListenerId listener = 0}) =>
      _remember(_TrayResourceType.menuItem, item.nativeHandle, listener);

  void rememberTrayIcon(TrayIcon tray, {ListenerId listener = 0}) =>
      _remember(_TrayResourceType.trayIcon, tray.nativeHandle, listener);

  void rememberImage(Image image) =>
      _remember(_TrayResourceType.image, image.nativeHandle);

  void _remember(_TrayResourceType type, int handle, [int listener = 0]) {
    var window = _window!;
    _entries[handle] = [type.index, handle, listener];
    var snapshot = jsonEncode(
      _entries.values.toList(),
    ).toNativeUtf16(allocator: calloc);
    using((arena) {
      var name = PCWSTR(_propertyName.toNativeUtf16(allocator: arena));
      var previous = GetProp(window, name);
      var result = SetProp(window, name, HANDLE(snapshot.cast()));
      if (!result.value) {
        calloc.free(snapshot);
        throw StateError('登记系统托盘资源失败: ${result.error}');
      }
      if (previous.address != 0) calloc.free(previous);
    });
  }

  /// 注销残留监听器并回收资源，同时移除窗口属性及其原生内存。
  ///
  /// nativeapi 的句柄带有代次，重复释放已失效句柄是空操作，因此也适用于
  /// 正常退出及部分初始化失败后的兜底清理。
  void dispose() {
    var window = _window;
    if (window == null) return;
    var snapshot = using((arena) {
      var name = PCWSTR(_propertyName.toNativeUtf16(allocator: arena));
      return RemoveProp(window, name).value.cast<Utf16>();
    });
    _entries.clear();
    if (snapshot == nullptr) return;
    List<dynamic> entries;
    try {
      entries = jsonDecode(snapshot.toDartString()) as List<dynamic>;
    } finally {
      calloc.free(snapshot);
    }
    // 与分配顺序相反：先移除托盘，再回收它引用的菜单及菜单项。
    for (var value in entries.reversed) {
      var entry = (value as List<dynamic>).cast<int>();
      var handle = entry[1];
      var listener = entry[2];
      switch (_TrayResourceType.values[entry[0]]) {
        case _TrayResourceType.menu:
          Menu.borrowed(handle).dispose();
        case _TrayResourceType.menuItem:
          var item = MenuItem.borrowed(handle);
          if (listener != 0) item.removeListener(listener);
          item.dispose();
        case _TrayResourceType.trayIcon:
          var tray = TrayIcon.borrowed(handle);
          if (listener != 0) tray.removeListener(listener);
          tray.dispose();
        case _TrayResourceType.image:
          Image.borrowed(handle).dispose();
      }
    }
  }
}
