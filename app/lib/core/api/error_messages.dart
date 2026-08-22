/// Message shown when a request never produced a server envelope
/// (timeout, connection refused, no route to host).
const String networkUnreachableMessage =
    "Cannot reach server. Is the backend running?";

/// Fallback for codes we don't recognise and that carry no server message.
const String genericErrorMessage = "Something went wrong. Please try again.";

/// ARCHITECTURE §4 error codes → user-facing copy (Task 2.4),
/// plus NETWORK for transport-level failures.
const Map<String, String> apiErrorMessages = {
  "VALIDATION_ERROR": "Please check your details and try again.",
  "UNAUTHORIZED": "Please log in again.",
  "FORBIDDEN": "You don't have permission to do that.",
  "NOT_FOUND": "We couldn't find that.",
  "RIDE_INVALID_TRANSITION": "That ride can't be updated from its current state.",
  "RIDE_BUSY_DRIVER": "This driver is busy right now. Try another one.",
  "RIDE_BUSY_CUSTOMER": "You already have an active ride.",
  "DRIVER_NOT_VERIFIED": "Your account isn't verified yet. Please wait for approval.",
  "NETWORK": networkUnreachableMessage,
};

/// Friendly message a screen should show for an API error [code].
/// Known codes get their curated copy; unknown codes fall back to
/// [serverMessage] when the server explained itself, else to a generic one.
String errorMessageFor(String code, {String? serverMessage}) {
  final mapped = apiErrorMessages[code];
  if (mapped != null) return mapped;
  if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
  return genericErrorMessage;
}
