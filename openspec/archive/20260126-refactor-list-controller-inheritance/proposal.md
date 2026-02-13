# Proposal: EasyListController 继承 EasyRequestController

## Context

用户需求：`EasyListController` 应该是 `EasyRequestController` 的扩展，建立清晰的 "is-a" 关系。

当前状态：
- `EasyRequestController<T, E>` - 单数据请求，`StateMixin<T>`
- `EasyListController<T, E>` - 列表分页请求，`StateMixin<List<T>>`
- 两者有 40-50% 重复代码

## Decision

采用 **泛型继承方案**：
```dart
EasyListController<T, E> extends EasyRequestController<List<T>, E>
```

允许破坏性变更，提供迁移指南。

## Resolved Constraints

### Hard Constraints (MUST)

| ID | Constraint | Rationale |
|----|------------|-----------|
| HC-1 | 子类必须复用父类的 error/errorStack 管理 | 消除重复代码 |
| HC-2 | 子类必须复用父类的 autoFetch/fetchDelay 逻辑 | 消除重复代码 |
| HC-3 | 子类必须复用父类的 mapError 方法 | 消除重复代码 |
| HC-4 | 所有现有测试必须通过（允许修改测试适配新 API） | 保证功能正确性 |
| HC-5 | onFetch 签名变更：从 `{required int page}` 改为 `onFetchPage(int page)` | 适配父类无参 onFetch |
| HC-6 | 父类 fetch() 必须支持"保留现有数据"策略 | 避免刷新时闪屏 |
| HC-7 | 父类必须提供 `clearError()` 方法 | 子类需要在 resetPagination 时清理 |
| HC-8 | 父类必须暴露 `isFetching` getter | 子类 loadMore 需要互斥判断 |
| HC-9 | 父类必须提供 `performAutoFetch()` 钩子 | 子类覆写为 refreshData() |
| HC-10 | 父类必须将 `_isEmpty` 改为 `@protected isEmptyData()` | 子类可覆写空判断 |
| HC-11 | 父类必须在 onClose() 关闭 Rxn 变量 | 避免资源泄漏 |

### User Decisions (已确认)

| ID | Decision | Choice |
|----|----------|--------|
| UD-1 | fetch() 暴露策略 | `fetch() = refreshData()`，覆写使其等价 |
| UD-2 | empty 状态的 state | `[] + RxStatus.empty`，避免 state! 报错 |
| UD-3 | hasMore 策略 | **可覆写**，提供 `computeHasMore()` 钩子 |
| UD-4 | 起始页码 | **固定为 1** |

### Soft Constraints (SHOULD)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-1 | 保持 obx 方法签名一致 | 减少使用者学习成本 |
| SC-2 | 提供 CHANGELOG 和迁移指南 | 帮助使用者升级 |

## Architecture

```
GetxController
    │
    ├── with StateMixin<T>
    │
    ▼
EasyRequestController<T, E>
    │  - error, errorStack (with clearError())
    │  - autoFetch, fetchDelay
    │  - mapError(), onError()
    │  - fetch({preserveState}) → onFetch()
    │  - performAutoFetch() [可覆写]
    │  - isEmptyData() [可覆写]
    │  - isFetching [getter]
    │  - obx()
    │  - onClose() [关闭 Rxn]
    │
    ▼
EasyListController<T, E> extends EasyRequestController<List<T>, E>
       - 分页状态: currentPage, hasMore, isRefreshing, isLoadingMore
       - loadMoreError
       - fetch() → 覆写为 refreshData()
       - refreshData() → 调用 super.fetch(preserveState: hasData)
       - loadMore()
       - onFetchPage(int page) → 子类实现
       - computeHasMore(items, page) [可覆写]
       - onLoadMoreError()
       - isEmptyData() → 覆写返回 [] 而非 null
```

## Breaking Changes

| Before | After | Migration |
|--------|-------|-----------|
| `onFetch({required int page})` | `onFetchPage(int page)` | 重命名方法 |
| `onBeforeSuccess(List<T>, ListLoadType)` | `onBeforeSuccess(List<T>)` + `onBeforeLoadMore(List<T>)` | 拆分为两个钩子 |

## Parent Class Changes Required

### 1. 新增扩展点

```dart
// EasyRequestController 新增
@protected
Future<void> performAutoFetch() async => fetch();

@protected
bool isEmptyData(T? data) { ... }

@protected
void clearError() {
  _error.value = null;
  _errorStack.value = null;
}

bool get isFetching => _isFetching;
```

### 2. fetch() 策略支持

```dart
Future<void> fetch({bool preserveState = false}) async {
  if (_isFetching) return;
  _isFetching = true;

  clearError();

  // 策略：是否显示 loading
  if (!preserveState || state == null) {
    change(null, status: RxStatus.loading());
  }

  // ... 请求逻辑 ...

  // 策略：错误时是否保留数据
  if (result.isError && preserveState && state != null) {
    // 保留旧数据，不切换到 error 状态
  } else {
    change(null, status: RxStatus.error());
  }
}
```

### 3. onClose() 补充

```dart
@override
void onClose() {
  _error.close();
  _errorStack.close();
  super.onClose();
}
```

## Success Criteria

- [x] 架构决策已确认
- [x] 所有用户决策已记录
- [ ] EasyListController 继承 EasyRequestController
- [ ] 重复代码减少 40% 以上
- [ ] 所有测试通过
- [ ] 提供迁移指南
