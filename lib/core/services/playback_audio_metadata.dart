// Dart imports:
import 'dart:io';
import 'dart:typed_data';

/// Reads only container headers. No extra decoder/process, whole-file read or
/// assumption that a 32-bit decoder container means 32 encoded bits.
class PlaybackAudioMetadata {
  String? _path;
  Future<Map<int, int>>? _depths;

  void clear() {
    _path = null;
    _depths = null;
  }

  Future<int?> bitDepth(
    String path, {
    required String codec,
    int? track,
  }) async {
    if (!codec.startsWith('pcm_') && !const {'flac', 'alac'}.contains(codec)) {
      return null;
    }
    if (_path != path) {
      _path = path;
      _depths = _read(path);
    }
    var depths = await _depths!;
    return depths[track] ?? depths[-1];
  }

  static Future<Map<int, int>> _read(String path) async {
    RandomAccessFile? file;
    try {
      file = await File(path).open();
      var length = await file.length();
      var prefix = await file.read(42);
      if (_tag(prefix, 0) == 'fLaC') {
        var bits = _flacBits(prefix);
        return {-1: ?bits};
      }
      if (const {'RIFF', 'RF64'}.contains(_tag(prefix, 0)) &&
          _tag(prefix, 8) == 'WAVE') {
        return await _wav(file, length);
      }
      if (prefix.length >= 4 && _uint(prefix, 0, 4) == 0x1a45dfa3) {
        return await _matroska(file, length);
      }
      return await _mp4(file, length);
    } on FileSystemException {
      return const {};
    } on FormatException {
      return const {};
    } on RangeError {
      return const {};
    } finally {
      await file?.close();
    }
  }

  static Future<Map<int, int>> _wav(RandomAccessFile file, int length) async {
    var position = 12;
    for (var count = 0; count < 128 && position + 8 <= length; count++) {
      await file.setPosition(position);
      var header = await file.read(8);
      var size = ByteData.sublistView(header).getUint32(4, Endian.little);
      if (position + 8 + size > length) return const {};
      if (_tag(header, 0) == 'fmt ' && size >= 16) {
        var data = ByteData.sublistView(await file.read(size < 40 ? size : 40));
        var tag = data.getUint16(0, Endian.little);
        var bits = data.getUint16(14, Endian.little);
        if (tag == 0xfffe && data.lengthInBytes >= 40) {
          tag = data.getUint32(24, Endian.little);
          var valid = data.getUint16(18, Endian.little);
          if (valid > 0 && valid <= bits) bits = valid;
        }
        return {if ((tag == 1 || tag == 3) && bits > 0 && bits <= 64) -1: bits};
      }
      position += 8 + size + (size & 1);
    }
    return const {};
  }

  static Future<Map<int, int>> _matroska(
    RandomAccessFile file,
    int length,
  ) async {
    var position = 0;
    int? segment;
    for (var count = 0; count < 256 && position < length; count++) {
      await file.setPosition(position);
      var header = await file.read(12);
      var element = _ebml(header, 0);
      var payload = position + element.start;
      var end = element.end == null ? length : position + element.end!;
      if (end > length || end <= position) return const {};
      if (element.id == 0x18538067) {
        segment = payload;
        position = payload;
        continue;
      }
      if (segment != null && element.id == 0x1654ae6b) {
        if (end - payload > 4 * 1024 * 1024) return const {};
        await file.setPosition(payload);
        return _matroskaDepths(await file.read(end - payload));
      }
      if (segment != null &&
          element.id == 0x114d9b74 &&
          end - payload <= 128 * 1024) {
        await file.setPosition(payload);
        var seekHead = await file.read(end - payload);
        int? tracksPosition;
        for (var seek in _ebmlChildren(seekHead)) {
          if (seek.id != 0x4dbb) continue;
          int? id;
          int? offset;
          for (var value in _ebmlChildren(_payload(seekHead, seek))) {
            var bytes = _payload(_payload(seekHead, seek), value);
            if (value.id == 0x53ab) id = _uint(bytes, 0, bytes.length);
            if (value.id == 0x53ac) offset = _uint(bytes, 0, bytes.length);
          }
          if (id == 0x1654ae6b && offset != null) {
            tracksPosition = segment + offset;
            break;
          }
        }
        if (tracksPosition != null) {
          position = tracksPosition;
          continue;
        }
      }
      if (element.end == null) return const {};
      position = end;
    }
    return const {};
  }

  static Map<int, int> _matroskaDepths(Uint8List data) {
    var result = <int, int>{};
    for (var entry in _ebmlChildren(data)) {
      if (entry.id != 0xae) continue;
      int? number;
      int? bits;
      String? codec;
      Uint8List? private;
      var track = _payload(data, entry);
      for (var field in _ebmlChildren(track)) {
        var value = _payload(track, field);
        switch (field.id) {
          case 0xd7:
            number = _uint(value, 0, value.length);
          case 0x86:
            codec = String.fromCharCodes(value);
          case 0x63a2:
            private = value;
          case 0xe1:
            for (var audio in _ebmlChildren(value)) {
              if (audio.id == 0x6264) {
                var depth = _payload(value, audio);
                bits = _uint(depth, 0, depth.length);
              }
            }
        }
      }
      if (codec == 'A_FLAC') bits = _flacBits(private ?? Uint8List(0)) ?? bits;
      if (codec == 'A_ALAC' && private != null && private.length >= 36) {
        bits = private[17];
      }
      if (number != null && bits != null && bits > 0 && bits <= 64) {
        result[number] = bits;
      }
    }
    return result;
  }

  static Future<Map<int, int>> _mp4(RandomAccessFile file, int length) async {
    var position = 0;
    for (var count = 0; count < 128 && position + 8 <= length; count++) {
      await file.setPosition(position);
      var header = await file.read(16);
      var size = _uint(header, 0, 4);
      var headerSize = size == 1 ? 16 : 8;
      if (size == 1) size = _uint(header, 8, 8);
      if (size == 0) size = length - position;
      if (size < headerSize || position + size > length) return const {};
      if (_tag(header, 4) == 'moov') {
        if (size > 4 * 1024 * 1024) return const {};
        await file.setPosition(position + headerSize);
        return _mp4Depths(await file.read(size - headerSize));
      }
      position += size;
    }
    return const {};
  }

  static Map<int, int> _mp4Depths(Uint8List data) {
    var result = <int, int>{};
    for (var trak in _boxes(data).where((value) => value.id == 'trak')) {
      var track = _payload(data, trak);
      int? id;
      int? bits;
      for (var child in _boxes(track)) {
        if (child.id == 'tkhd') {
          var header = _payload(track, child);
          id = _uint(header, header[0] == 1 ? 20 : 12, 4);
        }
        if (child.id == 'mdia') {
          var mdia = _payload(track, child);
          for (var minf in _boxes(mdia).where((value) => value.id == 'minf')) {
            var media = _payload(mdia, minf);
            for (var stbl in _boxes(
              media,
            ).where((value) => value.id == 'stbl')) {
              var table = _payload(media, stbl);
              for (var stsd in _boxes(
                table,
              ).where((value) => value.id == 'stsd')) {
                var descriptions = _payload(table, stsd);
                for (var entry in _boxes(descriptions, start: 8)) {
                  if (entry.id != 'alac') continue;
                  var audio = _payload(descriptions, entry);
                  var version = _uint(audio, 8, 2);
                  if (version > 1) continue;
                  for (var config in _boxes(
                    audio,
                    start: version == 1 ? 44 : 28,
                  )) {
                    var value = _payload(audio, config);
                    if (config.id == 'alac' && value.length >= 28) {
                      bits = value[9];
                    }
                  }
                }
              }
            }
          }
        }
      }
      if (id != null && bits != null && const {16, 20, 24, 32}.contains(bits)) {
        result[id] = bits;
      }
    }
    return result;
  }

  static int? _flacBits(Uint8List data) {
    var start = _tag(data, 0) == 'fLaC' ? 8 : 0;
    if (data.length < start + 34) return null;
    if (start == 8 && (data[4] & 0x7f) != 0) return null;
    return ((_uint(data, start + 10, 8) >> 36) & 31) + 1;
  }

  static String _tag(Uint8List data, int offset) => data.length < offset + 4
      ? ''
      : String.fromCharCodes(data.sublist(offset, offset + 4));

  static int _uint(Uint8List data, int offset, int size) {
    if (size < 0 || size > 8 || offset < 0 || offset + size > data.length) {
      throw const FormatException('Invalid audio header integer');
    }
    var result = 0;
    for (var index = offset; index < offset + size; index++) {
      result = (result << 8) | data[index];
    }
    return result;
  }

  static Uint8List _payload(Uint8List data, _AudioHeader header) =>
      Uint8List.sublistView(data, header.start, header.end);

  static _AudioHeader _ebml(Uint8List data, int offset) {
    int width(int byte, int maximum) {
      for (var count = 1; count <= maximum; count++) {
        if ((byte & (1 << (8 - count))) != 0) return count;
      }
      throw const FormatException('Invalid EBML header');
    }

    var idWidth = width(data[offset], 4);
    var id = _uint(data, offset, idWidth);
    var sizeOffset = offset + idWidth;
    var sizeWidth = width(data[sizeOffset], 8);
    var size =
        _uint(data, sizeOffset, sizeWidth) & ((1 << (7 * sizeWidth)) - 1);
    var start = sizeOffset + sizeWidth;
    return _AudioHeader(
      id,
      start,
      size == (1 << (7 * sizeWidth)) - 1 ? null : start + size,
    );
  }

  static Iterable<_AudioHeader> _ebmlChildren(Uint8List data) sync* {
    var position = 0;
    while (position < data.length) {
      var header = _ebml(data, position);
      if (header.end == null || header.end! > data.length) {
        throw const FormatException('Truncated EBML audio metadata');
      }
      yield header;
      position = header.end!;
    }
  }

  static Iterable<_AudioHeader> _boxes(Uint8List data, {int start = 0}) sync* {
    var position = start;
    while (position + 8 <= data.length) {
      var size = _uint(data, position, 4);
      var id = _tag(data, position + 4);
      var headerSize = size == 1 ? 16 : 8;
      if (size == 1) size = _uint(data, position + 8, 8);
      if (size == 0) size = data.length - position;
      if (size < headerSize || position + size > data.length) {
        throw const FormatException('Invalid MP4 audio metadata');
      }
      yield _AudioHeader(id, position + headerSize, position + size);
      position += size;
    }
  }
}

class _AudioHeader {
  const _AudioHeader(this.id, this.start, this.end);
  final Object id;
  final int start;
  final int? end;
}
