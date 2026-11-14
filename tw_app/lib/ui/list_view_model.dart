import 'package:material_ui/material_ui.dart';

class ListViewModel<T>({required final Future<List<T>> Function() _fetch}) extends ChangeNotifier {
  var _isLoading = false;
  var _hasError = false;
  var _isDisposed = false;
  var _items = <T>[];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<T> get items => _items;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _items = List<T>.unmodifiable(await _fetch());
    } on Exception {
      _hasError = true;
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
