import '../../data/datasources/bangumi_remote_data_source.dart';
import '../../data/datasources/bangumi_remote_data_source_impl.dart';
import '../../data/repositories/bangumi_repository_impl.dart';
import '../../domain/repositories/bangumi_repository.dart';
import '../../request/bangumi/bangumi_api.dart';

class BTRepositoryProviders {
  static BTBangumiRepository? _bangumiRepository;
  static BTBangumiRemoteDataSource? _remoteDataSource;

  static BTBangumiRepository provideBangumiRepository() {
    return _bangumiRepository ??= BTBangumiRepositoryImpl(
      remoteDataSource: _provideRemoteDataSource(),
    );
  }

  static BTBangumiRemoteDataSource _provideRemoteDataSource() {
    return _remoteDataSource ??= BTBangumiRemoteDataSourceImpl(
      api: BtrBangumiApi(),
    );
  }

  static void reset() {
    _bangumiRepository = null;
    _remoteDataSource = null;
  }
}
