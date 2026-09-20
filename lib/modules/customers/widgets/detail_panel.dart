// import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

class DetailPanel extends StatelessWidget {
  const DetailPanel({
    super.key,
    required this.icon,
    required this.fullName,
    required this.status,
    required this.phoneNumber,
    required this.branch,
    this.lastVisit,
    required this.,
    required this.,

  });

  final IconData icon;
  final String fullName, status, phoneNumber, branch;
  final DateTime lastVisit = DateTime(year);

  @override
  Widget build(BuildContext context) {
    return Column(children: [customerCard(), summary()]);
  }

  Widget summary(
    DateTime lastVisit,
    DateTime nextActivity,
    String responsibleEmployee,
  ) {
    return Row(
      children: [
        summaryBlock("Последний контакт", lastVisit.toString()),
        summaryBlock("Следующее действие", nextActivity.toString()),
        summaryBlock("Ответственный", responsibleEmployee),
      ],
    );
  }

  Widget summaryBlock(String title, String description) {
    return Row(children: [Text(title), Text(description)]);
  }

  Widget customerCard() {
    return Row(
      children: [
        leftSide(icon, fullName, status, phoneNumber, branch),
        activitySide(),
      ],
    );
  }

  Widget activitySide() {
    return Row(
      children: [
        button("Позвонить", Colors.white, Colors.black),
        button("+ Задача", Colors.deepPurpleAccent, Colors.black),
        button("...", Colors.white, Colors.black),
      ],
    );
  }

  Widget button(String text, Color bgColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(color: bgColor),
      child: Text(text),
    );
  }

  Widget leftSide(
    IconData icon,
    String fullName,
    String status,
    String phoneNumber,
    String branch,
  ) {
    return Row(
      children: [
        Icon(icon),
        Column(
          children: [
            Text(fullName),
            Row(
              children: [
                Text(status),
                Text("-"),
                Text(phoneNumber),
                Text("-"),
                Text(branch),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
