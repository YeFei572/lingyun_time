import 'package:uuid/uuid.dart';

class IdGenerator {
  static const _uuid = Uuid();

  static String next() => _uuid.v4();
}
