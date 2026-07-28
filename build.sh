#!/bin/bash
export DART_VM_OPTIONS="--max-old-space-size=2560"
cd app
../flutter/bin/flutter clean
../flutter/bin/flutter build web --release --web-renderer canvakit --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID"
