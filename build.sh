#!/bin/bash
export DART_VM_OPTIONS="--old_gen_heap_size=1024"
export NODE_OPTIONS="--max-old-space-size=2048"
cd app
../flutter/bin/flutter clean
../flutter/bin/flutter build web --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID"
