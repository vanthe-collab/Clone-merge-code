import 'dart:math' as math;
import 'package:flutter/material.dart';

class HostRangeInput extends StatefulWidget {
  const HostRangeInput({
    super.key,
    required this.label,
    required this.unit,
    required this.values,
    required this.sliderMax,
    required this.onChanged,
    this.minimum = 0,
    this.limit = 1000000000,
  });
  final String label, unit;
  final RangeValues values;
  final double sliderMax, minimum, limit;
  final ValueChanged<RangeValues> onChanged;
  @override
  State<HostRangeInput> createState() => _HostRangeInputState();
}

class _HostRangeInputState extends State<HostRangeInput> {
  late final TextEditingController low, high;
  String number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  @override
  void initState() {
    super.initState();
    low = TextEditingController(text: number(widget.values.start));
    high = TextEditingController(text: number(widget.values.end));
  }

  @override
  void dispose() {
    low.dispose();
    high.dispose();
    super.dispose();
  }

  void typed(String _) {
    final a = double.tryParse(low.text), b = double.tryParse(high.text);
    if (a != null &&
        b != null &&
        a.isFinite &&
        b.isFinite &&
        a >= widget.minimum &&
        b >= a &&
        b <= widget.limit) {
      widget.onChanged(RangeValues(a, b));
    }
  }

  Widget input(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: widget.unit),
    onChanged: typed,
    validator: (_) {
      final a = double.tryParse(low.text), b = double.tryParse(high.text);
      if (a == null ||
          b == null ||
          !a.isFinite ||
          !b.isFinite ||
          a < widget.minimum ||
          b < a ||
          b > widget.limit) {
        return 'Nhập khoảng hợp lệ: tối đa ≥ tối thiểu';
      }
      return null;
    },
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: input(low, 'Tối thiểu')),
          const SizedBox(width: 12),
          Expanded(child: input(high, 'Tối đa')),
        ],
      ),
      RangeSlider(
        values: widget.values,
        min: widget.minimum,
        max: math.max(widget.sliderMax, widget.values.end),
        labels: RangeLabels(
          number(widget.values.start),
          number(widget.values.end),
        ),
        onChanged: (values) {
          final rounded = RangeValues(
            values.start.roundToDouble(),
            values.end.roundToDouble(),
          );
          low.text = number(rounded.start);
          high.text = number(rounded.end);
          widget.onChanged(rounded);
        },
      ),
    ],
  );
}
