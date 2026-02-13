import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/easy_http_result.dart';

/// 单数据请求控制器基类
///
/// 使用 GetX 原生的 [StateMixin] 和 [RxStatus] 管理请求状态。
///
/// 使用示例：
/// ```dart
/// class UserController extends EasyRequestController<User, String> {
///   @override
///   Future<EasyHttpResult<User, String>> onFetch() async {
///     final response = await api.getUser();
///     if (response.success) {
///       return EasyHttpResult.ok(response.data);
///     }
///     return EasyHttpResult.err(response.message);
///   }
/// }
/// ```
abstract class EasyRequestController<T, E> extends GetxController
    with StateMixin<T> {
  final Rxn<E> _error = Rxn<E>();
  final Rxn<StackTrace> _errorStack = Rxn<StackTrace>();

  /// 最近一次请求失败的错误对象（完整类型 E）
  E? get error => _error.value;

  /// 最近一次请求失败的堆栈
  StackTrace? get errorStack => _errorStack.value;

  /// 是否在 onReady 时自动执行首次请求
  bool get autoFetch => true;

  /// 首次请求的延迟时间
  Duration get fetchDelay => Duration.zero;

  /// 防止并发请求的标志
  bool _isFetching = false;

  /// 是否正在执行请求
  bool get isFetching => _isFetching;

  /// 清除错误状态
  @protected
  void clearError() {
    _error.value = null;
    _errorStack.value = null;
  }

  /// 设置错误状态
  @protected
  void setError(E? error, StackTrace stack) {
    _error.value = error;
    _errorStack.value = stack;
  }

  /// 将捕获到的异常对象转换为类型 [E]。
  ///
  /// 默认实现等同于 `error as E`：
  /// - 如果你希望 [E] 就是你实际 throw 的类型（如 Exception / DioException / Failure），直接设置泛型即可；
  /// - 如果你希望将任意异常映射到你的领域错误类型，请重写此方法。
  @protected
  E mapError(Object error, StackTrace stack) => error as E;

  /// 自动请求时执行的方法，子类可覆写
  @protected
  Future<void> performAutoFetch() async => fetch();

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

  /// 执行请求
  ///
  /// [preserveState] 为 true 时：
  /// - 如果当前已经有可展示状态（success/empty/error），则不切换到 loading
  /// - 请求失败时保留原状态/原数据（UI 不会被 error 覆盖）
  Future<void> fetch({bool preserveState = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    final hasUiState = status.isSuccess || status.isEmpty || status.isError;
    final preserve = preserveState && hasUiState;

    // preserveState=true 且当前在 error UI 时，不要清空 error，否则 obx 会拿到 null。
    if (!(preserve && status.isError)) {
      clearError();
    }

    // 策略：是否显示 loading
    if (!preserve) {
      change(null, status: RxStatus.loading());
    }

    try {
      final result = await onFetch();
      if (result.isSuccess) {
        clearError();
        if (isEmptyData(result.data)) {
          change(null, status: RxStatus.empty());
        } else {
          final processedData = await onBeforeSuccess(result.data as T);
          final handled = onSuccessHandled(processedData);
          if (!handled) {
            change(processedData, status: RxStatus.success());
          }
        }
      } else {
        final currentStack = StackTrace.current;
        setError(result.error, currentStack);
        if (result.error != null) {
          onError(result.error as E, currentStack);
          final errorHandled =
              await onErrorHandled(result.error as E, currentStack);
          // 策略：错误时是否保留数据
          if (!errorHandled && !preserve) {
            change(null, status: RxStatus.error());
          }
        } else {
          // 策略：错误时是否保留数据
          if (!preserve) {
            change(null, status: RxStatus.error());
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
        // 策略：错误时是否保留数据
        if (!errorHandled && !preserve) {
          change(null, status: RxStatus.error());
        }
      } else {
        // 策略：错误时是否保留数据
        if (!preserve) {
          change(null, status: RxStatus.error());
        }
      }
    } finally {
      _isFetching = false;
    }
  }

  /// 子类实现：实际请求逻辑
  Future<EasyHttpResult<T, E>> onFetch();

  /// 错误处理钩子
  void onError(E error, StackTrace stack) {}

  /// 错误处理钩子，在 [onError] 之后调用。
  ///
  /// 返回 true 表示调用者已自行处理状态更新，框架不再调用 change。
  /// 返回 false 表示使用默认行为，框架自动调用 change。
  ///
  /// 使用场景：需要根据错误内容决定是否走错误流程，或自定义状态更新逻辑。
  ///
  /// 支持异步操作，例如：
  /// - 显示确认对话框让用户决定如何处理
  /// - 执行 token 刷新等异步恢复操作
  /// - 异步日志记录或错误上报
  @protected
  Future<bool> onErrorHandled(E error, StackTrace stack) async => false;

  /// 数据更新前的钩子，在设置 [RxStatus.success] 状态前调用。
  ///
  /// 可用于：
  /// - 数据转换/过滤
  /// - 缓存写入
  /// - 日志记录
  ///
  /// 返回处理后的数据，将用于更新状态。
  @protected
  Future<T> onBeforeSuccess(T data) async => data;

  /// 成功处理钩子，在 [onBeforeSuccess] 之后调用。
  ///
  /// 返回 true 表示调用者已自行处理状态更新，框架不再调用 change。
  /// 返回 false 表示使用默认行为，框架自动调用 change。
  ///
  /// 使用场景：需要根据数据内容决定是否走成功流程，或自定义状态更新逻辑。
  @protected
  bool onSuccessHandled(T data) => false;

  /// 便捷的 UI 构建方法：让 onError 直接拿到类型 [E] 的错误对象，而不是 String。
  ///
  /// 注意：GetX 原生的 `obx` 在错误回调中只提供 `String?`（RxStatus 的 errorMessage）。
  /// 这里通过读取 [error] 来向 UI 提供完整错误对象。
  Widget obx(
    NotifierBuilder<T?> widget, {
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
        // Also can be widget(null); but is risky
        return onEmpty ?? const SizedBox.shrink();
      }
      return widget(value);
    });
  }

  /// 判断数据是否为空，子类可覆写
  @protected
  bool isEmptyData(T? data) {
    if (data == null) return true;
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }

  @override
  void onClose() {
    _error.close();
    _errorStack.close();
    super.onClose();
  }
}
