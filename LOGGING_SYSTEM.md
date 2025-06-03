# User Interaction Logging System

## Overview

The logging system tracks user interactions throughout the Prysm iOS app and stores them in Firebase Storage. Each user has their own text file containing chronological logs of their app usage.

## System Architecture

### Components

1. **LoggingService** - Singleton service that handles all logging operations
2. **Firebase Storage** - Stores individual log files per user (`/logging/{userId}.txt`)
3. **Firestore** - Stores log summaries and metadata (`/logging_summary/{userId}`)
4. **Security Rules** - Ensures users can only access their own logs

### Data Flow

```
User Action → LoggingService → Pending Logs → Batch Upload → Firebase Storage
                             ↘                                  ↗
                               Firestore Summary ←──────────────
```

## Tracked Events

### App Navigation
- **app_entered** - User opens/enters the app
- **settings_opened** - User opens settings menu
- **preferences_opened** - User opens preferences/customization

### Content Viewing
- **topic_summary_viewed** - User views a topic detail page
- **subtopic_summary_viewed** - User views a subtopic detail page
- **reddit_summary_viewed** - User views reddit reactions/discussions

### Media Interactions
- **podcast_played** - User starts playing a podcast
- **podcast_paused** - User pauses a podcast
- **podcast_seeked** - User seeks to different position in podcast

### User Actions
- **refresh_triggered** - User triggers content refresh (various contexts)

## Implementation Details

### Adding Logging to Views

To add logging to any view, inject the LoggingService and call appropriate methods:

```swift
@StateObject private var loggingService = LoggingService.shared

// In button action or onAppear
loggingService.logTopicSummaryViewed(
    topicName: "Technology",
    topicId: "tech_001"
)
```

### Log Entry Format

Each log entry follows this format in the text file:
```
[YYYY-MM-DD HH:mm:ss] event_name | {"detail_key": "detail_value"}
```

Example:
```
[2024-06-02 20:15:32] topic_summary_viewed | {"topic_name": "Technology", "topic_id": "tech_001"}
[2024-06-02 20:16:45] podcast_played | {"podcast_url": "https://...", "duration_seconds": 180.5}
```

### Batch Upload System

- Logs are batched locally and uploaded every 30 seconds
- Prevents excessive Firebase calls while ensuring data persistence
- Failed uploads are retried automatically
- Manual flush available via `LoggingService.shared.flushLogs()`

### Security & Privacy

- Each user can only access their own log files
- Firebase Storage rules enforce user isolation
- Firestore rules protect log summary documents
- No sensitive data is logged (URLs are optional)

## File Structure

```
Firebase Storage:
└── logging/
    ├── {userId1}.txt
    ├── {userId2}.txt
    └── ...

Firestore:
└── logging_summary/
    ├── {userId1}/
    │   ├── user_id: string
    │   ├── total_entries: number
    │   ├── last_updated: timestamp
    │   └── latest_entries_count: number
    └── ...
```

## Integration Points

### Currently Integrated

1. **ModernDashboardView**
   - App entrance logging
   - Topic selection logging
   - Refresh action logging
   - Settings/preferences navigation

2. **TopicDetailView**
   - Topic summary viewing
   - Subtopic navigation

3. **SubtopicDetailView**
   - Subtopic summary viewing
   - Reddit summary access

4. **AudioPlayerService**
   - Podcast play/pause events
   - Seeking actions with timestamps

### Potential Extensions

- Article reading duration
- Search queries
- Notification interactions
- Feature usage analytics
- Performance metrics

## Usage Examples

### Basic Event Logging
```swift
// Simple event
loggingService.logAppEntered()

// Event with context
loggingService.logRefreshTriggered(context: "pull_to_refresh")

// Event with detailed data
loggingService.logPodcastSeeked(fromTime: 45.2, toTime: 67.8)
```

### Accessing Log Data
```swift
// Get summary data
let summary = await loggingService.getLogSummary()
print("Total entries: \(summary?["total_entries"] ?? 0)")

// Force upload pending logs
await loggingService.flushLogs()
```

## Deployment

### Deploy Security Rules
```bash
./deploy_firebase_rules.sh
```

### Manual Deployment
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage
```

## Monitoring & Analytics

### Firestore Summary Fields
- `total_entries`: Total number of log entries for user
- `last_updated`: Timestamp of last log upload
- `latest_entries_count`: Number of entries in most recent batch

### Log Analysis Queries
The text files can be parsed for analytics:
- Most accessed content
- User engagement patterns
- Feature usage statistics
- Session duration analysis

## Troubleshooting

### Common Issues

1. **Logs not uploading**
   - Check network connectivity
   - Verify user authentication
   - Check Firebase Storage rules

2. **Permission denied errors**
   - Ensure storage rules are deployed
   - Verify user is authenticated
   - Check userId in logs

3. **Missing logs**
   - Call `flushLogs()` before app termination
   - Check for pending logs in service

### Debug Information

The LoggingService provides console output for debugging:
- `📝 LoggingService: event_name - details`
- `✅ LoggingService: Successfully uploaded X log entries`
- `❌ LoggingService: Failed to upload logs: error`

## Performance Considerations

- Logs are batched to minimize Firebase calls
- Text files have 10MB size limit (thousands of entries)
- Periodic uploads run on background timer
- No blocking UI operations for logging

## Privacy Compliance

- Only interaction events are logged, not content
- No personally identifiable information in logs
- Users control their own data through authentication
- Log files can be deleted per user request

## Future Enhancements

- Log rotation for large files
- Compression for storage efficiency
- Real-time analytics dashboard
- Export functionality for users
- Automated insights generation 