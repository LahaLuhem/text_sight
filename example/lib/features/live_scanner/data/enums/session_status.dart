/// Lifecycle of the live camera session, surfaced to the view as one switchable state.
///
/// [preparingModel] comes first: the on-device recognition model is fetched (a no-op on iOS and
/// with the bundled ML Kit model) before the camera is ever requested. A refused camera permission
/// splits into [denied] (the prompt can be shown again, retry re-asks) and [permanentlyDenied]
/// (only the system settings can grant it now). [paused], and a [failed] after scanning began, come
/// from the controller's `sessionState`.
enum SessionStatus { preparingModel, requesting, denied, permanentlyDenied, ready, paused, failed }
