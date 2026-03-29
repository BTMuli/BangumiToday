import 'package:fluent_ui/fluent_ui.dart';

class BTSplashScreen extends StatelessWidget {
  const BTSplashScreen({super.key});

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
                const ProgressRing(),
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
                const Text(
                  '正在加载...',
                  style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
