class S3UploadConfig {
  const S3UploadConfig({
    this.endpoint = '',
    this.region = 'us-east-1',
    this.bucket = '',
    this.accessKeyId = '',
    this.secretAccessKey = '',
    this.pathPrefix = 'lingyun-time',
    this.publicBaseUrl = '',
    this.usePathStyle = true,
  });

  final String endpoint;
  final String region;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String pathPrefix;
  final String publicBaseUrl;
  final bool usePathStyle;

  bool get isConfigured {
    return endpoint.trim().isNotEmpty &&
        region.trim().isNotEmpty &&
        bucket.trim().isNotEmpty &&
        accessKeyId.trim().isNotEmpty &&
        secretAccessKey.trim().isNotEmpty;
  }

  String get normalizedEndpoint {
    final trimmed = endpoint.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  S3UploadConfig copyWith({
    String? endpoint,
    String? region,
    String? bucket,
    String? accessKeyId,
    String? secretAccessKey,
    String? pathPrefix,
    String? publicBaseUrl,
    bool? usePathStyle,
  }) {
    return S3UploadConfig(
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
      pathPrefix: pathPrefix ?? this.pathPrefix,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      usePathStyle: usePathStyle ?? this.usePathStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'region': region,
        'bucket': bucket,
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'pathPrefix': pathPrefix,
        'publicBaseUrl': publicBaseUrl,
        'usePathStyle': usePathStyle,
      };

  factory S3UploadConfig.fromJson(Map<String, dynamic> json) {
    return S3UploadConfig(
      endpoint: json['endpoint'] as String? ?? '',
      region: json['region'] as String? ?? 'us-east-1',
      bucket: json['bucket'] as String? ?? '',
      accessKeyId: json['accessKeyId'] as String? ?? '',
      secretAccessKey: json['secretAccessKey'] as String? ?? '',
      pathPrefix: json['pathPrefix'] as String? ?? 'lingyun-time',
      publicBaseUrl: json['publicBaseUrl'] as String? ?? '',
      usePathStyle: json['usePathStyle'] as bool? ?? true,
    );
  }
}
