import 'package:flutter/material.dart';

Widget squareButton(
  String text,
  Color bgColor,
  Color textColor,
  Color borderColor,
  double width,
  double height,
  VoidCallback? onPressed,
) {
  return TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      fixedSize: Size(width, height),
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadiusGeometry.circular(12),
      ),
    ),
    onPressed: onPressed,
    child: Text(text, style: TextStyle(color: textColor)),
  );
}
