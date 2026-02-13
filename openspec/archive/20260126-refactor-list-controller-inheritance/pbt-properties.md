# PBT Properties: EasyListController 继承重构

## Property 1: 继承不变性 (Inheritance Invariant)

**INVARIANT**: `EasyListController<T, E>` 实例必须同时是 `EasyRequestController<List<T>, E>` 实例

**FALSIFICATION STRATEGY**:
```dart
test('继承关系验证', () {
  final controller = TestListController();
  expect(controller, isA<EasyRequestController<List<String>, Object>>());
  expect(controller, isA<GetxController>());
});
```

---

## Property 2: 错误状态共享 (Error State Sharing)

**INVARIANT**: 子类的 `error` 和 `errorStack` 必须与父类共享同一存储

**FALSIFICATION STRATEGY**:
```dart
test('错误状态共享', () {
  final controller = TestListController();
  controller.mockError = Exception('test');
  await controller.refreshData();

  // 通过父类引用访问
  final parent = controller as EasyRequestController<List<String>, Object>;
  expect(identical(parent.error, controller.error), isTrue);
  expect(identical(parent.errorStack, controller.errorStack), isTrue);
});
```

---

## Property 3: 刷新幂等性 (Refresh Idempotency)

**INVARIANT**: 连续调用 `refreshData()` 应重置到第一页，且最终状态一致

**BOUNDARY CONDITIONS**:
- 有数据时刷新
- 无数据时刷新
- 刷新失败后再刷新

**FALSIFICATION STRATEGY**:
```dart
test('刷新幂等性', () {
  await controller.refreshData();
  await controller.loadMore();
  expect(controller.currentPage, equals(2));

  await controller.refreshData();
  expect(controller.currentPage, equals(1));

  // 再次刷新，状态应一致
  await controller.refreshData();
  expect(controller.currentPage, equals(1));
});
```

---

## Property 4: 页码单调性 (Page Monotonicity)

**INVARIANT**: `currentPage` 只能通过 `loadMore` 递增，通过 `refreshData` 重置为 1

**BOUNDARY CONDITIONS**:
- loadMore 失败时 currentPage 不变
- refreshData 失败时 currentPage 重置为 1
- 并发调用时页码不错乱

**FALSIFICATION STRATEGY**:
```dart
test('页码单调性 - loadMore 失败', () {
  await controller.refreshData();
  expect(controller.currentPage, equals(1));

  controller.mockError = Exception('error');
  await controller.loadMore();

  expect(controller.currentPage, equals(1)); // 失败不递增
});

test('页码单调性 - refresh 失败', () {
  await controller.refreshData();
  await controller.loadMore();
  expect(controller.currentPage, equals(2));

  controller.mockError = Exception('error');
  await controller.refreshData();

  expect(controller.currentPage, equals(1)); // 失败也重置
});
```

---

## Property 5: 数据保留策略 (Data Preservation)

**INVARIANT**: 刷新失败时，如果已有数据，则保留旧数据且状态保持 success

**BOUNDARY CONDITIONS**:
- 有数据时刷新失败 → 保留数据
- 无数据时刷新失败 → 显示 error

**FALSIFICATION STRATEGY**:
```dart
test('数据保留 - 有旧数据时刷新失败', () {
  await controller.refreshData();
  final oldData = controller.state;
  expect(oldData!.isNotEmpty, isTrue);

  controller.mockError = Exception('error');
  await controller.refreshData();

  expect(controller.state, equals(oldData)); // 数据保留
  expect(controller.status.isSuccess, isTrue); // 状态保持
});

test('数据保留 - 无数据时刷新失败', () {
  controller.mockError = Exception('error');
  await controller.refreshData();

  expect(controller.status.isError, isTrue);
});
```

---

## Property 6: Empty 状态一致性 (Empty State Consistency)

**INVARIANT**: 列表为空时，`state` 必须是 `[]` 而非 `null`

**FALSIFICATION STRATEGY**:
```dart
test('empty 状态使用空列表', () {
  controller.mockFetch = (_) => [];
  await controller.refreshData();

  expect(controller.status.isEmpty, isTrue);
  expect(controller.state, isNotNull);
  expect(controller.state, equals([]));
});
```

---

## Property 7: fetch/refreshData 等价性 (Method Equivalence)

**INVARIANT**: 调用 `fetch()` 必须等价于调用 `refreshData()`

**FALSIFICATION STRATEGY**:
```dart
test('fetch 等价于 refreshData', () async {
  await controller.fetch();
  final stateAfterFetch = controller.state;
  final pageAfterFetch = controller.currentPage;

  controller.resetPagination();
  await controller.refreshData();
  final stateAfterRefresh = controller.state;
  final pageAfterRefresh = controller.currentPage;

  expect(stateAfterFetch, equals(stateAfterRefresh));
  expect(pageAfterFetch, equals(pageAfterRefresh));
});
```

---

## Property 8: hasMore 计算正确性 (HasMore Correctness)

**INVARIANT**: `hasMore` 必须基于 `computeHasMore(items, page)` 的返回值

**BOUNDARY CONDITIONS**:
- items.length == pageSize → hasMore = true
- items.length < pageSize → hasMore = false
- items.length > pageSize → hasMore = true (异常情况)

**FALSIFICATION STRATEGY**:
```dart
test('hasMore 计算 - 满页', () {
  controller.mockFetch = (_) => List.generate(10, (i) => 'item_$i');
  await controller.refreshData();
  expect(controller.hasMore, isTrue);
});

test('hasMore 计算 - 不满页', () {
  controller.mockFetch = (_) => List.generate(5, (i) => 'item_$i');
  await controller.refreshData();
  expect(controller.hasMore, isFalse);
});
```

---

## Property 9: 并发互斥 (Concurrency Exclusion)

**INVARIANT**:
- 并发 refreshData 只执行一次
- 并发 loadMore 只执行一次
- refreshData 和 loadMore 互斥

**FALSIFICATION STRATEGY**:
```dart
test('并发 refreshData 互斥', () async {
  final futures = [
    controller.refreshData(),
    controller.refreshData(),
    controller.refreshData(),
  ];
  await Future.wait(futures);
  expect(controller.fetchCount, equals(1));
});

test('refresh 和 loadMore 互斥', () async {
  // 启动 refresh
  final refreshFuture = controller.refreshData();
  // 立即尝试 loadMore
  await controller.loadMore();
  await refreshFuture;

  // loadMore 应该被阻止（因为 isRefreshing）
  expect(controller.currentPage, equals(1));
});
```

---

## Property 10: 生命周期正确性 (Lifecycle Correctness)

**INVARIANT**: `onClose()` 必须关闭所有 Rx 变量，且不抛出异常

**FALSIFICATION STRATEGY**:
```dart
test('onClose 关闭所有 Rx 变量', () {
  final controller = TestListController();
  controller.onClose();
  // 不应该抛出异常
  // 再次调用也不应该抛出
  controller.onClose();
});
```
