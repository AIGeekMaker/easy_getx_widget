/// Easy GetX Widget - 基于 GetX 的请求状态管理脚手架
///
/// 提供 [EasyRequestController] 和 [EasyListController] 两个核心控制器，
/// 使用 GetX 原生的 [StateMixin] 和 [RxStatus] 管理请求状态。
///
/// ## 快速开始
///
/// ### 单数据请求
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
///
/// // UI 层
/// controller.obx(
///   (user) => UserCard(user: user!),
///   onLoading: LoadingWidget(),
///   onEmpty: EmptyWidget(),
///   onError: (e) => ErrorWidget(e ?? 'unknown error'),
/// )
/// ```
///
/// ### 列表分页请求
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
///
/// // UI 层
/// controller.obx(
///   (articles) => RefreshIndicator(
///     onRefresh: controller.refreshData,
///     child: ListView.builder(...),
///   ),
///   onLoading: LoadingWidget(),
///   onEmpty: EmptyWidget(),
///   onError: (error) => ErrorWidget(error),
/// )
/// ```
library easy_getx_widget;

// 导出 GetX 核心
export 'package:get/get.dart' hide FormData, MultipartFile, Response;
export 'package:get/get_state_manager/get_state_manager.dart';

export 'src/controllers/easy_list_controller.dart';
// 导出新实现的控制器
export 'src/controllers/easy_request_controller.dart';
// 导出扩展工具
export 'src/extensions/getx_extensions.dart';
// 导出 HTTP 结果模型
export 'src/models/easy_http_result.dart';
