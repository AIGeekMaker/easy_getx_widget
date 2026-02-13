import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/easy_http_result.dart';
import 'easy_request_controller.dart';

/// 列表分页请求控制器基类
///
/// 继承自 [EasyRequestController]，复用错误管理和生命周期逻辑。
///
/// 使用示例：
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
abstract class EasyListController<T, E>
    extends EasyRequestController<List<T>, E> {
  // ===== 加载更多错误状态 =====
  final Rxn<E> _loadMoreError = Rxn<E>();

  /// 加载更多的错误对象（完整类型 E）
  E? get loadMoreError => _loadMoreError.value;

  // ===== 分页状态（响应式）=====
  final _isRefreshing = false.obs;
  final _isLoadingMore = false.obs;
  final _hasMore = true.obs;

  /// 是否正在下拉刷新
  bool get isRefreshing => _isRefreshing.value;

  /// 是否正在加载更多
  bool get isLoadingMore => _isLoadingMore.value;

  /// 是否还有更多数据
  bool get hasMore => _hasMore.value;

  // ===== 分页参数 =====

  /// 每页数据量
  int get pageSize => 20;

  int _currentPage = 1;

  /// 当前页码
  int get currentPage => _currentPage;

  /// 服务端返回的总数据量（用于精确计算 hasMore）
  int? _total;

  /// 总数据量（如果已设置）
  int? get total => _total;

  /// 设置总数据量，框架会自动计算 hasMore
  ///
  /// 在 [onFetchPage] 中调用此方法，传入服务端返回的 total：
  /// ```dart
  /// @override
  /// Future<EasyHttpResult<List<T>, E>> onFetchPage(int page) async {
  ///   final response = await api.getList(page: page);
  ///   setTotal(response.pagination.total);
  ///   return EasyHttpResult.ok(response.items);
  /// }
  /// ```
  @protected
  void setTotal(int total) {
    _total = total;
  }

  /// 设置当前页码
  ///
  /// 用于服务端返回的页码与请求页码不一致的场景。
  @protected
  void setPage(int page) {
    _currentPage = page;
  }

  // ===== 父类方法覆写 =====

  /// 覆写父类 fetch，使其等价于 refreshData
  @override
  Future<void> fetch({bool preserveState = false}) =>
      refreshData(preserveState: preserveState);

  /// 覆写自动请求方法
  @override
  Future<void> performAutoFetch() async => refreshData();

  /// 实现父类 onFetch，调用 onFetchPage
  @override
  Future<EasyHttpResult<List<T>, E>> onFetch() => onFetchPage(_currentPage);

  /// 计算是否还有更多数据，子类可覆写
  ///
  /// 如果已通过 [setTotal] 设置了总数，则根据 total 精确计算；
  /// 否则使用默认策略：当前页数据量 >= pageSize 则认为还有更多。
  @protected
  bool computeHasMore(List<T> items, int page) {
    if (_total != null) {
      final loadedCount = (page - 1) * pageSize + items.length;
      return loadedCount < _total!;
    }
    return items.length >= pageSize;
  }

  /// 下拉刷新
  ///
  /// [preserveState] 默认 true：如果当前已经有可展示状态（success/empty/error），
  /// 刷新时不会切换到 loading，从而避免 UI 被 loading 覆盖；仅在首次加载
  /// （还没有任何可展示状态）时才会进入 loading。
  ///
  /// 当 [preserveState] 为 false：每次刷新都会进入 loading。
  Future<void> refreshData({bool preserveState = true}) async {
    if (_isRefreshing.value) return;

    _isRefreshing.value = true;
    _currentPage = 1;
    _loadMoreError.value = null;
    final hasUiState = status.isSuccess || status.isEmpty || status.isError;
    final preserve = preserveState && hasUiState;

    // preserveState=true 且当前在 error UI 时，不要清空 error，否则 obx 会拿到 null。
    if (!(preserve && status.isError)) {
      clearError();
    }

    if (!preserve) {
      change(null, status: RxStatus.loading());
    }

    try {
      final result = await onFetchPage(1);
      if (result.isSuccess) {
        clearError();
        final items = result.data ?? [];
        _hasMore.value = computeHasMore(items, 1);

        if (items.isEmpty) {
          change([], status: RxStatus.empty());
        } else {
          final processedItems = await onBeforeSuccess(items);
          final handled = onSuccessHandled(processedItems);
          if (!handled) {
            change(processedItems, status: RxStatus.success());
          }
        }
      } else {
        setError(result.error, StackTrace.current);
        if (result.error != null) {
          onError(result.error as E, StackTrace.current);
          final errorHandled =
              await onErrorHandled(result.error as E, StackTrace.current);
          if (!errorHandled && !preserve) {
            change([], status: RxStatus.error());
          }
        } else {
          if (!preserve) {
            change([], status: RxStatus.error());
          }
        }
      }
    } catch (e, stack) {
      E? typedError;
      try {
        typedError = mapError(e, stack);
      } catch (_) {
        typedError = null;
      }
      if (typedError != null) {
        setError(typedError, stack);
        onError(typedError, stack);
        final errorHandled = await onErrorHandled(typedError, stack);
        if (!errorHandled && !preserve) {
          change([], status: RxStatus.error());
        }
      } else {
        if (!preserve) {
          change([], status: RxStatus.error());
        }
      }
    } finally {
      _isRefreshing.value = false;
    }
  }

  /// 上拉加载更多
  Future<void> loadMore() async {
    if (_isLoadingMore.value) return;
    if (_isRefreshing.value) return;
    if (!_hasMore.value) return;

    _isLoadingMore.value = true;
    _loadMoreError.value = null;

    try {
      final result = await onFetchPage(_currentPage + 1);
      if (result.isSuccess) {
        final items = result.data ?? [];
        _currentPage++;
        _hasMore.value = computeHasMore(items, _currentPage);

        // 如果没有新数据，跳过 UI 更新避免不必要的 rebuild
        if (items.isEmpty) {
          // 约定：loadMore 成功但返回空列表，视为没有更多数据。
          // 同时触发钩子，便于外部组件（如上拉加载控件）切换到“无更多”状态。
          _hasMore.value = false;
          onLoadMoreNoMore();
          change(state, status: RxStatus.success());
          return;
        }

        final currentItems = state ?? [];
        final mergedItems = [...currentItems, ...items];
        final processedItems = await onBeforeLoadMore(mergedItems);
        final handled = onLoadMoreSuccessHandled(processedItems);
        if (!handled) {
          change(processedItems, status: RxStatus.success());
        }

        if (!_hasMore.value) {
          onLoadMoreNoMore();
        }
      } else {
        _loadMoreError.value = result.error;
        if (result.error != null) {
          onLoadMoreError(result.error as E, StackTrace.current);
        }
      }
    } catch (e, stack) {
      E? typedError;
      try {
        typedError = mapError(e, stack);
      } catch (_) {
        typedError = null;
      }
      if (typedError != null) {
        _loadMoreError.value = typedError;
        onLoadMoreError(typedError, stack);
      }
    } finally {
      _isLoadingMore.value = false;
    }
  }

  /// 子类实现：分页请求逻辑
  Future<EasyHttpResult<List<T>, E>> onFetchPage(int page);

  /// 加载更多错误处理钩子
  void onLoadMoreError(E error, StackTrace stack) {}

  /// 加载更多已无更多数据时的钩子
  ///
  /// 触发时机：
  /// - loadMore 成功但返回空列表（items.isEmpty）；
  /// - loadMore 成功后计算得到 hasMore=false（例如返回条数 < pageSize 或 total 已加载完）。
  ///
  /// 使用场景：对接第三方上拉/下拉组件的“没有更多”状态（例如调用某些 refresh controller 的
  /// `loadNoData()` / `finishLoad(noMore: true)` 之类 API）。
  void onLoadMoreNoMore() {}

  /// 刷新数据更新前的钩子
  @override
  @protected
  Future<List<T>> onBeforeSuccess(List<T> data) async => data;

  /// 加载更多数据更新前的钩子
  @protected
  Future<List<T>> onBeforeLoadMore(List<T> data) async => data;

  /// 加载更多成功处理钩子
  ///
  /// 返回 true 表示调用者已自行处理状态更新，框架不再调用 change。
  /// 返回 false 表示使用默认行为，框架自动调用 change。
  @protected
  bool onLoadMoreSuccessHandled(List<T> data) => false;

  /// 重置分页状态
  void resetPagination() {
    _currentPage = 1;
    _total = null;
    _hasMore.value = true;
    clearError();
    _loadMoreError.value = null;
  }

  /// 按条件删除列表项并刷新 UI
  ///
  /// [test] 返回 true 的项将被删除。
  /// 删除后自动更新状态：如果列表为空则设置 empty 状态。
  ///
  /// 示例：
  /// ```dart
  /// // 删除 id 为 123 的项
  /// controller.removeWhere((item) => item.id == '123');
  ///
  /// // 删除所有已读消息
  /// controller.removeWhere((msg) => msg.isRead);
  /// ```
  void removeWhere(bool Function(T item) test) {
    final currentItems = state;
    if (currentItems == null || currentItems.isEmpty) return;

    final newItems = currentItems.where((item) => !test(item)).toList();

    if (newItems.isEmpty) {
      change([], status: RxStatus.empty());
    } else {
      change(newItems, status: RxStatus.success());
    }

    // 同步更新 total
    if (_total != null) {
      final removedCount = currentItems.length - newItems.length;
      _total = _total! - removedCount;
    }
  }

  /// 便捷的 UI 构建方法：让 onError 直接拿到类型 [E] 的错误对象。
  Widget obx(
    NotifierBuilder<List<T>?> widget, {
    Widget? onLoading,
    Widget? onEmpty,
    Widget Function(E? error)? onError,
  }) {
    return SimpleBuilder(builder: (_) {
      if (status.isLoading) {
        return onLoading ?? const Center(child: CircularProgressIndicator());
      } else if (status.isError) {
        return onError != null
            ? onError(error)
            : Center(child: Text('A error occurred: $error'));
      } else if (status.isEmpty) {
        return onEmpty ?? const SizedBox.shrink();
      }
      return widget(value);
    });
  }

  @override
  void onClose() {
    _isRefreshing.close();
    _isLoadingMore.close();
    _hasMore.close();
    _loadMoreError.close();
    super.onClose();
  }
}
