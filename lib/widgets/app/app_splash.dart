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
                const SizedBox(height: 24),
                const Text(
                  'BangumiToday',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('正在加载...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
