import 'package:easy_getx_widget/base/base_getx_request_controller.dart';
import 'package:easy_getx_widget/bean/load_type.dart';
import 'package:easy_getx_widget/bean/view_state_http_data.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';

abstract class GetXRequestController<T, E>
    extends BaseGetXRequestController<T, E> {
  @override
  void onReady() {
    if (getAutoRefresh()) {
      setBusy();
    }
    void doOnReady() {
      if (getAutoRefresh()) {
        realRefreshData();
      }
    }

    if (getDelayDuration().inSeconds == 0) {
      doOnReady.call();
    } else {
      Future.delayed(getDelayDuration(), () {
        doOnReady.call();
      });
    }
    isInit = true;
  }

  Future<ViewStateHttpData<T, E>> realRefreshData() async {
    if (!isBusy && isInit) {
      refreshError = null;
      setRefreshBusy();
    }
    beforeRefresh();
    ViewStateHttpData<T, E> httpData = await refreshData();
    handleHttpData(httpData: httpData, loadType: LoadType.refresh);
    return httpData;
  }

  Future<ViewStateHttpData<T, E>> realLoadMoreData() async {
    if (!isBusy && isInit) {
      loadMoreError = null;
      setLoadMoreBusy();
    }
    beforeLoadMore();
    ViewStateHttpData<T, E> httpData = await loadMoreData();
    handleHttpData(httpData: httpData, loadType: LoadType.loadMore);
    return httpData;
  }

  ///------------------------------------------- 防抖 --------------------------------------------------------

  void debounceSuccess() {
    _debounceSuccess.value = _debounceSuccess.value + 1;
  }

  void deBounceTasks() {
    _counter.value = _counter.value + 1;
  }

  List<Function> getDeBounceTasks() {
    return [realRefreshData];
  }

  Duration getDeBounceDuration() {
    return const Duration(milliseconds: 800);
  }

  Duration getDeBounceSuccessDuration() {
    return const Duration(milliseconds: 500);
  }

  final RxInt _counter = 0.obs;

  final RxInt _debounceSuccess = 0.obs;

  @override
  void onInit() {
    super.onInit();
    debounce(_counter, (callback) {
      getDeBounceTasks().forEach((element) {
        element.call();
      });
    }, time: getDeBounceDuration());

    debounce(_debounceSuccess, (callback) {
      setSuccess();
    }, time: getDeBounceSuccessDuration());
  }

  @override
  void onClose() {
    _counter.close();
    _debounceSuccess.close();
  }
}
