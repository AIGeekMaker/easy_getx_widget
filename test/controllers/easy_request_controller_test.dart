import 'package:flutter_test/flutter_test.dart';
import 'package:easy_getx_widget/easy_getx_widget.dart';

// 测试用的具体实现
class TestRequestController extends EasyRequestController<String, Object> {
  String? mockResult;
  Object? mockError;
  int fetchCount = 0;
  Object? lastError;
  StackTrace? lastStackTrace;

  @override
  bool get autoFetch => false; // 测试时手动控制

  @override
  Future<EasyHttpResult<String, Object>> onFetch() async {
    fetchCount++;
    if (mockError != null) {
      return EasyHttpResult.err(mockError!);
    }
    return EasyHttpResult.ok(mockResult ?? 'test data');
  }

  @override
  void onError(Object error, StackTrace stack) {
    lastError = error;
    lastStackTrace = stack;
  }
}

class AutoFetchController extends EasyRequestController<String, Object> {
  int fetchCount = 0;

  @override
  bool get autoFetch => true;

  @override
  Future<EasyHttpResult<String, Object>> onFetch() async {
    fetchCount++;
    return EasyHttpResult.ok('auto data');
  }
}

class DelayedFetchController extends EasyRequestController<String, Object> {
  int fetchCount = 0;

  @override
  bool get autoFetch => true;

  @override
  Duration get fetchDelay => const Duration(milliseconds: 100);

  @override
  Future<EasyHttpResult<String, Object>> onFetch() async {
    fetchCount++;
    return EasyHttpResult.ok('delayed data');
  }
}

// 测试 null 返回的控制器
class NullableController extends EasyRequestController<String?, Object> {
  bool returnNull = false;

  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<String?, Object>> onFetch() async {
    if (returnNull) return EasyHttpResult.ok(null);
    return EasyHttpResult.ok('data');
  }
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('EasyRequestController', () {
    test('初始状态应该存在', () {
      final controller = Get.put(TestRequestController());
      expect(controller.status, isNotNull);
    });

    test('fetch 成功应该设置 success 状态', () async {
      final controller = Get.put(TestRequestController());
      controller.mockResult = 'success data';

      await controller.fetch();

      expect(controller.status.isSuccess, isTrue);
      expect(controller.state, equals('success data'));
    });

    test('fetch 空字符串应该设置 empty 状态', () async {
      final controller = Get.put(TestRequestController());
      controller.mockResult = ''; // 空字符串

      await controller.fetch();

      expect(controller.status.isEmpty, isTrue);
    });

    test('fetch null 数据应该设置 empty 状态', () async {
      final controller = Get.put(NullableController());
      controller.returnNull = true;

      await controller.fetch();

      expect(controller.status.isEmpty, isTrue);
    });

    test('fetch 失败应该设置 error 状态', () async {
      final controller = Get.put(TestRequestController());
      controller.mockError = Exception('test error');

      await controller.fetch();

      expect(controller.status.isError, isTrue);
      expect(controller.error, isA<Exception>());
      expect(controller.error.toString(), contains('test error'));
    });

    test('fetch 失败应该调用 onError 钩子', () async {
      final controller = Get.put(TestRequestController());
      final testError = Exception('test error');
      controller.mockError = testError;

      await controller.fetch();

      expect(controller.lastError, equals(testError));
      expect(controller.lastStackTrace, isNotNull);
    });

    test('并发 fetch 应该被阻止', () async {
      final controller = Get.put(TestRequestController());
      controller.mockResult = 'data';

      // 并发调用
      final futures = [
        controller.fetch(),
        controller.fetch(),
        controller.fetch(),
      ];
      await Future.wait(futures);

      // 只应该执行一次
      expect(controller.fetchCount, equals(1));
    });

    test('fetch 完成后可以再次 fetch', () async {
      final controller = Get.put(TestRequestController());
      controller.mockResult = 'data';

      await controller.fetch();
      await controller.fetch();

      expect(controller.fetchCount, equals(2));
    });

    test('autoFetch 为 true 时应该在 onReady 自动执行', () async {
      final controller = Get.put(AutoFetchController());

      // 模拟 onReady 调用
      controller.onReady();

      // 等待异步操作完成
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.fetchCount, equals(1));
    });

    test('fetchDelay 应该延迟执行', () async {
      final controller = Get.put(DelayedFetchController());

      controller.onReady();

      // 立即检查，应该还没执行
      expect(controller.fetchCount, equals(0));

      // 等待延迟时间
      await Future.delayed(const Duration(milliseconds: 150));

      expect(controller.fetchCount, equals(1));
    });

    test('空 List 应该被识别为 empty', () async {
      final listController = Get.put(_ListTestController());
      listController.mockResult = [];

      await listController.fetch();

      expect(listController.status.isEmpty, isTrue);
    });

    test('空 Map 应该被识别为 empty', () async {
      final mapController = Get.put(_MapTestController());
      mapController.mockResult = {};

      await mapController.fetch();

      expect(mapController.status.isEmpty, isTrue);
    });

    test('非空 List 应该被识别为 success', () async {
      final listController = Get.put(_ListTestController());
      listController.mockResult = ['item1', 'item2'];

      await listController.fetch();

      expect(listController.status.isSuccess, isTrue);
    });

    test('非空 Map 应该被识别为 success', () async {
      final mapController = Get.put(_MapTestController());
      mapController.mockResult = {'key': 'value'};

      await mapController.fetch();

      expect(mapController.status.isSuccess, isTrue);
    });

    test('onFetch 抛出异常应该被 catch 分支捕获', () async {
      final controller = Get.put(_ThrowingController());
      await controller.fetch();
      expect(controller.status.isError, isTrue);
      expect(controller.error, isA<Exception>());
    });

    test('mapError 转换失败应该设置 error 为 null', () async {
      final controller = Get.put(_BadMapErrorController());
      await controller.fetch();
      expect(controller.status.isError, isTrue);
      expect(controller.error, isNull);
    });

    test('onErrorHandled 返回 false 时应该设置 error 状态', () async {
      final controller = Get.put(_ErrorHandledController());
      controller.mockError = Exception('test error');
      controller.handleError = false; // 默认行为

      await controller.fetch();

      expect(controller.status.isError, isTrue);
      expect(controller.error, isA<Exception>());
      expect(controller.onErrorCalled, isTrue);
      expect(controller.lastError, isA<Exception>());
    });

    test('onErrorHandled 返回 true 时应该跳过 error 状态设置', () async {
      final controller = Get.put(_ErrorHandledController());
      controller.mockError = Exception('test error');
      controller.handleError = true; // 标记错误已处理

      await controller.fetch();

      // 状态不应该变为 error
      expect(controller.status.isError, isFalse);
      // error 属性仍然应该被设置
      expect(controller.error, isA<Exception>());
      // onError 仍然应该被调用
      expect(controller.onErrorCalled, isTrue);
      expect(controller.lastError, isA<Exception>());
    });

    test('onErrorHandled 在 catch 分支也应该生效', () async {
      final controller = Get.put(_ThrowingErrorHandledController());
      controller.handleError = true; // 标记错误已处理

      await controller.fetch();

      // 状态不应该变为 error
      expect(controller.status.isError, isFalse);
      // error 属性仍然应该被设置
      expect(controller.error, isA<Exception>());
      // onError 仍然应该被调用
      expect(controller.onErrorCalled, isTrue);
      expect(controller.lastError, isA<Exception>());
    });
  });
}

// 辅助测试类
class _ListTestController extends EasyRequestController<List<String>, Object> {
  List<String>? mockResult;

  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<List<String>, Object>> onFetch() async =>
      EasyHttpResult.ok(mockResult ?? []);
}

class _MapTestController
    extends EasyRequestController<Map<String, dynamic>, Object> {
  Map<String, dynamic>? mockResult;

  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<Map<String, dynamic>, Object>> onFetch() async =>
      EasyHttpResult.ok(mockResult ?? {});
}

// 测试 onFetch 抛出异常的控制器
class _ThrowingController extends EasyRequestController<String, Exception> {
  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<String, Exception>> onFetch() async {
    throw Exception('thrown error');
  }
}

// 测试 mapError 转换失败的控制器
class _BadMapErrorController extends EasyRequestController<String, String> {
  @override
  bool get autoFetch => false;

  @override
  String mapError(Object error, StackTrace stack) {
    throw Exception('mapError failed');
  }

  @override
  Future<EasyHttpResult<String, String>> onFetch() async {
    throw Exception('original error');
  }
}

// 测试 onErrorHandled 钩子的控制器
class _ErrorHandledController extends EasyRequestController<String, Object> {
  Object? mockError;
  bool handleError = false; // 控制 onErrorHandled 返回值
  Object? lastError;
  bool onErrorCalled = false;

  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<String, Object>> onFetch() async {
    if (mockError != null) {
      return EasyHttpResult.err(mockError!);
    }
    return EasyHttpResult.ok('data');
  }

  @override
  void onError(Object error, StackTrace stack) {
    onErrorCalled = true;
    lastError = error;
  }

  @override
  Future<bool> onErrorHandled(Object error, StackTrace stack) async =>
      handleError;
}

// 测试 onErrorHandled 在 catch 分支的控制器
class _ThrowingErrorHandledController
    extends EasyRequestController<String, Object> {
  bool handleError = false;
  Object? lastError;
  bool onErrorCalled = false;

  @override
  bool get autoFetch => false;

  @override
  Future<EasyHttpResult<String, Object>> onFetch() async {
    throw Exception('thrown error');
  }

  @override
  void onError(Object error, StackTrace stack) {
    onErrorCalled = true;
    lastError = error;
  }

  @override
  Future<bool> onErrorHandled(Object error, StackTrace stack) async =>
      handleError;
}
