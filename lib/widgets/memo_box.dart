// lib/widgets/memo_box.dart
import 'package:flutter/material.dart';

class MemoBox extends StatelessWidget {
  final String memoText;
  final VoidCallback onEdit;

  const MemoBox({super.key, required this.memoText, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              memoText.isNotEmpty ? memoText : '잊기 쉬운 내용을 남겨주세요!',
              style: TextStyle(
                color: memoText.isNotEmpty ? Colors.black : Colors.grey,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
        ],
      ),
    );
  }
}
