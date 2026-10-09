part of 'playback_page.dart';

/// Shared by the empty stage and both windowed/fullscreen video controls.
class _PlaybackLoadingIndicator extends StatelessWidget {
  const _PlaybackLoadingIndicator({
    required this.message,
    this.filePath,
    this.onMaterial = false,
  });

  final String message;
  final String? filePath;

  /// 空态直接铺在窗口材料上，卡片用材料色并跟随主题；视频上方保持纯黑卡片，
  /// 亮画面下文字仍然清楚。
  final bool onMaterial;

  @override
  Widget build(BuildContext context) {
    var surface = onMaterial
        ? FluentTheme.of(context).micaBackgroundColor
        : const Color(0xCC000000);
    var foreground = onMaterial ? BTColors.textPrimary(context) : Colors.white;
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BTRadius.mediumBR,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 32,
                    child: material.CircularProgressIndicator(
                      color: foreground,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: foreground, fontSize: 14),
                  ),
                  if (filePath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      path.basename(filePath!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
