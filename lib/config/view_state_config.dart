class ViewStateConfig{

  static final ViewStateConfig _instance = ViewStateConfig._();

  factory ViewStateConfig() => _instance;

  ViewStateConfig._();

  // ViewStateConfig.init({
  //   Widget Function(BaseViewStateError viewState)? onBuildErrorWidget,
  //   Widget Function()? onBuildBusyWidget,
  // }){
  //   _instance = ViewStateConfig._();
  //   _instance.onBuildBusyWidget = onBuildBusyWidget;
  //   _instance.onBuildErrorWidget = onBuildErrorWidget;
  // }
  //
  //
  // ///------------------------------------------------定义一些状态切换配置-----------------------------------------------------------------
  // Widget Function(BaseViewStateError viewState)? onBuildErrorWidget;
  //
  // Widget Function()? onBuildBusyWidget;



}