import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:easy_getx_widget/easy_getx_widget.dart';

// 测试用的具体实现
class TestListController extends EasyListController<String, Object> {
  List<String> Function(int page)? mockFetch;
  Object? mockError;
  int fetchCount = 0;
  Object? lastError;
  Object? lastLoadMoreError;
  int loadMoreNoMoreCount = 0;

  @override
  bool get autoFetch => false;

  @override
  int get pageSize => 10;

  @override
  Future<EasyHttpResult<List<String>, Object>> onFetchPage(int page) async {
    fetchCount++;
    if (mockError != null) {
      return EasyHttpResult.err(mockError!);
    }
    if (mockFetch != null) {
      return EasyHttpResult.ok(mockFetch!(page));
    }
    return EasyHttpResult.ok(List.generate(pageSize, (i) => 'item_${page}_$i'));
  }

  @override
  void onError(Object error, StackTrace stack) {
    lastError = error;
  }

  @override
  void onLoadMoreError(Object error, StackTrace stack) {
    lastLoadMoreError = error;
  }

  @override
  void onLoadMoreNoMore() {
    loadMoreNoMoreCount++;
  }
}

// autoFetch=true 的测试控制器
class AutoFetchListController extends EasyListController<String, Object> {
  int fetchCount = 0;

  @override
  bool get autoFetch => true;

  @override
  int get pageSize => 10;

  @override
  Future<EasyHttpResult<List<String>, Object>> onFetchPage(int page) async {
    fetchCount++;
    return EasyHttpResult.ok(List.generate(pageSize, (i) => 'item_${page}_$i'));
  }
}

// 带延迟的测试控制器
class DelayedFetchListController extends EasyListController<String, Object> {
  int fetchCount = 0;

  @override
  bool get autoFetch => true;

  @override
  Duration get fetchDelay => const Duration(milliseconds: 100);

  @override
  int get pageSize => 10;

  @override
  Future<EasyHttpResult<List<String>, Object>> onFetchPage(int page) async {
    fetchCount++;
    return EasyHttpResult.ok(List.generate(pageSize, (i) => 'item_${page}_$i'));
  }
}

class _GateListController extends EasyListController<String, Object> {
  int fetchCount = 0;
  Completer<void>? _gate;
  EasyHttpResult<List<String>, Object> _nextResult =
      EasyHttpResult.ok(const <String>[]);

  @override
  bool get autoFetch => false;

  @override
  int get pageSize => 10;

  void prepareNext(EasyHttpResult<List<String>, Object> result) {
    _nextResult = result;
    _gate = Completer<void>();
  }

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<EasyHttpResult<List<String>, Object>> onFetchPage(int page) async {
    fetchCount++;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return _nextResult;
  }
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('EasyListController - Refresh', () {
    test('refreshData 成功应该设置 success 状态', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();
      expect(controller.status.isSuccess, isTrue);
      expect(controller.state!.length, equals(10));
      expect(controller.currentPage, equals(1));
    });

    test('refreshData 空数据应该设置 empty 状态', () async {
      final controller = Get.put(TestListController());
      controller.mockFetch = (_) => [];
      await controller.refreshData();
      expect(controller.status.isEmpty, isTrue);
    });

    test('refreshData 失败（无旧数据）应该设置 error 状态', () async {
      final controller = Get.put(TestListController());
      controller.mockError = Exception('refresh error');
      await controller.refreshData();
      expect(controller.status.isError, isTrue);
    });

    test('refreshData 失败（有旧数据）应该保留旧数据', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();
      expect(controller.state!.length, equals(10));

      controller.mockError = Exception('refresh error');
      await controller.refreshData();

      expect(controller.state!.length, equals(10));
      expect(controller.status.isSuccess, isTrue);
    });

    test('并发 refreshData 应该被阻止', () async {
      final controller = Get.put(TestListController());
      final futures = [
        controller.refreshData(),
        controller.refreshData(),
        controller.refreshData(),
      ];
      await Future.wait(futures);
      expect(controller.fetchCount, equals(1));
    });

    test('refreshData(preserveState=true) 在已有状态时不应切换到 loading', () async {
      final controller = Get.put(_GateListController());
      controller.prepareNext(
        EasyHttpResult.ok(List.generate(10, (i) => 'item_1_$i')),
      );
      controller.release();
      await controller.refreshData();
      expect(controller.status.isSuccess, isTrue);

      controller.prepareNext(
        EasyHttpResult.ok(List.generate(10, (i) => 'item_1_$i')),
      );
      final future = controller.refreshData();
      // refreshData 在进入 await 之前会同步决定是否切换状态
      expect(controller.status.isSuccess, isTrue);

      controller.release();
      await future;
      expect(controller.status.isSuccess, isTrue);
    });

    test('refreshData(preserveState=false) 每次都应切换到 loading', () async {
      final controller = Get.put(_GateListController());
      controller.prepareNext(
        EasyHttpResult.ok(List.generate(10, (i) => 'item_1_$i')),
      );
      controller.release();
      await controller.refreshData();
      expect(controller.status.isSuccess, isTrue);

      controller.prepareNext(
        EasyHttpResult.ok(List.generate(10, (i) => 'item_1_$i')),
      );
      final future = controller.refreshData(preserveState: false);
      expect(controller.status.isLoading, isTrue);

      controller.release();
      await future;
      expect(controller.status.isSuccess, isTrue);
    });
  });

  group('EasyListController - LoadMore', () {
    test('loadMore 成功应该追加数据', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();
      final beforeCount = controller.fetchCount;

      await controller.loadMore();

      expect(controller.state!.length, equals(20));
      expect(controller.currentPage, equals(2));
      expect(controller.fetchCount, equals(beforeCount + 1));
    });

    test('loadMore 返回少于 pageSize 应该设置 hasMore 为 false', () async {
      final controller = Get.put(TestListController());
      controller.mockFetch = (page) => page == 1
          ? List.generate(10, (i) => 'item_$i')
          : List.generate(5, (i) => 'item_$i');

      await controller.refreshData();
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.hasMore, isFalse);
    });

    test('loadMore 返回空列表应触发 onLoadMoreNoMore 且 hasMore=false', () async {
      final controller = Get.put(TestListController());
      controller.mockFetch = (page) =>
          page == 1 ? List.generate(10, (i) => 'item_$i') : <String>[];

      await controller.refreshData();
      expect(controller.hasMore, isTrue);
      expect(controller.loadMoreNoMoreCount, equals(0));

      await controller.loadMore();
      expect(controller.loadMoreNoMoreCount, equals(1));
      expect(controller.hasMore, isFalse);
      expect(controller.state!.length, equals(10));
      expect(controller.currentPage, equals(2));
    });

    test('hasMore 为 false 时 loadMore 应该被阻止', () async {
      final controller = Get.put(TestListController());
      controller.mockFetch = (page) => List.generate(5, (i) => 'item_$i');

      await controller.refreshData();
      expect(controller.hasMore, isFalse);

      final beforeCount = controller.fetchCount;
      await controller.loadMore();
      expect(controller.fetchCount, equals(beforeCount));
    });

    test('loadMore 失败应该设置 loadMoreError', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();

      controller.mockError = Exception('loadMore error');
      await controller.loadMore();

      expect(controller.loadMoreError?.toString(), contains('loadMore error'));
      expect(controller.state!.length, equals(10));
      expect(controller.currentPage, equals(1));
    });
  });

  group('EasyListController - 状态管理', () {
    test('isRefreshing 状态应该在刷新完成后为 false', () async {
      final controller = Get.put(TestListController());
      expect(controller.isRefreshing, isFalse);
      await controller.refreshData();
      expect(controller.isRefreshing, isFalse);
    });

    test('isLoadingMore 状态应该在加载完成后为 false', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();
      expect(controller.isLoadingMore, isFalse);
      await controller.loadMore();
      expect(controller.isLoadingMore, isFalse);
    });

    test('resetPagination 应该重置分页状态', () async {
      final controller = Get.put(TestListController());
      await controller.refreshData();

      // 验证初始状态
      expect(controller.currentPage, equals(1));
      expect(controller.hasMore, isTrue);

      // 修改状态
      controller.resetPagination();

      // 验证重置后的状态
      expect(controller.currentPage, equals(1));
      expect(controller.hasMore, isTrue);
      expect(controller.loadMoreError, isNull);
    });
  });

  group('EasyListController - 生命周期', () {
    test('onClose 应该关闭所有 Rx 变量', () async {
      final controller = Get.put(TestListController());
      controller.onClose();
      // 不应该抛出异常
    });

    test('autoFetch 为 true 时应该在 onReady 自动刷新', () async {
      final controller = Get.put(AutoFetchListController());
      controller.onReady();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.fetchCount, equals(1));
    });

    test('fetchDelay 应该延迟执行刷新', () async {
      final controller = Get.put(DelayedFetchListController());
      controller.onReady();
      expect(controller.fetchCount, equals(0));
      await Future.delayed(const Duration(milliseconds: 150));
      expect(controller.fetchCount, equals(1));
    });
  });

  group('EasyListController - 异常处理', () {
    test('onFetch 抛出异常应该被 catch 分支捕获', () async {
      final controller = Get.put(_ThrowingListController());
      await controller.refreshData();
      expect(controller.status.isError, isTrue);
    });

    test('loadMore 抛出异常应该设置 loadMoreError', () async {
      final controller = Get.put(_ThrowOnLoadMoreController());
      await controller.refreshData();
      await controller.loadMore();
      expect(controller.loadMoreError, isNotNull);
    });
  });
}

// 测试 onFetchPage 抛出异常的控制器
class _ThrowingListController extends EasyListController<String, Exception> {
  @override
  bool get autoFetch => false;

  @override
  int get pageSize => 10;

  @override
  Future<EasyHttpResult<List<String>, Exception>> onFetchPage(int page) {
    throw Exception('thrown error');
  }
}

// 测试 loadMore 抛出异常的控制器
class _ThrowOnLoadMoreController extends EasyListController<String, Exception> {
  @override
  bool get autoFetch => false;

  @override
  int get pageSize => 10;

  @override
  Future<EasyHttpResult<List<String>, Exception>> onFetchPage(int page) {
    if (page > 1) {
      throw Exception('loadMore error');
    }
    return Future.value(EasyHttpResult.ok(List.generate(10, (i) => 'item_$i')));
  }
}
