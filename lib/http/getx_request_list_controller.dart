import 'package:easy_getx_widget/bean/load_type.dart';
import 'package:easy_getx_widget/bean/view_state_http_data.dart';
import 'package:easy_getx_widget/http/getx_request_controller.dart';
import 'package:easy_getx_widget/utils/easy_utils.dart';

abstract class GetXRequestListController<T, E>
    extends GetXRequestController<List<T>, E> {
  /// 是否还有更多数据
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  bool _hasPageSize = false;

  /// 页面大小，用于自动推断是否还有更多数据
  int _inferredPageSize = 0;

  /// 是否启用自动推断hasMore（当用户没有手动设置时）
  bool _autoInferHasMore = true;

  /// 当前页码，用于跟踪加载状态
  int _currentPage = 0;

  /// 刷新时是否清空数据
  bool getShouldClearRefresh() => true;

  /// 刷新错误时是否清空数据
  bool getShouldClearWhenRefreshError() => false;

  /// 获取是否启用自动推断hasMore
  bool getAutoInferHasMore() => _autoInferHasMore;

  /// 设置是否启用自动推断hasMore
  void setAutoInferHasMore(bool enable) {
    _autoInferHasMore = enable;
  }

  /// 手动设置hasMore（这将禁用自动推断）
  void setHasMore(bool hasMoreData) {
    _hasMore = hasMoreData;
    _autoInferHasMore = false;
  }

  /// 手动设置pageSize（这将启用更精确的hasMore推断）
  void setPageSize(int pageSize) {
    _inferredPageSize = pageSize;
    _hasPageSize = true;
  }

  /// 获取推断的页面大小
  int get pageSize => _inferredPageSize;

  GetXRequestListController() {
    data = [];
  }

  @override
  void handleHttpData(
      {required ViewStateHttpData<List<T>, E> httpData,
      required LoadType loadType}) {
    handleResult.call(httpData, loadType);
  }

  @override
  void handleResult(
      ViewStateHttpData<List<T>, E> httpData, LoadType loadType) async {
    if (httpData.success) {
      if (loadType == LoadType.refresh) {
        _currentPage = 1;
      } else if (loadType == LoadType.loadMore) {
        _currentPage++;
      }

      // 自动推断hasMore逻辑
      if (_autoInferHasMore) {
        _autoInferHasMoreLogic(httpData.data ?? [], loadType);
      }
      if (EasyUtil.isNotEmpty(httpData.data)) {
        if (loadType == LoadType.refresh && getShouldClearRefresh()) {
          data.clear();
        }
        await handleAddList(httpData, loadType);
        setStateByLoadType(loadType);
      } else if (loadType == LoadType.refresh) {
        if (isRefreshBusy) {
          setRefreshSuccessButEmpty();
        } else {
          setSuccessEmpty();
        }
      } else if (loadType == LoadType.loadMore) {
        if (isLoadMoreBusy) {
          setLoadMoreSuccessButEmpty();
        } else {
          refresh();
        }
      }
    } else {
      if (loadType == LoadType.refresh) {
        _currentPage = 0;
        if (getShouldClearWhenRefreshError()) {
          data.clear();
          refresh();
        }
      } else if (loadType == LoadType.loadMore) {
        // 加载更多失败时，页码回退
        _currentPage = _currentPage > 0 ? _currentPage - 1 : 0;
      }

      if (data.isEmpty) {
        setError(httpData.error);
      } else {
        if (isRefreshBusy && loadType == LoadType.refresh) {
          setRefreshError(httpData.error);
        } else if (isLoadMoreBusy && loadType == LoadType.loadMore) {
          setLoadMoreError(httpData.error);
        } else {
          refresh();
        }
      }
    }
  }

  Future<void> handleAddList(
      ViewStateHttpData<List<T>, E> httpData, LoadType loadType) async {
    // 添加新数据
    data.addAll(httpData.data!);
  }

  void setStateByLoadType(LoadType loadType) {
    if (isRefreshBusy && loadType == LoadType.refresh) {
      setRefreshSuccess();
    } else if (isLoadMoreBusy && loadType == LoadType.loadMore) {
      setLoadMoreSuccess();
    } else {
      setSuccess();
    }
  }

  /// 自动推断hasMore的核心逻辑
  void _autoInferHasMoreLogic(List<T> newData, LoadType loadType) {
    if (loadType == LoadType.refresh) {
      // 刷新时，如果没有设置pageSize，暂时不处理hasMore
      if (_inferredPageSize == 0) {
        _hasMore = true; // 假设还有更多数据，等待第二页来推断
      } else {
        // 如果已知pageSize，直接判断
        _hasMore = newData.length >= _inferredPageSize;
      }
    } else if (loadType == LoadType.loadMore) {
      if (_inferredPageSize == 0 && _currentPage == 2) {
        // 第二页加载时，推断第一页的数据长度为pageSize
        int firstPageSize = data.length - newData.length;
        if (firstPageSize > 0) {
          _inferredPageSize = firstPageSize;
        }
      }

      if (_inferredPageSize != 0) {
        // 如果当前页数据量小于pageSize，说明没有更多数据了
        _hasMore = newData.length >= _inferredPageSize;
      } else {
        // 如果还没有推断出pageSize，保持hasMore为true
        _hasMore = true;
      }
    }
  }

  /// 重置状态（在刷新时调用）
  void resetPaginationState() {
    _currentPage = 0;
    if (!_hasPageSize) {
      _inferredPageSize = 0;
    }
    _hasMore = true;
    _autoInferHasMore = true;
  }
}
