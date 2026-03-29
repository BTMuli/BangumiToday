import 'package:fluent_ui/fluent_ui.dart';

class BTSplashScreen extends StatelessWidget {
  const BTSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      home: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: Colors.grey[20],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ProgressRing(),
                const SizedBox(height: 24),
                Text(
                  'BangumiToday',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text(
                  '正在加载...',
                  style: FluentTheme.of(context).typography.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
