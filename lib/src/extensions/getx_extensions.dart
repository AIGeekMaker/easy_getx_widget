import 'package:get/get.dart';

/// GetX 扩展工具
///
/// 提供简化的 Controller 查找和注册方法。
extension EasyGetXExtension on GetInterface {
  /// 获取或创建 Controller
  ///
  /// 如果 Controller 已注册，返回已有实例；
  /// 否则使用 [init] 创建新实例并注册。
  ///
  /// [tag] - 可选的标识符，用于区分同类型的多个实例
  /// [init] - 创建 Controller 的工厂函数
  /// [permanent] - 是否永久保留（不会被自动销毁）
  T getOrPut<T extends GetxController>({
    String? tag,
    required T Function() init,
    bool permanent = false,
  }) {
    if (Get.isRegistered<T>(tag: tag)) {
      return Get.find<T>(tag: tag);
    }
    return Get.put<T>(init(), tag: tag, permanent: permanent);
  }

  /// 如果 Controller 已注册，执行回调
  ///
  /// [tag] - 可选的标识符
  /// [onRegistered] - Controller 已注册时的回调
  /// [onNotRegistered] - Controller 未注册时的回调
  void doIfRegistered<T extends GetxController>({
    String? tag,
    void Function(T controller)? onRegistered,
    void Function()? onNotRegistered,
  }) {
    if (Get.isRegistered<T>(tag: tag)) {
      onRegistered?.call(Get.find<T>(tag: tag));
    } else {
      onNotRegistered?.call();
    }
  }

  /// 安全地删除 Controller
  ///
  /// 只有当 Controller 已注册时才执行删除操作。
  bool safeDelete<T extends GetxController>({String? tag, bool force = false}) {
    if (Get.isRegistered<T>(tag: tag)) {
      Get.delete<T>(tag: tag, force: force);
      return true;
    }
    return false;
  }
}
