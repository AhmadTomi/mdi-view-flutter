import 'package:flutter/material.dart';

class CalculatorWidget extends StatefulWidget {
  const CalculatorWidget({super.key});

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _output = "0";
  String _expression = "";
  double _num1 = 0;
  double _num2 = 0;
  String _operand = "";

  void _buttonPressed(String buttonText) {
    if (buttonText == "C") {
      _output = "0";
      _expression = "";
      _num1 = 0;
      _num2 = 0;
      _operand = "";
    } else if (buttonText == "+" || buttonText == "-" || buttonText == "*" || buttonText == "/") {
      _num1 = double.tryParse(_output) ?? 0;
      _operand = buttonText;
      _expression = "$_output $buttonText ";
      _output = "0";
    } else if (buttonText == "=") {
      _num2 = double.tryParse(_output) ?? 0;
      _expression += _output;

      if (_operand == "+") {
        _output = (_num1 + _num2).toString();
      }
      if (_operand == "-") {
        _output = (_num1 - _num2).toString();
      }
      if (_operand == "*") {
        _output = (_num1 * _num2).toString();
      }
      if (_operand == "/") {
        _output = _num2 == 0 ? "Error" : (_num1 / _num2).toString();
      }

      // Format decimal points nicely
      if (_output.endsWith(".0")) {
        _output = _output.substring(0, _output.length - 2);
      }

      _operand = "";
    } else {
      if (_output == "0" || _output == "Error") {
        _output = buttonText;
      } else {
        _output = _output + buttonText;
      }
    }

    setState(() {});
  }

  Widget _buildButton(String buttonText, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF262626),
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onPressed: () => _buttonPressed(buttonText),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Display
        Expanded(
          child: Container(
            color: Colors.grey.shade900,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _expression,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  _output,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Pad
        Container(
          color: const Color(0xFF0F0F0F),
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Row(
                children: [
                  _buildButton("7"),
                  _buildButton("8"),
                  _buildButton("9"),
                  _buildButton("/", color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: [
                  _buildButton("4"),
                  _buildButton("5"),
                  _buildButton("6"),
                  _buildButton("*", color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: [
                  _buildButton("1"),
                  _buildButton("2"),
                  _buildButton("3"),
                  _buildButton("-", color: Colors.orange, textColor: Colors.white),
                ],
              ),
              Row(
                children: [
                  _buildButton("C", color: Colors.red.shade900),
                  _buildButton("0"),
                  _buildButton("=", color: Colors.green.shade800),
                  _buildButton("+", color: Colors.orange, textColor: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
