#!/bin/bash

# Deploy Firebase Security Rules
# This script deploys both Firestore and Storage security rules

echo "🔐 Deploying Firebase Security Rules..."

# Deploy Firestore rules
echo "📝 Deploying Firestore security rules..."
firebase deploy --only firestore:rules

# Deploy Storage rules  
echo "💾 Deploying Storage security rules..."
firebase deploy --only storage

echo "✅ Firebase security rules deployed successfully!"
echo ""
echo "🔍 Rules deployed:"
echo "  - Firestore: User isolation for all collections including logging_summary"
echo "  - Storage: User-specific logging files in /logging/{userId}.txt"
echo "  - Storage: User-specific audio files in /audio/{userId}/"
echo ""
echo "📁 Log files structure:"
echo "  - Location: Firebase Storage /logging/{userId}.txt"
echo "  - Format: [YYYY-MM-DD HH:mm:ss] event_name | {json_details}"
echo "  - Summary: Firestore /logging_summary/{userId}" 