import 'dart:math';

import 'package:easy_getx_widget/easy_getx_widget.dart';

extension ExtendGetX on GetInterface {
  GetxController getController<GetxController>(
      {String tag = '',
      required GetxController Function() init,
      bool isLazyPut = false,
      Function(GetxController controller)? doIfRegister,
      bool shouldDoWhenRegistering = false,
      bool permanent = false,
      bool shouldPut = true}) {
    GetxController controller;
    if (Get.isRegistered<GetxController>(tag: tag)) {
      controller = Get.find<GetxController>(tag: tag);
      doIfRegister?.call(controller);
    } else {
      controller = init.call();
      if (shouldDoWhenRegistering) {
        doIfRegister?.call(controller);
      }

      if (shouldPut) {
        if (isLazyPut) {
          Get.lazyPut<GetxController>(() => controller, tag: tag);
        } else {
          Get.put<GetxController>(controller, tag: tag, permanent: permanent);
        }
      }
    }
    return controller;
  }

  void doIfControllerRegister<T>(
      {String tag = '',
      Function(T controller)? doIfRegister,
      Function()? doIfUnRegister}) {
    if (Get.isRegistered<T>(tag: tag)) {
      doIfRegister?.call(Get.find<T>(tag: tag));
    } else {
      doIfUnRegister?.call();
    }
  }

  /// 生成一个唯一的tag
  String uniqueTag({int count = 3}) {
    String randomStr = Random().nextInt(10).toString();
    for (var i = 0; i < count; i++) {
      var str = Random().nextInt(10);
      randomStr = "$randomStr$str";
    }
    final timeNumber = DateTime.now().millisecondsSinceEpoch;
    final uuid = "$randomStr$timeNumber";
    return uuid;
  }
}
