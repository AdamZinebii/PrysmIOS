# Category Mapping System for Google News

## Overview

This system maps user-selected news categories and subcategories (in any language) to standardized Google News identifiers. This ensures that regardless of the user's language preference, the correct news topics are fetched from Google News API.

## How it works

### 1. User Selection
- User selects categories like "Divertissement" (French) or "Entertainment" (English)
- User selects subcategories like "Films" (French) or "Movies" (English)

### 2. Database Storage
Two types of data are stored:

#### User Preferences (in user's language)
```json
{
  "user_id": "user123",
  "news_subjects": ["Divertissement", "Technologie"],
  "news_subcategories": ["Films", "Intelligence Artificielle"],
  "preferred_language": "Français",
  "country": "France"
}
```

#### Topic Mapping (universal identifiers)
```json
{
  "user_id": "user123",
  "gnews_categories": ["entertainment", "technology"],
  "gnews_subcategories": ["entertainment-movies", "technology-ai"],
  "language": "Français",
  "country": "France"
}
```

### 3. Google News Integration
When fetching news, the backend uses the `gnews_categories` and `gnews_subcategories` to query Google News API, ensuring consistent results regardless of user language.

## Category Mappings

### Main Categories
| Localization Key | English | French | Spanish | Arabic | Google News ID |
|------------------|---------|--------|---------|--------|----------------|
| category.general | General | Général | General | عام | general |
| category.world | World | Monde | Mundo | عالم | world |
| category.nation | Nation | Nation | Nación | وطن | nation |
| category.business | Business | Affaires | Negocios | أعمال | business |
| category.technology | Technology | Technologie | Tecnología | تكنولوجيا | technology |
| category.entertainment | Entertainment | Divertissement | Entretenimiento | ترفيه | entertainment |
| category.sports | Sports | Sports | Deportes | رياضة | sports |
| category.science | Science | Science | Ciencia | علوم | science |
| category.health | Health | Santé | Salud | صحة | health |

### Subcategory Examples

#### Entertainment
| Localization Key | English | French | Spanish | Arabic | Google News ID |
|------------------|---------|--------|---------|--------|----------------|
| subcategory.movies | Movies | Films | Películas | أفلام | entertainment-movies |
| subcategory.music | Music | Musique | Música | موسيقى | entertainment-music |
| subcategory.tv_shows | TV Shows | Émissions TV | Programas TV | برامج تلفزيونية | entertainment-tv |

#### Technology
| Localization Key | English | French | Spanish | Arabic | Google News ID |
|------------------|---------|--------|---------|--------|----------------|
| subcategory.ai | AI | IA | IA | ذكاء اصطناعي | technology-ai |
| subcategory.mobile | Mobile | Mobile | Móvil | جوال | technology-mobile |
| subcategory.software | Software | Logiciel | Software | برمجيات | technology-software |

## Implementation Details

### CategoryMapping Structure
```swift
struct CategoryMapping {
    static let subcategoryToGNewsMapping: [String: String] = [
        "subcategory.movies": "entertainment-movies",
        "subcategory.ai": "technology-ai",
        // ... more mappings
    ]
    
    static func getGNewsCategory(for localizedCategoryName: String, using languageManager: LanguageManager) -> String?
    static func getGNewsSubcategory(for localizedSubcategoryName: String, using languageManager: LanguageManager) -> String?
}
```

### Database Collections

#### 1. User Preferences Collection
- **Collection**: `user_preferences`
- **Document ID**: `user_id`
- **Purpose**: Store user preferences in their selected language
- **Fields**: `news_subjects`, `news_subcategories`, `preferred_language`, `country`, etc.

#### 2. Topic Mapping Collection
- **Collection**: `topic_mappings`
- **Document ID**: `user_id`
- **Purpose**: Store universal Google News identifiers
- **Fields**: `gnews_categories`, `gnews_subcategories`, `language`, `country`

### Benefits

1. **Language Independence**: News fetching works regardless of user's language
2. **Consistent Results**: Same topics return same news across languages
3. **Scalability**: Easy to add new languages without changing backend logic
4. **Maintainability**: Clear separation between UI language and news API queries
5. **Analytics**: Can track popular topics across all languages using universal IDs

### Example Flow

1. French user selects "Divertissement" → "Films"
2. System maps to `entertainment` → `entertainment-movies`
3. Backend queries Google News with `category=entertainment&subcategory=entertainment-movies`
4. Returns movie news in French (based on user's country/language preference)
5. English user selecting "Entertainment" → "Movies" gets same news in English

This ensures consistent, language-agnostic news delivery while maintaining user experience in their preferred language. 