import 'package:flutter/material.dart';

class BannerWidget extends StatelessWidget {
  final Color color, borderColor, iconColor, textColor;
  final IconData icon;
  final String text;

  const BannerWidget({
    super.key,
    required this.color, required this.borderColor,
    required this.icon, required this.iconColor,
    required this.text, required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}