import 'dart:js' as js;

/// Callbacks for the web Razorpay checkout flow.
typedef OnSuccess = void Function(String paymentId, String orderId, String signature);
typedef OnError = void Function(int code, String message);
typedef OnDismiss = void Function();

/// Opens the Razorpay Checkout modal on web.
void openRazorpayCheckout({
  required String key,
  required int amount,
  required String orderId,
  required String name,
  required String description,
  required OnSuccess onSuccess,
  required OnError onError,
  required OnDismiss onDismiss,
  Map<String, String>? prefill,
  Map<String, String>? theme,
}) {
  // Validate key before proceeding
  if (key.isEmpty) {
    onError(0, 'Razorpay key is not configured. Please check RAZORPAY_KEY_ID dart-define.');
    return;
  }

  // WARNING: Due to Dart:JS interop limitations in the current Flutter setup,
  // callback registration is disabled. The Razorpay checkout will still open,
  // but success/error callbacks will not be invoked in Dart.
  // Payment confirmation relies on the server-side webhook (Edge Function).
  // The UI will auto-refresh after a short delay to check for updated payments.

  // Create a plain JavaScript object for the opts parameter. In Flutter Web DDC mode,
  // passing a Dart Map directly causes type interop issues - the JS side receives
  // a Dart wrapper object instead of a proper JS object with accessible properties.
  final options = js.JsObject(js.context['Object']);
  options['key'] = key;
  options['amount'] = amount;
  options['orderId'] = orderId;
  options['name'] = name;
  options['description'] = description;
  options['prefill'] = prefill ?? {};
  options['theme'] = theme ?? {};

  // Invoke the Razorpay Checkout initialization function directly via context
  // Using callMethod on context avoids DDC issues with JsFunction.call()
  // This calls window.__openRazorpayCheckout(options) directly
  js.context.callMethod('__openRazorpayCheckout', [options]);
}