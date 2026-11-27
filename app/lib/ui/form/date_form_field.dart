import 'package:material_ui/material_ui.dart';
import 'package:shared/time.dart';

/// Date picker which displays the selected date as text
class const DateFormField({
  super.key,
  super.initialValue,
  super.validator,
  super.onSaved,
  super.enabled,
  final String Function(CalendarDate?)? _format,
  final InputDecoration? _decoration = const InputDecoration(),
  final Now _now = DateTime.now,
}) extends FormField<CalendarDate> {
  static final _firstDate = DateTime(1900);
  static final _lastDate = DateTime(2100);

  this : super(builder: _builder);

  @override
  FormFieldState<CalendarDate> createState() => _DateFormFieldState();

  static Widget _builder(FormFieldState<CalendarDate> state) =>
      (state as _DateFormFieldState)._buildInput();
}

class _DateFormFieldState extends FormFieldState<CalendarDate> {
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
    return date == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(date.toLocalDateTime());
  }

  @override
  void didChange(CalendarDate? value) {
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
        initialDate: (value ?? CalendarDate.today(now: widget._now)).toLocalDateTime(),
        firstDate: DateFormField._firstDate,
        lastDate: DateFormField._lastDate,
      );
      if (!mounted || !widget.enabled || selected == null) return;
      didChange(CalendarDate.fromDateTime(selected));
    },
    decoration: (widget._decoration ?? const InputDecoration()).copyWith(errorText: errorText),
  );
}
