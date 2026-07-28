#!/bin/bash
cd app
../flutter/bin/flutter clean
../flutter/bin/flutter build web --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID"
