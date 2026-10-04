part of 'playback_page.dart';

enum _PlaybackCommand {
  toggle,
  play,
  pause,
  back5,
  forward5,
  back10,
  forward10,
  volumeUp,
  volumeDown,
  mute,
  slower,
  faster,
  toggleRate,
  previous,
  next,
  fullscreen,
  screenshot,
  escape,
  info,
  help,
  scaleHalf,
  scaleOriginal,
  scaleOneHalf,
}

class _PlaybackShortcut {
  const _PlaybackShortcut(
    this.command,
    this.label,
    this.description,
    this.activators,
  );

  final _PlaybackCommand command;
  final String label;
  final String description;
  final List<ShortcutActivator> activators;
}

// The controls and help panel use this same list, including repeat behavior.
const _playbackShortcuts = [
  _PlaybackShortcut(_PlaybackCommand.toggle, 'Space / K', '播放 / 暂停', [
    SingleActivator(LogicalKeyboardKey.space, includeRepeats: false),
    SingleActivator(LogicalKeyboardKey.keyK, includeRepeats: false),
    SingleActivator(LogicalKeyboardKey.mediaPlayPause, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.back5, '←', '后退 5 秒', [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
  ]),
  _PlaybackShortcut(_PlaybackCommand.forward5, '→', '前进 5 秒', [
    SingleActivator(LogicalKeyboardKey.arrowRight),
  ]),
  _PlaybackShortcut(_PlaybackCommand.back10, 'J', '后退 10 秒', [
    SingleActivator(LogicalKeyboardKey.keyJ),
  ]),
  _PlaybackShortcut(_PlaybackCommand.forward10, 'L', '前进 10 秒', [
    SingleActivator(LogicalKeyboardKey.keyL),
  ]),
  _PlaybackShortcut(_PlaybackCommand.volumeUp, '↑', '音量增加 5%', [
    SingleActivator(LogicalKeyboardKey.arrowUp),
  ]),
  _PlaybackShortcut(_PlaybackCommand.volumeDown, '↓', '音量减少 5%', [
    SingleActivator(LogicalKeyboardKey.arrowDown),
  ]),
  _PlaybackShortcut(_PlaybackCommand.mute, 'M', '静音 / 恢复音量', [
    SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.toggleRate, 'Z', '1× / 记忆倍速切换', [
    SingleActivator(LogicalKeyboardKey.keyZ, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.slower, 'X', '播放速度减少 0.1×', [
    SingleActivator(LogicalKeyboardKey.keyX),
  ]),
  _PlaybackShortcut(_PlaybackCommand.faster, 'C', '播放速度增加 0.1×', [
    SingleActivator(LogicalKeyboardKey.keyC),
  ]),
  _PlaybackShortcut(_PlaybackCommand.previous, 'Page Up', '上一个视频', [
    SingleActivator(LogicalKeyboardKey.pageUp, includeRepeats: false),
    SingleActivator(
      LogicalKeyboardKey.mediaTrackPrevious,
      includeRepeats: false,
    ),
  ]),
  _PlaybackShortcut(_PlaybackCommand.next, 'Page Down', '下一个视频', [
    SingleActivator(LogicalKeyboardKey.pageDown, includeRepeats: false),
    SingleActivator(LogicalKeyboardKey.mediaTrackNext, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.fullscreen, 'F / Enter', '进入 / 退出全屏', [
    SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false),
    SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.scaleHalf, '1', '窗口尺寸 · 0.5 倍', [
    SingleActivator(LogicalKeyboardKey.digit1),
    SingleActivator(LogicalKeyboardKey.numpad1),
  ]),
  _PlaybackShortcut(_PlaybackCommand.scaleOriginal, '2', '窗口尺寸 · 原始像素', [
    SingleActivator(LogicalKeyboardKey.digit2),
    SingleActivator(LogicalKeyboardKey.numpad2),
  ]),
  _PlaybackShortcut(_PlaybackCommand.scaleOneHalf, '3', '窗口尺寸 · 1.5 倍', [
    SingleActivator(LogicalKeyboardKey.digit3),
    SingleActivator(LogicalKeyboardKey.numpad3),
  ]),
  _PlaybackShortcut(_PlaybackCommand.screenshot, 'S', '截屏并复制到剪贴板（含字幕）', [
    SingleActivator(LogicalKeyboardKey.keyS, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.escape, 'Esc', '关闭快捷键面板 / 退出全屏', [
    SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.info, 'Tab', '显示 / 隐藏视频信息', [
    SingleActivator(LogicalKeyboardKey.tab, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.help, 'F1', '查看 / 关闭快捷键面板', [
    SingleActivator(LogicalKeyboardKey.f1, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.play, '', '', [
    SingleActivator(LogicalKeyboardKey.mediaPlay, includeRepeats: false),
  ]),
  _PlaybackShortcut(_PlaybackCommand.pause, '', '', [
    SingleActivator(LogicalKeyboardKey.mediaPause, includeRepeats: false),
  ]),
];

class _PlaybackFeedback {
  const _PlaybackFeedback(
    this.id,
    this.text,
    this.icon, {
    this.detail,
    this.level,
  });

  final int id;
  final String text;
  final IconData icon;
  final String? detail;
  final double? level;
}

/// Shared across the windowed and fullscreen video controls.
class _PlaybackOverlayController extends ChangeNotifier {
  Timer? _timer;
  bool _disposed = false;
  int _sequence = 0;
  bool showInfo = false;
  bool showHelp = false;
  double audibleVolume = 100;
  _PlaybackFeedback? feedback;
  final menuClosers = <bool Function()>{};

  bool closeMenus() {
    var closed = false;
    for (var close in List<bool Function()>.of(menuClosers)) {
      closed = close() || closed;
    }
    return closed;
  }

  void show(String text, IconData icon, {String? detail, double? level}) {
    if (_disposed) return;
    _timer?.cancel();
    feedback = _PlaybackFeedback(
      ++_sequence,
      text,
      icon,
      detail: detail,
      level: level?.clamp(0.0, 1.0),
    );
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      feedback = null;
      notifyListeners();
    });
  }

  void toggleInfo() {
    if (_disposed) return;
    showInfo = !showInfo;
    notifyListeners();
  }

  void toggleHelp() {
    if (_disposed) return;
    showHelp = !showHelp;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    menuClosers.clear();
    super.dispose();
  }
}

class _PlaybackFeedbackView extends StatelessWidget {
  const _PlaybackFeedbackView({required this.feedback});

  final _PlaybackFeedback? feedback;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      child: feedback == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(feedback!.id),
              constraints: const BoxConstraints(maxWidth: 280),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(feedback!.icon, size: 32, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    feedback!.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (feedback!.detail != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      feedback!.detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: material.Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (feedback!.level != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 140,
                      child: material.LinearProgressIndicator(
                        value: feedback!.level,
                        minHeight: 3,
                        backgroundColor: material.Colors.white24,
                        color: FluentTheme.of(context).accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}

class _PlaybackShortcutHelp extends StatelessWidget {
  const _PlaybackShortcutHelp({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.3),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 80),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 350,
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 18),
                decoration: BoxDecoration(
                  color: const Color(0xF01B1B1F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: material.Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          material.Icons.keyboard_alt_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '快捷键',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        material.IconButton(
                          tooltip: '关闭（F1 / Esc）',
                          onPressed: onClose,
                          color: material.Colors.white70,
                          icon: const Icon(
                            material.Icons.close_rounded,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var shortcut in _playbackShortcuts)
                              if (shortcut.label.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          shortcut.label,
                                          style: const TextStyle(
                                            color: Color(0xFF6DD8CF),
                                            fontFamily: 'Consolas',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          shortcut.description,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '点击视频后使用快捷键 · '
                      '右键可打开操作菜单',
                      style: TextStyle(
                        color: material.Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Z 会记住切回 1× 前的倍速，重启后仍可恢复',
                      style: TextStyle(
                        color: material.Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _playbackTime(Duration value, {bool milliseconds = false}) {
  var hours = value.inHours;
  var minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  var seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  var time = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  var millis = value.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return milliseconds ? '$time.$millis' : time;
}
