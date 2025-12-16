class ViewStateHttpData<T, E>{

  String code = '';

  T? data;

  E? error;

  String url = '';

  String _tag = '';

  String get tag => _tag.isNotEmpty? _tag : url;

  set tag(String value) {
    _tag = value;
  }

  bool success = false;
}