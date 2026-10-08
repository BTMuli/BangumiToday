part of 'playback_page.dart';

/// Shared by the empty stage and both windowed/fullscreen video controls.
class _PlaybackLoadingIndicator extends StatelessWidget {
  const _PlaybackLoadingIndicator({required this.message, this.filePath});

  final String message;
  final String? filePath;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 32,
                  child: material.CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (filePath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    path.basename(filePath!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
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
