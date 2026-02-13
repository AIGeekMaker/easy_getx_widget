/// 通用 HTTP 请求结果封装
///
/// 通过 [error] == null 判断请求是否成功。
///
/// 使用示例：
/// ```dart
/// Future<EasyHttpResult<User, String>> onFetch() async {
///   final response = await api.getUser();
///   if (response.success) {
///     return EasyHttpResult(data: response.data);
///   } else {
///     return EasyHttpResult(error: response.message);
///   }
/// }
/// ```
class EasyHttpResult<T, E> {
  /// 成功时的数据
  final T? data;

  /// 失败时的错误
  final E? error;

  const EasyHttpResult({
    this.data,
    this.error,
  });

  /// 请求是否成功（error == null）
  bool get isSuccess => error == null;

  /// 请求是否失败（error != null）
  bool get isError => error != null;

  /// 成功结果的工厂构造
  factory EasyHttpResult.ok(T data) => EasyHttpResult(data: data);

  /// 失败结果的工厂构造
  factory EasyHttpResult.err(E error) => EasyHttpResult(error: error);

  @override
  String toString() {
    if (isSuccess) {
      return 'EasyHttpResult.ok($data)';
    } else {
      return 'EasyHttpResult.err($error)';
    }
  }
}
