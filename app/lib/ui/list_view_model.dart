import 'package:material_ui/material_ui.dart';

class ListViewModel<T>({required final Future<List<T>> Function() _fetch}) extends ChangeNotifier {
  var _isLoading = false;
  var _hasError = false;
  var _isDisposed = false;
  var _loadId = 0;
  var _items = <T>[];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<T> get items => _items;

  Future<void> load() async {
    if (_isDisposed) return;
    final loadId = ++_loadId;
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final items = await _fetch();
      if (!_isCurrentLoad(loadId)) return;
      _items = List<T>.unmodifiable(items);
    } on Exception {
      if (_isCurrentLoad(loadId)) _hasError = true;
    } finally {
      if (_isCurrentLoad(loadId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentLoad(int loadId) => !_isDisposed && loadId == _loadId;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    super.dispose();
  }
}
