import 'package:flutter_test/flutter_test.dart';
import 'package:easy_getx_widget/easy_getx_widget.dart';

class TestController extends GetxController {
  final String id;
  TestController([this.id = 'default']);
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('EasyGetXExtension', () {
    group('getOrPut', () {
      test('应该创建新的 Controller 如果未注册', () {
        final controller = Get.getOrPut<TestController>(
          init: () => TestController('new'),
        );

        expect(controller, isNotNull);
        expect(controller.id, equals('new'));
        expect(Get.isRegistered<TestController>(), isTrue);
      });

      test('应该返回已存在的 Controller 如果已注册', () {
        final first = Get.put(TestController('first'));
        final second = Get.getOrPut<TestController>(
          init: () => TestController('second'),
        );

        expect(second, equals(first));
        expect(second.id, equals('first'));
      });

      test('应该支持 tag 参数', () {
        final controller1 = Get.getOrPut<TestController>(
          tag: 'tag1',
          init: () => TestController('tag1'),
        );
        final controller2 = Get.getOrPut<TestController>(
          tag: 'tag2',
          init: () => TestController('tag2'),
        );

        expect(controller1.id, equals('tag1'));
        expect(controller2.id, equals('tag2'));
        expect(controller1, isNot(equals(controller2)));
      });

      test('应该支持 permanent 参数', () {
        final controller = Get.getOrPut<TestController>(
          init: () => TestController(),
          permanent: true,
        );

        expect(controller, isNotNull);
      });
    });

    group('doIfRegistered', () {
      test('应该在 Controller 已注册时调用 onRegistered', () {
        final controller = Get.put(TestController('registered'));
        TestController? foundController;

        Get.doIfRegistered<TestController>(
          onRegistered: (c) => foundController = c,
        );

        expect(foundController, equals(controller));
      });

      test('应该在 Controller 未注册时调用 onNotRegistered', () {
        bool notRegisteredCalled = false;

        Get.doIfRegistered<TestController>(
          onNotRegistered: () => notRegisteredCalled = true,
        );

        expect(notRegisteredCalled, isTrue);
      });

      test('应该支持 tag 参数', () {
        Get.put(TestController('with-tag'), tag: 'myTag');
        TestController? foundController;

        Get.doIfRegistered<TestController>(
          tag: 'myTag',
          onRegistered: (c) => foundController = c,
        );

        expect(foundController?.id, equals('with-tag'));
      });
    });

    group('safeDelete', () {
      test('应该删除已注册的 Controller', () {
        Get.put(TestController());

        final result = Get.safeDelete<TestController>();

        expect(result, isTrue);
        expect(Get.isRegistered<TestController>(), isFalse);
      });

      test('应该在 Controller 未注册时返回 false', () {
        final result = Get.safeDelete<TestController>();

        expect(result, isFalse);
      });

      test('应该支持 tag 参数', () {
        Get.put(TestController(), tag: 'deleteTag');

        final result = Get.safeDelete<TestController>(tag: 'deleteTag');

        expect(result, isTrue);
        expect(Get.isRegistered<TestController>(tag: 'deleteTag'), isFalse);
      });

      test('应该支持 force 参数', () {
        Get.put(TestController());

        final result = Get.safeDelete<TestController>(force: true);

        expect(result, isTrue);
      });
    });
  });
}
