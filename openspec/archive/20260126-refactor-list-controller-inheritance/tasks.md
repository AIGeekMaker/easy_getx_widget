# Tasks: EasyListController 继承重构

## Task 1: 修改 EasyRequestController 添加扩展点

**文件**: `lib/src/controllers/easy_request_controller.dart`

**精确变更**:

1. 将 `_isFetching` 暴露为 getter:
   ```dart
   bool get isFetching => _isFetching;
   ```

2. 添加 `clearError()` 方法:
   ```dart
   @protected
   void clearError() {
     _error.value = null;
     _errorStack.value = null;
   }
   ```

3. 将 `_isEmpty()` 改为 `@protected isEmptyData()`:
   ```dart
   @protected
   bool isEmptyData(T? data) {
     if (data == null) return true;
     if (data is List) return data.isEmpty;
     if (data is Map) return data.isEmpty;
     if (data is String) return data.isEmpty;
     return false;
   }
   ```

4. 添加 `performAutoFetch()` 钩子:
   ```dart
   @protected
   Future<void> performAutoFetch() async => fetch();
   ```

5. 修改 `onReady()` 使用钩子:
   ```dart
   @override
   void onReady() {
     super.onReady();
     if (autoFetch) {
       if (fetchDelay == Duration.zero) {
         performAutoFetch();
       } else {
         Future.delayed(fetchDelay, performAutoFetch);
       }
     }
   }
   ```

6. 修改 `fetch()` 支持 `preserveState` 参数:
   ```dart
   Future<void> fetch({bool preserveState = false}) async {
     if (_isFetching) return;
     _isFetching = true;

     clearError();

     // 策略：是否显示 loading
     if (!preserveState || state == null) {
       change(null, status: RxStatus.loading());
     }

     try {
       final result = await onFetch();
       if (result.isSuccess) {
         if (isEmptyData(result.data)) {
           change(null, status: RxStatus.empty());
         } else {
           final processedData = await onBeforeSuccess(result.data as T);
           change(processedData, status: RxStatus.success());
         }
       } else {
         _error.value = result.error;
         final currentStack = StackTrace.current;
         _errorStack.value = currentStack;
         if (result.error != null) {
           onError(result.error as E, currentStack);
         }
         // 策略：错误时是否保留数据
         if (!preserveState || state == null) {
           change(null, status: RxStatus.error());
         }
       }
     } catch (e, stack) {
       // ... 保持现有 catch 逻辑 ...
       // 策略：错误时是否保留数据
       if (!preserveState || state == null) {
         change(null, status: RxStatus.error());
       }
     } finally {
       _isFetching = false;
     }
   }
   ```

7. 添加 `onClose()`:
   ```dart
   @override
   void onClose() {
     _error.close();
     _errorStack.close();
     super.onClose();
   }
   ```

**验收标准**:
- `flutter test test/controllers/easy_request_controller_test.dart` 全部通过
- 新增方法可被子类访问

---

## Task 2: 重构 EasyListController 继承 EasyRequestController

**文件**: `lib/src/controllers/easy_list_controller.dart`

**精确变更**:

1. 修改类声明:
   ```dart
   abstract class EasyListController<T, E> extends EasyRequestController<List<T>, E> {
   ```

2. 删除重复成员（从父类继承）:
   - 删除 `_error`, `_errorStack`, `error`, `errorStack`
   - 删除 `autoFetch`, `fetchDelay`
   - 删除 `mapError()`

3. 将 `onFetch({required int page})` 重命名为 `onFetchPage(int page)`:
   ```dart
   Future<EasyHttpResult<List<T>, E>> onFetchPage(int page);
   ```

4. 实现父类 `onFetch()`:
   ```dart
   @override
   Future<EasyHttpResult<List<T>, E>> onFetch() => onFetchPage(_currentPage);
   ```

5. 覆写 `fetch()` 使其等价于 `refreshData()`:
   ```dart
   @override
   Future<void> fetch({bool preserveState = false}) => refreshData();
   ```

6. 覆写 `performAutoFetch()`:
   ```dart
   @override
   Future<void> performAutoFetch() async => refreshData();
   ```

7. 添加 `computeHasMore()` 钩子:
   ```dart
   @protected
   bool computeHasMore(List<T> items, int page) => items.length >= pageSize;
   ```

8. 修改 `refreshData()` 使用父类能力:
   ```dart
   Future<void> refreshData() async {
     if (_isRefreshing.value) return;

     _isRefreshing.value = true;
     _currentPage = 1;
     _loadMoreError.value = null;
     clearError();  // 使用父类方法

     final hasData = state != null && state!.isNotEmpty;

     // 如果当前没有数据，显示 loading 状态
     if (!hasData) {
       change(null, status: RxStatus.loading());
     }

     try {
       final result = await onFetchPage(1);
       if (result.isSuccess) {
         final items = result.data ?? [];
         _hasMore.value = computeHasMore(items, 1);

         if (items.isEmpty) {
           change([], status: RxStatus.empty());  // 使用 [] 而非 null
         } else {
           final processedItems = await onBeforeSuccess(items);
           change(processedItems, status: RxStatus.success());
         }
       } else {
         setError(result.error, StackTrace.current);
         if (result.error != null) {
           onError(result.error as E, StackTrace.current);
         }
         // 如果有旧数据则保留，否则显示错误
         if (!hasData) {
           change([], status: RxStatus.error());
         }
       }
     } catch (e, stack) {
       // ... 保持现有 catch 逻辑，使用 setError ...
       if (!hasData) {
         change([], status: RxStatus.error());
       }
     } finally {
       _isRefreshing.value = false;
     }
   }
   ```

9. 修改 `loadMore()` 使用 `computeHasMore()`:
   ```dart
   // 在 loadMore 成功分支
   _hasMore.value = computeHasMore(items, _currentPage + 1);
   ```

10. 拆分 `onBeforeSuccess` 钩子:
    ```dart
    @override
    @protected
    Future<List<T>> onBeforeSuccess(List<T> data) async => data;

    @protected
    Future<List<T>> onBeforeLoadMore(List<T> data) async => data;
    ```

11. 修改 `loadMore()` 使用 `onBeforeLoadMore`:
    ```dart
    final processedItems = await onBeforeLoadMore(mergedItems);
    ```

12. 删除 `onReady()` 覆写（使用父类逻辑 + performAutoFetch）

13. 修改 `onClose()` 调用 super:
    ```dart
    @override
    void onClose() {
      _isRefreshing.close();
      _isLoadingMore.close();
      _hasMore.close();
      _loadMoreError.close();
      super.onClose();  // 父类关闭 _error, _errorStack
    }
    ```

14. 添加 `setError()` 辅助方法（如果父类未提供）:
    ```dart
    @protected
    void setError(E? error, StackTrace stack) {
      // 通过父类 clearError 后重新设置
      // 或直接访问继承的 _error/_errorStack
    }
    ```

**验收标准**:
- `flutter test test/controllers/easy_list_controller_test.dart` 全部通过
- 继承关系正确建立

---

## Task 3: 更新测试适配新 API

**文件**: `test/controllers/easy_list_controller_test.dart`

**精确变更**:

1. 将所有 `onFetch({required int page})` 改为 `onFetchPage(int page)`:
   ```dart
   // Before
   Future<EasyHttpResult<List<String>, Object>> onFetch({required int page}) async {

   // After
   Future<EasyHttpResult<List<String>, Object>> onFetchPage(int page) async {
   ```

2. 如果测试使用了 `onBeforeSuccess(data, loadType)`，拆分为两个测试

**验收标准**:
- `flutter test` 全部通过
- 覆盖率 >= 90%

---

## Task 4: 更新导出和文档

**文件**: `lib/easy_getx_widget.dart`

**精确变更**:

1. 更新库文档示例代码:
   ```dart
   /// ### 列表分页请求
   /// ```dart
   /// class ArticleListController extends EasyListController<Article, String> {
   ///   @override
   ///   Future<EasyHttpResult<List<Article>, String>> onFetchPage(int page) async {
   ///     final response = await api.getArticles(page: page, pageSize: pageSize);
   ///     if (response.success) {
   ///       return EasyHttpResult.ok(response.data);
   ///     }
   ///     return EasyHttpResult.err(response.message);
   ///   }
   /// }
   /// ```
   ```

**验收标准**:
- 示例代码可编译运行
- `dart analyze` 无错误

---

## Task 5: 运行完整测试套件

**命令**:
```bash
flutter test --coverage
```

**验收标准**:
- 所有测试通过
- 覆盖率 >= 90%
