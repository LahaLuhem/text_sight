/// Lifecycle of the live camera session, surfaced to the view as one switchable state.
///
/// [preparingModel] comes first: the on-device recognition model is fetched (a no-op on iOS and
/// with the bundled ML Kit model) before the camera is ever requested.
enum SessionStatus { preparingModel, requesting, denied, ready, failed }
