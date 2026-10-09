// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/bt_buttons.dart';

Future<Color?> showAccentColorDialog(
  BuildContext context, {
  required Color initialColor,
}) => showDialog<Color>(
  context: context,
  barrierDismissible: true,
  builder: (_) => _AccentColorDialog(initialColor: initialColor),
);

enum _ColorInputMode { rgb, hsv }

class _AccentColorDialog extends StatefulWidget {
  const _AccentColorDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_AccentColorDialog> createState() => _AccentColorDialogState();
}

class _AccentColorDialogState extends State<_AccentColorDialog> {
  final _hexController = TextEditingController();
  final _channelControllers = List.generate(3, (_) => TextEditingController());
  late Color _color;
  late HSVColor _hsv;
  var _mode = _ColorInputMode.rgb;
  var _inputValid = true;
  var _pickerRevision = 0;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor.withValues(alpha: 1);
    _hsv = HSVColor.fromColor(_color);
    _syncControllers();
  }

  @override
  void dispose() {
    _hexController.dispose();
    for (var controller in _channelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers({TextEditingController? except}) {
    var rgb = _color.toARGB32() & 0xFFFFFF;
    var hex = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    if (_hexController != except && _hexController.text != hex) {
      _hexController.text = hex;
    }
    var values = _mode == _ColorInputMode.rgb
        ? [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF]
        : [_hsv.hue, _hsv.saturation * 100, _hsv.value * 100];
    for (var i = 0; i < _channelControllers.length; i++) {
      var text = values[i].toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
      var controller = _channelControllers[i];
      if (controller != except && controller.text != text) {
        controller.text = text;
      }
    }
  }

  void _updateColor(
    Color color, {
    TextEditingController? source,
    HSVColor? hsv,
  }) {
    setState(() {
      _color = color.withValues(alpha: 1);
      _hsv = hsv ?? HSVColor.fromColor(_color);
      _inputValid = true;
      // ColorPicker 的 didUpdateWidget 不会同步内部色盘状态。
      // 仅在文本编辑时重新创建色盘，拖动时保持原实例和手势。
      if (source != null) _pickerRevision++;
      _syncControllers(except: source);
    });
  }

  void _onHexChanged(String text) {
    var hex = text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      setState(() => _inputValid = false);
      return;
    }
    _updateColor(
      Color(0xFF000000 | int.parse(hex, radix: 16)),
      source: _hexController,
    );
  }

  void _onChannelChanged(TextEditingController source) {
    var values = <double>[];
    var rgb = _mode == _ColorInputMode.rgb;
    var limits = rgb ? [255, 255, 255] : [360, 100, 100];
    for (var i = 0; i < _channelControllers.length; i++) {
      var text = _channelControllers[i].text.trim();
      var value = rgb ? int.tryParse(text)?.toDouble() : double.tryParse(text);
      if (value == null || !value.isFinite || value < 0 || value > limits[i]) {
        setState(() => _inputValid = false);
        return;
      }
      values.add(value);
    }
    if (rgb) {
      _updateColor(
        Color.fromARGB(
          255,
          values[0].toInt(),
          values[1].toInt(),
          values[2].toInt(),
        ),
        source: source,
      );
    } else {
      var hsv = HSVColor.fromAHSV(
        1,
        values[0],
        values[1] / 100,
        values[2] / 100,
      );
      _updateColor(hsv.toColor(), source: source, hsv: hsv);
    }
  }

  @override
  Widget build(BuildContext context) {
    var labels = _mode == _ColorInputMode.rgb
        ? ['R', 'G', 'B']
        : ['H (°)', 'S (%)', 'V (%)'];
    return ContentDialog(
      title: const Text('自定义主题色'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColorPicker(
              key: ValueKey(_pickerRevision),
              color: _color,
              onChanged: _updateColor,
              colorSpectrumShape: ColorSpectrumShape.box,
              isAlphaEnabled: false,
              isHexInputVisible: false,
              isColorChannelTextInputVisible: false,
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'HEX',
              child: TextBox(
                controller: _hexController,
                placeholder: '#RRGGBB',
                onChanged: _onHexChanged,
              ),
            ),
            const SizedBox(height: 12),
            BTSegmentedControl(
              selectedIndex: _mode.index,
              options: const ['RGB', 'HSV'],
              onChanged: (index) {
                setState(() {
                  _mode = _ColorInputMode.values[index];
                  _inputValid = true;
                  _syncControllers();
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _channelControllers.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: InfoLabel(
                      label: labels[i],
                      child: TextBox(
                        controller: _channelControllers[i],
                        onChanged: (_) =>
                            _onChannelChanged(_channelControllers[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!_inputValid) ...[
              const SizedBox(height: 8),
              Text(
                _mode == _ColorInputMode.rgb
                    ? '请输入6位HEX颜色，或0–255的RGB整数'
                    : '请输入6位HEX颜色；H为0–360，S/V为0–100',
                style: BTTypography.caption(
                  context,
                ).copyWith(color: BTColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _inputValid
              ? () => Navigator.of(context).pop(_color)
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
