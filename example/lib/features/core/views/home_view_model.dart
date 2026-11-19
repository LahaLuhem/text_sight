import 'package:pmvvm/pmvvm.dart';

/// Nothing to observe, since navigating is all the hub does and that lives in the view. Kept so
/// every feature has the same view and view-model pair.
final class HomeViewModel() extends ViewModel;
