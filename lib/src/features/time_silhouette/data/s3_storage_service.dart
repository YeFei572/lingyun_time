import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/s3_upload_config.dart';

class S3StorageService {
  S3StorageService(this.config);

  final S3UploadConfig config;

  Future<String> uploadFile({
    required String localPath,
    required String objectKey,
    required String mimeType,
  }) async {
    if (!config.isConfigured) {
      throw const S3UploadException('请先在设置页完成 S3 上传配置');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw const S3UploadException('本地文件不存在，无法上传');
    }

    final fileLength = await file.length();
    final payloadHash = (await sha256.bind(file.openRead()).first).toString();
    final uri = _buildObjectUri(objectKey);
    final headers = _buildSignedHeaders(
      uri: uri,
      payloadHash: payloadHash,
      mimeType: mimeType,
    );

    final client = HttpClient();
    try {
      final request = await client.putUrl(uri);
      headers.forEach(request.headers.set);
      request.contentLength = fileLength;
      await request.addStream(file.openRead());

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw S3UploadException(
          'S3 上传失败：HTTP ${response.statusCode}${responseBody.isEmpty ? '' : '，$responseBody'}',
        );
      }

      return _buildPublicUrl(objectKey, uri);
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildObjectUri(String objectKey) {
    final endpoint = Uri.parse(config.normalizedEndpoint);
    final endpointSegments = endpoint.pathSegments.where((e) => e.isNotEmpty).toList();
    final objectSegments = objectKey.split('/').where((e) => e.isNotEmpty).toList();

    if (config.usePathStyle || _requiresPathStyle(endpoint.host)) {
      return _buildUriWithoutQuery(
        source: endpoint,
        pathSegments: [...endpointSegments, config.bucket.trim(), ...objectSegments],
      );
    }

    return _buildUriWithoutQuery(
      source: endpoint,
      host: '${config.bucket.trim()}.${endpoint.host}',
      pathSegments: [...endpointSegments, ...objectSegments],
    );
  }

  bool _requiresPathStyle(String host) {
    final normalizedHost = host.toLowerCase();
    return normalizedHost == 's3.api.upyun.com';
  }

  Map<String, String> _buildSignedHeaders({
    required Uri uri,
    required String payloadHash,
    required String mimeType,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final host = _hostHeader(uri);
    final region = config.region.trim();
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalHeaders = [
      'content-type:$mimeType',
      'host:$host',
      'x-amz-content-sha256:$payloadHash',
      'x-amz-date:$amzDate',
      '',
    ].join('\n');

    // S3 协议要求签名内容严格按照规范排序和换行，任何空格差异都会导致签名失败。
    final canonicalRequest = [
      'PUT',
      _canonicalPath(uri),
      uri.query,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _deriveSigningKey(
      secretAccessKey: config.secretAccessKey.trim(),
      dateStamp: dateStamp,
      region: region,
    );
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();
    final authorization =
        'AWS4-HMAC-SHA256 Credential=${config.accessKeyId.trim()}/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    return {
      'Authorization': authorization,
      'Content-Type': mimeType,
      'Host': host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };
  }

  List<int> _deriveSigningKey({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
  }) {
    final dateKey = _hmac(utf8.encode('AWS4$secretAccessKey'), dateStamp);
    final regionKey = _hmac(dateKey, region);
    final serviceKey = _hmac(regionKey, 's3');
    return _hmac(serviceKey, 'aws4_request');
  }

  List<int> _hmac(List<int> key, String value) {
    return Hmac(sha256, key).convert(utf8.encode(value)).bytes;
  }

  String _formatAmzDate(DateTime time) {
    return '${_formatDateStamp(time)}T'
        '${time.hour.toString().padLeft(2, '0')}'
        '${time.minute.toString().padLeft(2, '0')}'
        '${time.second.toString().padLeft(2, '0')}Z';
  }

  String _formatDateStamp(DateTime time) {
    return '${time.year.toString().padLeft(4, '0')}'
        '${time.month.toString().padLeft(2, '0')}'
        '${time.day.toString().padLeft(2, '0')}';
  }

  String _hostHeader(Uri uri) {
    final isDefaultPort = (uri.scheme == 'https' && uri.port == 443) || (uri.scheme == 'http' && uri.port == 80);
    if (!uri.hasPort || isDefaultPort) {
      return uri.host;
    }
    return '${uri.host}:${uri.port}';
  }

  String _canonicalPath(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return '/';
    }
    return '/${uri.pathSegments.map(Uri.encodeComponent).join('/')}';
  }

  String _buildPublicUrl(String objectKey, Uri uploadUri) {
    final publicBaseUrl = config.publicBaseUrl.trim();
    if (publicBaseUrl.isEmpty) {
      return uploadUri.toString();
    }

    final baseUri = Uri.parse(publicBaseUrl.startsWith('http') ? publicBaseUrl : 'https://$publicBaseUrl');
    final baseSegments = baseUri.pathSegments.where((e) => e.isNotEmpty).toList();
    final objectSegments = objectKey.split('/').where((e) => e.isNotEmpty).toList();
    return _buildUriWithoutQuery(
      source: baseUri,
      pathSegments: [...baseSegments, ...objectSegments],
    ).toString();
  }

  Uri _buildUriWithoutQuery({
    required Uri source,
    required List<String> pathSegments,
    String? host,
  }) {
    // 不使用 Uri.replace(query: '')，因为空字符串会生成以 ? 结尾的空 query。
    return Uri(
      scheme: source.scheme,
      userInfo: source.userInfo,
      host: host ?? source.host,
      port: source.hasPort ? source.port : null,
      pathSegments: pathSegments,
    );
  }
}

class S3UploadException implements Exception {
  const S3UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
