import 'package:flutter/material.dart';
import 'region_selection_screen.dart'; // RegionSelectionScreen이 정의된 파일을 import 합니다.

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('금오캠핑'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '로그인',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // 로그인 로직 추가
              },
              child: const Text('로그인'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // 회원가입 화면으로 이동
                Navigator.pushNamed(context, '/signup');
              },
              child: const Text('회원가입'),
            ),
            const SizedBox(height: 16),
            // 아래 버튼을 눌러 바로 RegionSelectionScreen으로 이동할 수 있도록 추가
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegionSelectionScreen()),
                );
              },
              child: const Text('바로 지역 선택 화면으로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
