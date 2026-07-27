// Web-only Razorpay Checkout using dart:js (JS interop for Flutter Web).
// This file handles the FIX for the "Pay Online crash" bug.

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
  _ensureScriptLoaded(() {
    _openCheckout(
      key: key,
      amount: amount,
      orderId: orderId,
      name: name,
      description: description,
      onSuccess: onSuccess,
      onError: onError,
      onDismiss: onDismiss,  // Fixed: was "on-dismiss" with hyphen
      prefill: prefill,
      theme: theme,
    );
  });
}

// Ensure the Razorpay Checkout script is loaded before proceeding.
void _ensureScriptLoaded(void Function() onComplete) {
  final existing = js.context['document']?.querySelector(
    r'script\[src="https://checkout\\.razorpay\\.com/v1/checkout\\.js"\]',
  );
  if (existing != null) {
    onComplete();
    return;
  }

  final doc = js.context['document'] as js.JsObject;
  final script = js.JsObject.jsify({'src': 'https://checkout.razorpay.com/v1/checkout.js'});

  // Set up load and error handlers
  script['onLoad'] = js.allowInterop(() => onComplete());
  script['onError'] = js.allowInterop(() => onComplete());

  // Append to head
  const headProp = 'head';
  final head = doc.callMethod(headProp);
  head.callMethod('appendChild', [script]);
}

// Perform the actual checkout opening after script is ready.
void _openCheckout({
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
  // Verify Razorpay global constructor exists
  final rzpConstructor = js.context['Razorpay'];
  if (rzpConstructor == null) {
    onError(-1, 'Razorpay SDK not available');
    return;
  }

  // Build options object — handler MUST be included here, not set on the
  // instance after construction. Razorpay reads it during instantiation.
  final options = js.JsObject.jsify({
    'key': key,
    'amount': amount,
    'name': name,
    'order_id': orderId,
    'description': description,
    'handler': js.allowInterop((dynamic response) {
      final resp = response as js.JsObject;
      final paymentId = resp['razorpay_payment_id']?.toString() ?? '';
      final orderIdResult = resp['razorpay_order_id']?.toString() ?? '';
      final signature = resp['razorpay_signature']?.toString() ?? '';
      onSuccess(paymentId, orderIdResult, signature);
    }),
    if (prefill != null && prefill.isNotEmpty) 'prefill': prefill,
    if (theme != null && theme.isNotEmpty) 'theme': theme,
  });

  // FIXED: Use callMethod('newInstance', [options]) instead of .newInstance([options])
  // This was the root cause of the original NoSuchMethodError crash.
  final rzp = rzpConstructor.callMethod('newInstance', [options]);

  // Set payment.failed callback
  rzp.callMethod('on', [
    'payment.failed',
    js.allowInterop((dynamic response) {
      final resp = response as js.JsObject;
      final error = resp['error'] as js.JsObject;
      final code = error['code'] as int? ?? 100;
      final msg = error['description']?.toString() ?? 'Unknown error';
      onError(code, msg);
    }),
  ]);

  // Set modal.ondismiss callback
  rzp.callMethod('on', [
    'modal.ondismiss',
    js.allowInterop(() => onDismiss()),
  ]);

  // Open checkout
  rzp.callMethod('open', []);
}
