/// What the controller needs from the widget tree. The UI supplies the real
/// one; unit tests use `NoopNavigator` or a recording fake.
abstract class AppNavigator {
  void goPlay();
  void goHome();
  void showGameOver();
  void showPause();
  void showReroll();
  void dismissSheet();
  void showMessage(String text);
}

class NoopNavigator implements AppNavigator {
  const NoopNavigator();

  @override
  void goPlay() {}

  @override
  void goHome() {}

  @override
  void showGameOver() {}

  @override
  void showPause() {}

  @override
  void showReroll() {}

  @override
  void dismissSheet() {}

  @override
  void showMessage(String text) {}
}
