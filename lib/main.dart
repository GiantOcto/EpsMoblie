import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/yone.jpg'), // 이미지
            Text(
              '치이카와',
              style: TextStyle(
                fontSize: 50,         // 글자 크기
                color: Colors.pink,   // 글자 색상
                fontWeight: FontWeight.bold, // 글자 굵게
                fontStyle: FontStyle.italic, // 기울이기
              ),
            )          // 텍스트
          ],
        ),
      ),
    );
  }
}
