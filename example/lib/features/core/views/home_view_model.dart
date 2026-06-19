import 'package:pmvvm/pmvvm.dart';

/// The landing hub has no observable state — navigation is the only behaviour, and
/// `Navigator.push` lives in the view. The pair is kept for layout consistency with
/// every other feature.
final class HomeViewModel extends ViewModel {}
