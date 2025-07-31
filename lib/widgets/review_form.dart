/// lib/widgets/review_form.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 리뷰 작성 폼 (별점 + 내용 입력 + 등록 버튼 + 사진 첨부 + 선택 이미지 삭제)
class ReviewForm extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController txtCtr;
  final VoidCallback onSubmit;
  final String? userNickname;

  // 이미지 첨부 관련 콜백 및 선택된 이미지 목록
  final VoidCallback onPickImages;
  final List<XFile> selectedImages;
  final ValueChanged<int> onRemoveImage; // 선택 이미지 삭제 콜백

  const ReviewForm({
    Key? key,
    required this.rating,
    required this.onRating,
    required this.txtCtr,
    required this.onSubmit,
    required this.userNickname,
    required this.onPickImages,
    required this.selectedImages,
    required this.onRemoveImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('리뷰 작성', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (userNickname != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('작성자: $userNickname', style: const TextStyle(color: Colors.grey)),
          ),
        Row(
          children: [
            const Text('평점:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: rating,
              items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged: (v) { if (v != null) onRating(v); },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: '사진 첨부',
              onPressed: onPickImages,
            ),
          ],
        ),
        if (selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedImages.length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(selectedImages[i].path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // X 버튼
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
