import 'package:fluent_ui/fluent_ui.dart';

class BTSplashScreen extends StatelessWidget {
  final String? errorMessage;

  const BTSplashScreen({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData.light(),
      darkTheme: FluentThemeData.dark(),
      home: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(color: Colors.grey[20]),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (errorMessage == null)
                  const ProgressRing()
                else
                  Icon(FluentIcons.error_badge, size: 40, color: Colors.red),
                const SizedBox(height: 32),
                const Text(
                  'BangumiToday',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage == null ? '正在加载...' : '初始化失败，请重启应用后重试',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SelectableText(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF777777),
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
