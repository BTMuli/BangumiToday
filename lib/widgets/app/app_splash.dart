import 'package:fluent_ui/fluent_ui.dart';

class BTSplashScreen extends StatelessWidget {
  final String? errorMessage;

  /// 启动阶段使用的主题模式，保证加载页背景与文本跟随应用主题
  final ThemeMode themeMode;

  const BTSplashScreen({
    super.key,
    this.errorMessage,
    this.themeMode = ThemeMode.system,
  });

  /// 是否为深色主题
  bool get isDark {
    return switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData.light(),
      darkTheme: FluentThemeData.dark(),
      themeMode: themeMode,
      home: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF3F3F3),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 96, height: 96),
                const SizedBox(height: 16),
                Text(
                  'BangumiToday',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFF3F3F3)
                        : const Color(0xFF333333),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage == null)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    else
                      Icon(
                        FluentIcons.error_badge,
                        size: 20,
                        color: Colors.red,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      errorMessage == null ? '正在加载...' : '初始化失败，请重启应用后重试',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? const Color(0xFF9D9D9D)
                            : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SelectableText(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFB0B0B0)
                            : const Color(0xFF777777),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
