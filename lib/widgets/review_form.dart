/// lib/widgets/review_form.dart
import 'package:flutter/material.dart';

/// 리뷰 작성 폼 (별점 + 내용 입력 + 등록 버튼)
class ReviewForm extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController txtCtr;
  final VoidCallback onSubmit;
  final String? userNickname;

  const ReviewForm({
    Key? key,
    required this.rating,
    required this.onRating,
    required this.txtCtr,
    required this.onSubmit,
    required this.userNickname,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리뷰 작성',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (userNickname != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '작성자: $userNickname',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        Row(
          children: [
            const Text('평점:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: rating,
              items: List.generate(
                5,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (v) {
                if (v != null) onRating(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: txtCtr,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '내용',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(onPressed: onSubmit, child: const Text('등록')),
        ),
      ],
    );
  }
}
