import 'package:material_ui/material_ui.dart';
import 'package:tw_app/time/clock.dart';

/// Date picker which displays the selected date as text
class const DateFormField({
  super.key,
  super.initialValue,
  super.validator,
  super.onSaved,
  super.enabled,
  final String Function(DateTime?)? _format,
  required final DateTime _firstDate,
  required final DateTime _lastDate,
  final InputDecoration? _decoration = const InputDecoration(),
  final Clock _clock = const Clock(),
}) extends FormField<DateTime> {
  this : super(builder: _builder);

  @override
  FormFieldState<DateTime> createState() => _DateFormFieldState();

  static Widget _builder(FormFieldState<DateTime> state) =>
      (state as _DateFormFieldState)._buildInput();
}

class _DateFormFieldState extends FormFieldState<DateTime> {
  late final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.text = _formattedValue;
  }

  @override
  void didUpdateWidget(covariant DateFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._format != widget._format) _controller.text = _formattedValue;
  }

  String get _formattedValue {
    final format = widget._format;
    if (format != null) return format(value);
    final date = value;
    return date == null ? '' : MaterialLocalizations.of(context).formatShortDate(date);
  }

  @override
  void didChange(DateTime? value) {
    super.didChange(value);
    _controller.text = _formattedValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    _controller.text = _formattedValue;
  }

  @override
  DateFormField get widget => super.widget as DateFormField;

  Widget _buildInput() => TextField(
    controller: _controller,
    enabled: widget.enabled,
    readOnly: true,
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: value ?? widget._clock.now(),
        firstDate: widget._firstDate,
        lastDate: widget._lastDate,
      );
      if (!mounted || !widget.enabled || selected == null) return;
      didChange(selected);
    },
    decoration: (widget._decoration ?? const InputDecoration()).copyWith(errorText: errorText),
  );
}
