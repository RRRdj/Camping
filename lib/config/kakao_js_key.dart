import 'package:flutter/widgets.dart';

class KakaoJsKey extends InheritedWidget {
  final String jsKey;
  const KakaoJsKey({super.key, required this.jsKey, required Widget child})
    : super(child: child);

  static KakaoJsKey of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<KakaoJsKey>();
    assert(w != null, 'KakaoJsKey is not found above in the tree.');
    return w!;
  }

  @override
  bool updateShouldNotify(KakaoJsKey oldWidget) => jsKey != oldWidget.jsKey;
}
