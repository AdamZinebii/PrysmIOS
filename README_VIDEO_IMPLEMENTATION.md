# TikTok-Style Video Implementation

This document describes the new TikTok-style video feature that has replaced the Discovery View in the PrysmIOS app.

## Overview

The app now features a vertical video feed similar to TikTok, where users can scroll through videos generated from their news articles. Each video has a thumbnail background and TTS (Text-to-Speech) narration of the article summary.

## Architecture

### Backend Components

#### Video Generation Function (`main.py`)
- **Function**: `generate_video_from_text_and_thumbnail`
- **Purpose**: Creates MP4 videos with article thumbnails as background and TTS audio
- **Storage**: Videos are saved to Firebase Storage
- **Database**: Video metadata is stored in Firestore collection `VideoCacheLink`

#### API Endpoints
1. **`generate_article_videos`** - Creates new videos from user's news articles
2. **`get_user_video_cache`** - Retrieves user's video collection
3. **`clear_user_video_cache`** - Removes all videos for a user

### iOS Components

#### New Files Added:

1. **`VideoModels.swift`**
   - `VideoItem`: Represents a single video with metadata
   - `VideoCacheResponse`: API response structure
   - `GenerateVideosRequest/Response`: Request/response models

2. **`VideoAPIService.swift`**
   - Handles all video-related API calls
   - Follows the same pattern as `TrackerAPIService`
   - Includes proper error handling and authentication

3. **`TikTokVideoView.swift`**
   - Main video player interface
   - Vertical scrolling with `TabView` and `PageTabViewStyle`
   - Video controls and overlays
   - Empty state and loading states

#### Files Modified:

1. **`PrysmIOSApp.swift`**
   - Replaced `DiscoverView` with `TikTokVideoView`
   - Updated tab icon and title from "Discover" to "Videos"
   - Added `AVKit` import for video playback

2. **`DiscoverView.swift`** - **DELETED**
   - Original discovery view removed completely

## Features

### Video Player
- **Vertical Scrolling**: Swipe up/down to navigate between videos
- **Auto-play**: Videos start playing automatically when in view
- **Tap to Pause/Play**: Tap video to toggle playback
- **Video Metadata**: Article title and creation date overlay

### Controls
- **Generate Videos**: Button to create new videos from latest articles
- **Refresh**: Reload video cache
- **Clear Cache**: Remove all user videos
- **Loading States**: Proper loading indicators during operations

### Empty State
- Helpful message when no videos exist
- One-tap video generation button
- Clean, engaging UI

## Video Generation Process

1. **Article Selection**: Backend reads user's news cache
2. **Summary Generation**: Creates concise summaries for each article
3. **TTS Generation**: Converts summaries to speech using OpenAI
4. **Video Creation**: Combines article thumbnail + TTS audio into MP4
5. **Storage**: Videos saved to Firebase Storage
6. **Database**: Metadata stored in `VideoCacheLink` collection

## Database Structure

### VideoCacheLink Collection
```
VideoCacheLink/{userId}
├── videos: [
│   ├── url: string (Firebase Storage URL)
│   ├── storage_path: string
│   ├── filename: string
│   ├── theme_identifier: string
│   ├── article_title: string
│   ├── created_at: timestamp
│   └── duration?: number
│   ]
├── total_count: number
└── user_id: string
```

## Dependencies

### Backend (Python)
- `moviepy>=1.0.3` - Video processing
- `Pillow>=10.0.0` - Image manipulation
- `requests>=2.31.0` - HTTP requests

### iOS (Swift)
- `AVKit` - Video playback
- `AVFoundation` - Media framework
- `FirebaseAuth` - Authentication
- `SwiftUI` - UI framework

## Usage

### For Users
1. Open the app and navigate to the "Videos" tab
2. If no videos exist, tap "Generate Videos"
3. Wait for video generation to complete
4. Swipe vertically to browse videos
5. Tap videos to pause/play
6. Use controls to generate more or clear cache

### For Developers
1. Video generation is automatic when users have news articles
2. Videos are cached and persist until manually cleared
3. API calls handle authentication automatically
4. Error states are handled gracefully

## Testing

Use the included test script:
```bash
cd pb
python test_video_generation.py <user_id>
```

This will test:
- Video generation
- Video cache retrieval
- Cache clearing

## Performance Considerations

- Videos are stored in Firebase Storage for CDN delivery
- Metadata is cached in Firestore for fast retrieval
- Video generation happens asynchronously
- Large video files are handled efficiently with streaming

## Future Enhancements

Potential improvements:
- Video sharing functionality
- Like/save videos
- Custom video thumbnails
- Multiple aspect ratios
- Video search and filtering
- Analytics and viewing metrics

## Error Handling

The implementation includes comprehensive error handling:
- Network failures
- Authentication errors
- Video generation failures
- Storage upload failures
- Graceful fallbacks for missing data

## Security

- All API calls require Firebase authentication
- User videos are isolated by user ID
- Storage URLs are secured through Firebase rules
- No unauthorized access to other users' videos 