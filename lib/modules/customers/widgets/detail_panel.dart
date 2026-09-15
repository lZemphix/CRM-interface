// import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

class DetailPanel extends StatefulWidget {
  const DetailPanel({super.key});

  @override
  State<DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<DetailPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Expanded(child: Container(color: Colors.blueGrey))],
    );
  }
}
