// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:media_kit/media_kit.dart';

String _normalized(String? value) => (value ?? '').trim().toLowerCase();

String _audioLanguage(AudioTrack track) {
  var code = _normalized(track.language).replaceAll('_', '-').split('-').first;
  var language = switch (code) {
    'ja' ||
    'jp' ||
    'jpn' ||
    'japanese' ||
    '日语' ||
    '日語' ||
    '日文' ||
    '日本語' => 'ja',
    'zh' ||
    'chi' ||
    'zho' ||
    'cmn' ||
    'mandarin' ||
    'chinese' ||
    '中文' ||
    '国语' ||
    '普通话' ||
    '普通話' ||
    '國語' => 'zh',
    'yue' || 'cantonese' || '粤语' || '粵語' => 'yue',
    'en' || 'eng' || 'english' || '英语' || '英語' => 'en',
    'ko' || 'kor' || 'korean' => 'ko',
    '' || 'und' || 'unknown' || 'none' => '',
    _ => code,
  };
  if (language.isNotEmpty) return language;
  var title = _normalized(track.title);
  bool named(String pattern) => RegExp(pattern).hasMatch(title);
  bool word(String pattern) => named('(^|[^a-z0-9])($pattern)([^a-z0-9]|\$)');
  if (named('日[语語文]|日本語') || word('ja|jp|jpn|japanese')) return 'ja';
  if (named('粤[语語]|粵語') || word('yue|cantonese')) return 'yue';
  if (named('中文|国[语語]|國語|普通[话話]') || word('zh|chi|zho|cmn|chinese|mandarin')) {
    return 'zh';
  }
  if (named('英[语語文]') || word('en|eng|english')) return 'en';
  if (named('韩[语語]|韓語|한국어') || word('ko|kor|korean')) return 'ko';
  return '';
}

bool _commentary(String? title) => RegExp(
  r'commentary|解说|解說|评论|評論|讲评|講評|コメンタリー|解説|副音声|副音聲',
).hasMatch(_normalized(title));

bool _realTrack(AudioTrack track) => track.id != 'auto' && track.id != 'no';

int _audioPriority(AudioTrack track) => switch (_audioLanguage(track)) {
  'ja' => 0,
  'zh' || 'yue' => 1,
  'en' => 2,
  _ => 3,
};

/// Prefer dialogue, then Japanese/Chinese/English, then the container default.
/// Unrecognized languages still play; pseudo tracks never compete.
AudioTrack? preferredPlaybackAudio(Iterable<AudioTrack> tracks) {
  AudioTrack? selected;
  for (var track in tracks.where(_realTrack)) {
    if (selected == null ||
        (_commentary(selected.title) && !_commentary(track.title)) ||
        (_commentary(selected.title) == _commentary(track.title) &&
            (_audioPriority(track) < _audioPriority(selected) ||
                (_audioPriority(track) == _audioPriority(selected) &&
                    track.isDefault == true &&
                    selected.isDefault != true)))) {
      selected = track;
    }
  }
  return selected;
}

enum _AudioSelectionMode { automatic, disabled, manual }

/// Persist semantic identity, never a file-local track ID. A missing manual
/// match falls back for this file without overwriting the saved preference.
class PlaybackAudioSelection {
  const PlaybackAudioSelection.automatic() : this._();

  const PlaybackAudioSelection._({
    _AudioSelectionMode mode = _AudioSelectionMode.automatic,
    this.language = '',
    this.title = '',
    this.codec = '',
    this.channels,
    this.index = 0,
  }) : _mode = mode;

  static const settingKey = 'playbackAudioSelection';
  final _AudioSelectionMode _mode;
  final String language;
  final String title;
  final String codec;
  final int? channels;
  final int index;

  bool get automatic => _mode == _AudioSelectionMode.automatic;
  bool get disabled => _mode == _AudioSelectionMode.disabled;

  factory PlaybackAudioSelection.fromTrack(
    AudioTrack track,
    Iterable<AudioTrack> tracks,
  ) {
    if (track.id == 'auto') return const PlaybackAudioSelection.automatic();
    if (track.id == 'no') {
      return const PlaybackAudioSelection._(mode: _AudioSelectionMode.disabled);
    }
    var language = _audioLanguage(track);
    var candidates = tracks.where(
      (other) =>
          _realTrack(other) &&
          _audioLanguage(other) == language &&
          _commentary(other.title) == _commentary(track.title),
    );
    var index = candidates.toList().indexWhere((other) => other.id == track.id);
    return PlaybackAudioSelection._(
      mode: _AudioSelectionMode.manual,
      language: language,
      title: _normalized(track.title),
      codec: _normalized(track.codec),
      channels: track.channelscount ?? track.audiochannels,
      index: index < 0 ? 0 : index,
    );
  }

  factory PlaybackAudioSelection.parse(String? value) {
    if (value == null || value.isEmpty) {
      return const PlaybackAudioSelection.automatic();
    }
    try {
      var data = jsonDecode(value);
      if (data case {'mode': 'disabled'}) {
        return const PlaybackAudioSelection._(
          mode: _AudioSelectionMode.disabled,
        );
      }
      if (data case {
        'mode': 'manual',
        'language': String language,
        'title': String title,
        'codec': String codec,
        'channels': int? channels,
        'index': int index,
      } when index >= 0) {
        return PlaybackAudioSelection._(
          mode: _AudioSelectionMode.manual,
          language: language,
          title: title,
          codec: codec,
          channels: channels,
          index: index,
        );
      }
    } on FormatException {
      // Invalid local preferences should not prevent opening a video.
    }
    return const PlaybackAudioSelection.automatic();
  }

  String encode() => jsonEncode({
    'mode': _mode.name,
    if (_mode == _AudioSelectionMode.manual) ...{
      'language': language,
      'title': title,
      'codec': codec,
      'channels': channels,
      'index': index,
    },
  });

  AudioTrack? select(Iterable<AudioTrack> tracks) {
    if (disabled) return AudioTrack.no();
    if (automatic) return preferredPlaybackAudio(tracks);
    var candidates = tracks
        .where(
          (track) =>
              _realTrack(track) &&
              _audioLanguage(track) == language &&
              _commentary(track.title) == _commentary(title),
        )
        .toList();
    AudioTrack? selected;
    var best = -1;
    for (var i = 0; i < candidates.length; i++) {
      var track = candidates[i];
      // Title, codec and layout identify alternate dubs/mixes. Ordinal only
      // breaks ties between otherwise indistinguishable tracks in this tier.
      var score =
          (title.isNotEmpty && _normalized(track.title) == title ? 8 : 0) +
          (codec.isNotEmpty && _normalized(track.codec) == codec ? 4 : 0) +
          (channels != null &&
                  (track.channelscount ?? track.audiochannels) == channels
              ? 2
              : 0) +
          (i == index ? 1 : 0);
      if (score > best ||
          (score == best &&
              track.isDefault == true &&
              selected?.isDefault != true)) {
        selected = track;
        best = score;
      }
    }
    return selected ?? preferredPlaybackAudio(tracks);
  }
}

({String title, String? description}) playbackAudioLabel(AudioTrack track) {
  if (track.id == 'auto') return (title: '自动选择', description: null);
  if (track.id == 'no') return (title: '关闭', description: null);
  var language = _audioLanguage(track);
  var title = switch (language) {
    'ja' => '日语',
    'zh' => '中文',
    'yue' => '粤语',
    'en' => '英语',
    'ko' => '韩语',
    _ => language.isEmpty ? '轨道 ${track.id}' : language,
  };
  var name = (track.title ?? '').trim();
  // A bare language name carries no extra information after localization.
  var bareLanguage =
      name.isNotEmpty && _audioLanguage(AudioTrack('', null, name)) == language;
  return (
    title: title,
    description: name.isEmpty || bareLanguage ? null : name,
  );
}
