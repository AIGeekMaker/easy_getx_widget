import 'package:easy_getx_widget/bean/load_type.dart';
import 'package:easy_getx_widget/bean/view_state_http_data.dart';
import 'package:easy_getx_widget/bean/view_state_type.dart';
import 'package:easy_getx_widget/utils/easy_utils.dart';
import 'package:get/get.dart';

///用于定义状态切换框架的功能
abstract class BaseGetXRequestController<T, E> extends GetxController {
  bool getAutoRefresh() {
    return true;
  }

  Duration getDelayDuration() {
    return const Duration(milliseconds: 0);
  }

  bool isInit = false;

  ///------------------------------------------- 状态相关 --------------------------------------------------------
  void setBusy() {
    viewState = ViewStateType.busy;
    refresh();
  }

  void setSuccess() {
    if (EasyUtil.isEmpty(data)) {
      setSuccessEmpty();
      return;
    }
    viewState = ViewStateType.success;
    refresh();
  }

  void setSuccessEmpty() {
    viewState = ViewStateType.successEmpty;
    refresh();
  }

  void setError(E? e) {
    error = e;
    viewState = ViewStateType.error;
    refresh();
  }

  void setLoadMoreSuccess() {
    loadMoreState = ViewLoadMoreStateType.loadMoreSuccess;
    refresh();
    onLoadMoreSuccess();
  }

  void setLoadMoreBusy() {
    loadMoreState = ViewLoadMoreStateType.loadMoreBusy;
    refresh();
    onLoadMoreSuccess();
  }

  void setLoadMoreError(E? e) {
    loadMoreError = e;
    loadMoreState = ViewLoadMoreStateType.loadMoreError;
    refresh();
    onLoadMoreError();
  }

  void setLoadMoreSuccessButEmpty() {
    loadMoreState = ViewLoadMoreStateType.loadMoreSuccessButEmpty;
    refresh();
    onLoadMoreSuccessButEmpty();
  }

  void setRefreshBusy() {
    refreshState = ViewRefreshStateType.refreshBusy;
    refresh();
    onRefreshBusy();
  }

  void setRefreshError(E? e) {
    refreshError = e;
    refreshState = ViewRefreshStateType.refreshError;
    refresh();
    onRefreshError();
  }

  void setRefreshSuccess() {
    refreshState = ViewRefreshStateType.refreshSuccess;
    refresh();
    onRefreshSuccess();
  }

  void setRefreshSuccessButEmpty() {
    refreshState = ViewRefreshStateType.refreshSuccessButEmpty;
    refresh();
    onRefreshSuccessButEmpty();
  }

  void handleHttpData(
      {required ViewStateHttpData<T, E> httpData, required LoadType loadType}) {
    if (httpData.success) {
      data = httpData.data as T;
      setSuccess();
    } else {
      setError(httpData.error);
    }

    if (isSuccess) {
      handleResult.call(httpData, loadType);
    } else {
      handleError(httpData, loadType);
    }

    if (loadType == LoadType.refresh) {
      isInit = true;
    }
  }

  ViewStateType viewState = ViewStateType.none;

  bool get isBusy => viewState == ViewStateType.busy;

  bool get isSuccess => viewState == ViewStateType.success;

  bool get isSuccessEmpty => viewState == ViewStateType.successEmpty;

  bool get isError => viewState == ViewStateType.error;

  ///---------------------------------------------------------------------------------------------------

  ///下拉刷新，上拉加载应该分开控制
  ViewRefreshStateType refreshState = ViewRefreshStateType.none;

  ViewLoadMoreStateType loadMoreState = ViewLoadMoreStateType.none;

  bool get isRefreshSuccess =>
      refreshState == ViewRefreshStateType.refreshSuccess;

  bool get isRefreshBusy => refreshState == ViewRefreshStateType.refreshBusy;

  bool get isRefreshError => refreshState == ViewRefreshStateType.refreshError;

  bool get isRefreshSuccessButEmpty =>
      refreshState == ViewRefreshStateType.refreshSuccessButEmpty;

  bool get isLoadMoreSuccess =>
      loadMoreState == ViewLoadMoreStateType.loadMoreSuccess;

  bool get isLoadMoreBusy =>
      loadMoreState == ViewLoadMoreStateType.loadMoreBusy;

  bool get isLoadMoreSuccessButEmpty =>
      loadMoreState == ViewLoadMoreStateType.loadMoreSuccessButEmpty;

  bool get isLoadMoreError =>
      loadMoreState == ViewLoadMoreStateType.loadMoreError;

  void handleResult(ViewStateHttpData<T, E> httpData, LoadType loadType) {}

  void handleError(ViewStateHttpData<T, E> httpData, LoadType loadType) {}

  ///---------------------------------------------------------------------------------------------------

  ///-------------------------------下拉刷新状态回调----------------------------------------
  void onRefreshSuccess() {}

  void onRefreshError() {}

  void onRefreshSuccessButEmpty() {}

  void onRefreshBusy() {}

  void onLoadMoreSuccess() {}

  void onLoadMoreError() {}

  void onLoadMoreSuccessButEmpty() {}

  ///------------------------------------------- 请求相关 --------------------------------------------------------

  late T data;

  E? error;

  E? loadMoreError;

  E? refreshError;

  ///请求url
  String url = '';

  ///请求唯一标记
  String tag = '';

  ///刷新前
  void beforeRefresh() {}

  ///加载更多前
  void beforeLoadMore() {}

  Future<ViewStateHttpData<T, E>> refreshData();

  Future<ViewStateHttpData<T, E>> loadMoreData() {
    return Future.value(ViewStateHttpData());
  }
}
