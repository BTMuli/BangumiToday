// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

// Project imports:
import 'package:bangumi_today/core/services/playback_audio_controller.dart';
import 'package:bangumi_today/core/services/playback_window_data_host.dart';
import 'package:bangumi_today/core/services/playback_window_protocol.dart';
import 'package:bangumi_today/data/repositories/playback_window_remote.dart';
import 'package:bangumi_today/domain/repositories/playback_cover.dart';
import 'package:bangumi_today/domain/repositories/playback_history.dart';
import 'package:bangumi_today/domain/repositories/playback_library.dart';
import 'package:bangumi_today/domain/repositories/playback_settings.dart';
import 'package:bangumi_today/domain/repositories/playback_subjects.dart';
import 'package:bangumi_today/models/playback/playback_audio_selection.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';

const _english = AudioTrack('1', null, 'eng', isDefault: true);
const _japanese = AudioTrack('2', null, 'jpn');
const _tracks = [_english, _japanese];

class _Settings extends PlaybackSettingsStore {
  final values = <String, String>{};
  bool failWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('write failed');
    values[key] = value;
  }
}

class _Player extends Fake implements Player {
  @override
  PlayerState state = const PlayerState();
  final selected = <String>[];

  void media(List<AudioTrack> tracks, {AudioTrack? selected}) {
    state = PlayerState(
      tracks: Tracks(audio: [AudioTrack.auto(), AudioTrack.no(), ...tracks]),
      track: Track(audio: selected ?? AudioTrack.auto()),
    );
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    selected.add(track.id);
    state = state.copyWith(track: state.track.copyWith(audio: track));
  }
}

class _UnusedPlaybackData extends Fake
    implements
        PlaybackLibrary,
        PlaybackHistoryStore,
        PlaybackSubjectResolver,
        PlaybackCoverResolver {}

RemotePlaybackSettings _remoteSettings(PlaybackSettingsStore settings) {
  const identity = PlaybackWindowIdentity('audio-selection-test');
  var unused = _UnusedPlaybackData();
  var host = PlaybackWindowDataHost(
    identity: identity,
    library: unused,
    history: unused,
    settings: settings,
    subjects: unused,
    cover: unused,
    onCoverResolved: () {},
    onHistoryChanged: () {},
  );
  addTearDown(host.close);
  var sequence = 0;
  return RemotePlaybackSettings((method, body) {
    return host.handle(method, identity.request(++sequence, body));
  });
}

PlaybackAudioController _controller(
  PlaybackSettingsStore settings,
  _Player player,
) {
  var controller = PlaybackAudioController(
    settingsStore: settings,
    readPlayer: () => player,
    readSession: () => (
      id: player.state.hashCode.toString(),
      item: const PlaybackItem(filePath: 'show/01.mkv', title: '01'),
      completed: false,
    ),
    isClosed: () => false,
    serial: (action) => action(),
    onDiagnostic: (_) {},
    onChanged: () {},
  );
  addTearDown(controller.releasePlayer);
  return controller;
}

void main() {
  test('截图中的英语默认轨不能盖过日语，忽略自动和关闭占位轨', () {
    expect(
      preferredPlaybackAudio([AudioTrack.auto(), AudioTrack.no(), ..._tracks]),
      _japanese,
    );
    expect(
      preferredPlaybackAudio([AudioTrack.auto(), AudioTrack.no()]),
      isNull,
    );
  });

  test('识别语言别名、地区码、标题及日语原文', () {
    for (var language in ['ja', 'jp', 'JPN', 'ja_JP', '日本語']) {
      expect(
        preferredPlaybackAudio([_english, AudioTrack('3', null, language)])?.id,
        '3',
      );
    }
    for (var title in ['Japanese FLAC 2.0', '日语原声', '日本語']) {
      expect(
        preferredPlaybackAudio([_english, AudioTrack('3', title, 'und')])?.id,
        '3',
      );
    }
    for (var language in ['chi', 'zho', 'cmn', 'zh_CN', 'Chinese', '普通话']) {
      expect(
        preferredPlaybackAudio([_english, AudioTrack('3', null, language)])?.id,
        '3',
      );
    }
  });

  test('日语缺席时优先中文、英语，其他语言保留容器默认和稳定顺序', () {
    const chinese = AudioTrack('3', null, 'zh-Hans');
    const french = AudioTrack('4', null, 'fra', isDefault: true);
    const german = AudioTrack('5', null, 'deu');
    expect(preferredPlaybackAudio([french, _english, chinese]), chinese);
    expect(preferredPlaybackAudio([french, _english]), _english);
    expect(preferredPlaybackAudio([german, french]), french);
    expect(
      preferredPlaybackAudio([german, const AudioTrack('6', null, null)]),
      german,
    );
  });

  test('自动选择避开评论轨，同语言内优先容器默认轨', () {
    const commentary = AudioTrack(
      '3',
      'Audio Commentary',
      'jpn',
      isDefault: true,
    );
    const japaneseDefault = AudioTrack('4', '本篇', 'ja', isDefault: true);
    expect(preferredPlaybackAudio([commentary, _english]), _english);
    expect(preferredPlaybackAudio([commentary, _japanese]), _japanese);
    expect(
      preferredPlaybackAudio([_japanese, japaneseDefault]),
      japaneseDefault,
    );
    expect(preferredPlaybackAudio([commentary]), commentary);
  });

  test('手动选择跨集跟随语言而不是原编号，缺轨时回退但不覆盖偏好', () {
    var preference = PlaybackAudioSelection.fromTrack(_english, _tracks);
    const nextEnglish = AudioTrack('9', null, 'en');
    const nextJapanese = AudioTrack('1', null, 'ja', isDefault: true);
    expect(preference.select([nextJapanese, nextEnglish]), nextEnglish);
    expect(preference.select([nextJapanese]), nextJapanese);
    expect(preference.select([nextJapanese, nextEnglish]), nextEnglish);
    expect(preference.select([]), isNull);
  });

  test('同语言多音轨按标题、编码和声道恢复，不被重排或默认标记覆盖', () {
    const original = AudioTrack(
      '2',
      'Original',
      'jpn',
      codec: 'flac',
      channelscount: 6,
    );
    const stereo = AudioTrack(
      '1',
      'Original',
      'jpn',
      codec: 'aac',
      channelscount: 2,
      isDefault: true,
    );
    var preference = PlaybackAudioSelection.fromTrack(original, [
      stereo,
      original,
    ]);
    const nextSurround = AudioTrack(
      '8',
      'Original',
      'ja',
      codec: 'flac',
      channelscount: 6,
    );
    expect(preference.select([nextSurround, stereo]), nextSurround);
    const nextStereo = AudioTrack(
      '9',
      'Original',
      'ja',
      codec: 'aac',
      channelscount: 2,
      isDefault: true,
    );
    const retitled = AudioTrack(
      '7',
      'Episode 02',
      'ja',
      codec: 'flac',
      channelscount: 6,
    );
    // Exact title takes precedence; without it, the remembered mix wins.
    expect(preference.select([nextStereo, retitled]), nextStereo);
    expect(
      preference.select(
        [stereo, retitled].map(
          (track) => AudioTrack(
            track.id,
            'Episode 02',
            track.language,
            codec: track.codec,
            channelscount: track.channelscount,
          ),
        ),
      ),
      retitled,
    );
  });

  test('手动评论轨保持评论用途，缺失时不能把评论偏好套到普通音轨', () {
    const commentary = AudioTrack('3', 'Cast Commentary', 'jpn');
    var preference = PlaybackAudioSelection.fromTrack(commentary, [
      _japanese,
      commentary,
    ]);
    const next = AudioTrack('5', '第 2 集 解说', 'ja');
    expect(preference.select([_japanese, next]), next);
    expect(preference.select([_english, _japanese]), _japanese);
    expect(preference.select([_japanese, next]), next);
  });

  test('缺少语言和描述的轨道用同类顺序恢复，新增其他语言不影响顺序', () {
    const first = AudioTrack('1', null, null);
    const second = AudioTrack('2', null, null);
    var preference = PlaybackAudioSelection.fromTrack(second, [first, second]);
    const nextFirst = AudioTrack('4', null, 'und');
    const nextSecond = AudioTrack('6', null, null);
    expect(preference.select([_japanese, nextFirst, nextSecond]), nextSecond);
  });

  test('三种模式持久化，损坏或类型错误的配置回到自动选择', () {
    var manual = PlaybackAudioSelection.fromTrack(_english, _tracks);
    var restored = PlaybackAudioSelection.parse(manual.encode());
    expect(restored.automatic, isFalse);
    expect(restored.select(_tracks), _english);
    var disabled = PlaybackAudioSelection.fromTrack(AudioTrack.no(), _tracks);
    expect(
      PlaybackAudioSelection.parse(disabled.encode()).select(_tracks)?.id,
      'no',
    );
    var automatic = PlaybackAudioSelection.fromTrack(
      AudioTrack.auto(),
      _tracks,
    );
    expect(PlaybackAudioSelection.parse(automatic.encode()).automatic, isTrue);
    for (var value in [
      null,
      '',
      '{broken',
      '[]',
      '{"mode":"manual"}',
      '{"mode":"manual","language":1}',
    ]) {
      expect(PlaybackAudioSelection.parse(value).automatic, isTrue);
    }
  });

  test('音轨标签本地化，描述和评论信息保留', () {
    expect(playbackAudioLabel(_japanese), (title: '日语', description: null));
    expect(playbackAudioLabel(const AudioTrack('3', 'Japanese', 'jpn')), (
      title: '日语',
      description: null,
    ));
    expect(
      playbackAudioLabel(const AudioTrack('3', 'Japanese Commentary', 'ja')),
      (title: '日语', description: 'Japanese Commentary'),
    );
    expect(playbackAudioLabel(const AudioTrack('4', null, 'und')), (
      title: '轨道 4',
      description: null,
    ));
  });

  test('独立播放器窗口保存并恢复偏好，切集和播放器重建后继续选择手动语言', () async {
    var settings = _remoteSettings(_Settings());
    var player = _Player()..media(_tracks, selected: _japanese);
    var controller = _controller(settings, player);
    await controller.loadPreferences();
    await controller.setAudioTrack(_english);
    expect(controller.automaticTracks, isFalse);
    expect(player.state.track.audio, _english);
    controller.releasePlayer();

    const nextEnglish = AudioTrack('5', null, 'en');
    const nextJapanese = AudioTrack('1', null, 'ja', isDefault: true);
    await controller.prepareMedia();
    expect(player.state.track.audio.id, 'auto');
    player.media([nextJapanese, nextEnglish], selected: nextJapanese);
    await controller.selectTrack();
    expect(player.state.track.audio, nextEnglish);
    controller.releasePlayer();

    var recreatedPlayer = _Player()..media(_tracks, selected: _japanese);
    var recreated = _controller(settings, recreatedPlayer);
    await recreated.loadPreferences();
    await recreated.selectTrack();
    expect(recreatedPlayer.state.track.audio, _english);
    recreated.releasePlayer();
  });

  test('音轨延迟到达会重新匹配，恢复自动后不再沿用手动选择', () async {
    var settings = _Settings();
    var player = _Player()..media(_tracks, selected: _japanese);
    var controller = _controller(settings, player);
    await controller.setAudioTrack(_english);
    controller.releasePlayer();
    player.media([]);
    await controller.selectTrack();
    expect(player.state.track.audio.id, 'auto');
    player.media([_japanese], selected: _japanese);
    await controller.selectTrack();
    player.media(_tracks, selected: _japanese);
    await controller.selectTrack();
    expect(player.state.track.audio, _english);
    controller.releasePlayer();
    await controller.setAudioTrack(AudioTrack.auto());
    expect(controller.automaticTracks, isTrue);
    expect(player.state.track.audio, _japanese);
    controller.releasePlayer();
    var selectedCount = player.selected.length;
    await controller.selectTrack();
    expect(player.selected.length, selectedCount);
  });

  test('关闭音轨跨集和重建保持静音，保存失败不改变当前选择', () async {
    var settings = _Settings();
    var player = _Player()..media(_tracks, selected: _japanese);
    var controller = _controller(settings, player);
    settings.failWrite = true;
    await expectLater(controller.setAudioTrack(_english), throwsStateError);
    expect(controller.automaticTracks, isTrue);
    expect(player.state.track.audio, _japanese);
    settings.failWrite = false;
    await controller.setAudioTrack(AudioTrack.no());
    expect(player.state.track.audio.id, 'no');
    controller.releasePlayer();
    var restored = _controller(settings, player);
    await restored.loadPreferences();
    await restored.prepareMedia();
    expect(player.state.track.audio.id, 'no');
    player.media(_tracks);
    await restored.selectTrack();
    expect(player.state.track.audio.id, 'no');
    restored.releasePlayer();
  });
}
