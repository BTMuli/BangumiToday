// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/services/playback_tensorrt_resources.dart';

void main() {
  var root = Directory('temp/tensorrt-engine-cache-regression').absolute;
  var createdRoot = false;
  late Directory engines;
  late PlaybackTensorRtResources resources;
  var engineName = '${List.filled(64, 'a').join()}.engine';

  setUpAll(() {
    if (!root.existsSync()) {
      root.createSync(recursive: true);
      createdRoot = true;
    }
  });
  tearDownAll(() async {
    if (createdRoot) await root.delete();
  });
  setUp(() async {
    var data = await root.createTemp('case-');
    addTearDown(() => data.delete(recursive: true));
    engines = await Directory(path.join(data.path, 'engines')).create();
    resources = PlaybackTensorRtResources(
      onChanged: () {},
      dataDirectory: data.path,
    );
    addTearDown(resources.dispose);
  });

  File file(String name) => File(path.join(engines.path, name));

  test('新增、更新和删除日志、使用标记及临时文件不使引擎失效', () async {
    await file(engineName).writeAsString('engine');
    await file('$engineName.meta').writeAsString('metadata');
    await resources.refreshEngineCache();
    var epoch = resources.engineEpoch;
    for (var suffix in ['.part-1-1.log', '.used', '.part', '.meta.part']) {
      var artifact = file('$engineName$suffix');
      await artifact.writeAsString('first');
      await resources.refreshEngineCache();
      await artifact.writeAsString('updated');
      await resources.refreshEngineCache();
      await artifact.delete();
      await resources.refreshEngineCache();
    }
    expect(resources.engineEpoch, epoch);
  });

  test('同名引擎内容或元数据变化使已准备记录失效', () async {
    var engine = file(engineName);
    var metadata = file('$engineName.meta');
    await engine.writeAsString('first');
    await metadata.writeAsString('first');
    await resources.refreshEngineCache();
    await engine.writeAsString('replacement engine');
    await resources.refreshEngineCache();
    expect(resources.engineEpoch, 1);
    await metadata.writeAsString('other');
    await metadata.setLastModified(DateTime.utc(2026));
    await resources.refreshEngineCache();
    expect(resources.engineEpoch, 2);
  });

  test('删除引擎及元数据仍使缓存失效，目录不存在也可恢复', () async {
    await file(engineName).writeAsString('engine');
    await file('$engineName.meta').writeAsString('metadata');
    await resources.refreshEngineCache();
    await file('$engineName.meta').delete();
    await resources.refreshEngineCache();
    expect(resources.engineEpoch, 1);
    await file(engineName).delete();
    await engines.delete();
    await resources.refreshEngineCache();
    expect(resources.engineEpoch, 2);
    await engines.create();
    await file(engineName).writeAsString('engine');
    await resources.refreshEngineCache();
    expect(resources.engineEpoch, 3);
  });
}
