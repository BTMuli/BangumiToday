// Project imports:
import 'protocol.dart';

abstract interface class BtEngineGateway {
  BtEngineClientState get state;
  bool get isReady;
  List<BtTaskSnapshot> get tasks;
  Stream<BtEngineEvent> get events;
  Stream<List<BtTaskSnapshot>> get taskSnapshots;
  Stream<BtEngineClientState> get states;

  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  });

  Future<void> refreshTasks();
  Future<BtTaskDetails> taskDetails(String id);
  Future<List<int>> setFilePriorities(String id, Map<int, int> priorities);
  Future<Map<String, dynamic>> status();
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config);
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  });
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  });
  Future<BtTaskSnapshot> pause(String id);
  Future<BtTaskSnapshot> resume(String id);
  Future<BtTaskSnapshot> retry(String id);
  Future<BtTaskSnapshot> recheck(String id);
  Future<void> remove(String id, {bool deleteData = false});
  Future<void> shutdown();
}
