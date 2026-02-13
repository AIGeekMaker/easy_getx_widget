import 'package:flutter_test/flutter_test.dart';
import 'package:easy_getx_widget/easy_getx_widget.dart';

void main() {
  group('EasyHttpResult', () {
    test('ok 工厂构造应该创建成功结果', () {
      final result = EasyHttpResult<String, String>.ok('data');
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.data, equals('data'));
      expect(result.error, isNull);
    });

    test('err 工厂构造应该创建失败结果', () {
      final result = EasyHttpResult<String, String>.err('error');
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.data, isNull);
      expect(result.error, equals('error'));
    });

    test('默认构造函数应该正确设置字段', () {
      final result = EasyHttpResult<int, String>(data: 42, error: null);
      expect(result.isSuccess, isTrue);
      expect(result.data, equals(42));
    });

    test('toString 成功时应该返回 ok 格式', () {
      final result = EasyHttpResult<String, String>.ok('test');
      expect(result.toString(), equals('EasyHttpResult.ok(test)'));
    });

    test('toString 失败时应该返回 err 格式', () {
      final result = EasyHttpResult<String, String>.err('error msg');
      expect(result.toString(), equals('EasyHttpResult.err(error msg)'));
    });
  });
}
