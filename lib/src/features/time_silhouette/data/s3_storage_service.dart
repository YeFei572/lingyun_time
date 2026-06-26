abstract class S3StorageService {
  Future<String> uploadFile({
    required String localPath,
    required String objectKey,
    required String mimeType,
  });
}

class MockS3StorageService implements S3StorageService {
  @override
  Future<String> uploadFile({
    required String localPath,
    required String objectKey,
    required String mimeType,
  }) async {
    return 's3://mock/$objectKey';
  }
}
