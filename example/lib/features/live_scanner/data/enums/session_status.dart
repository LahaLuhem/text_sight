/// The live camera session's lifecycle, as one state the view can switch on.
///
/// [preparingModel] comes first: the model is fetched (a no-op on iOS and with the bundled ML Kit
/// model) before the camera is requested. A refused permission splits into [denied] (retry re-asks)
/// and [permanentlyDenied] (settings only). [paused], and a [failed] after scanning began, come
/// from the controller's `sessionState`.
enum SessionStatus() {
  preparingModel,
  requesting,
  denied,
  permanentlyDenied,
  ready,
  paused,
  failed,
}
