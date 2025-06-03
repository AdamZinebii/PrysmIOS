import SwiftUI
import Foundation

// MARK: - Enhanced Markdown Text View
struct MarkdownText: View {
    let markdown: String
    let font: Font
    let color: Color
    let lineLimit: Int?
    let alignment: TextAlignment
    
    init(_ markdown: String, 
         font: Font = .body, 
         color: Color = .primary, 
         lineLimit: Int? = nil, 
         alignment: TextAlignment = .leading) {
        self.markdown = markdown
        self.font = font
        self.color = color
        self.lineLimit = lineLimit
        self.alignment = alignment
    }
    
    var body: some View {
        Group {
            if #available(iOS 15.0, *) {
                // Use custom parsing for better control
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(parseMarkdownContent(markdown), id: \.id) { section in
                        MarkdownSectionView(section: section, font: font, color: color)
                    }
                }
            } else {
                // Fallback for older iOS versions
                Text(formatMarkdownForOlderVersions(markdown))
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(alignment)
            }
        }
    }
    
    private func parseMarkdownContent(_ content: String) -> [MarkdownSection] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [MarkdownSection] = []
        var currentSection: MarkdownSection?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                continue
            }
            
            if trimmedLine.hasPrefix("**") && trimmedLine.hasSuffix("**") && trimmedLine.count > 4 && !trimmedLine.contains("• ") && !trimmedLine.contains("- ") {
                // Bold header section (only if it's a standalone header, not mixed with bullets)
                if let current = currentSection {
                    sections.append(current)
                }
                let boldContent = String(trimmedLine.dropFirst(2).dropLast(2))
                currentSection = MarkdownSection(
                    id: UUID(),
                    type: .boldHeader,
                    content: boldContent,
                    items: []
                )
            } else if trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("- ") {
                // Bullet point (handle both • and - for robustness)
                let bulletContent = trimmedLine.hasPrefix("• ") ? 
                    String(trimmedLine.dropFirst(2)) : 
                    String(trimmedLine.dropFirst(2))
                
                if currentSection == nil || currentSection?.type != .bulletList {
                    if let current = currentSection {
                        sections.append(current)
                    }
                    currentSection = MarkdownSection(
                        id: UUID(),
                        type: .bulletList,
                        content: "",
                        items: []
                    )
                }
                currentSection?.items.append(bulletContent)
            } else {
                // Regular text paragraph
                if currentSection == nil || currentSection?.type != .paragraph {
                    if let current = currentSection {
                        sections.append(current)
                    }
                    currentSection = MarkdownSection(
                        id: UUID(),
                        type: .paragraph,
                        content: trimmedLine,
                        items: []
                    )
                } else {
                    currentSection?.content += " " + trimmedLine
                }
            }
        }
        
        if let current = currentSection {
            sections.append(current)
        }
        
        return sections
    }
    
    // New function to parse inline bold formatting
    private func parseInlineFormattingText(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = text
        
        while !currentText.isEmpty {
            // Check for triple asterisks first: ***text***
            if let tripleRange = currentText.range(of: "\\*\\*\\*([^*]+?)\\*\\*\\*", options: .regularExpression) {
                // Add text before triple asterisks
                let before = String(currentText[..<tripleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(contentsOf: parseDoubleBold(before))
                }
                
                // Add important text
                let tripleText = String(currentText[tripleRange])
                let cleanText = tripleText.replacingOccurrences(of: "***", with: "")
                segments.append(TextSegment(text: cleanText, isImportant: true))
                
                currentText = String(currentText[tripleRange.upperBound...])
            }
            // Check for double asterisks: **text**
            else if let doubleRange = currentText.range(of: "\\*\\*([^*]+?)\\*\\*", options: .regularExpression) {
                // Add text before double asterisks
                let before = String(currentText[..<doubleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(TextSegment(text: before))
                }
                
                // Add bold text
                let doubleText = String(currentText[doubleRange])
                let cleanText = doubleText.replacingOccurrences(of: "**", with: "")
                segments.append(TextSegment(text: cleanText, isBold: true))
                
                currentText = String(currentText[doubleRange.upperBound...])
            }
            else {
                // No more formatting, add remaining text
                segments.append(TextSegment(text: currentText))
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text)] : segments
    }
    
    // Helper function for double bold only
    private func parseDoubleBold(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = text
        
        while !currentText.isEmpty {
            if let doubleRange = currentText.range(of: "\\*\\*([^*]+?)\\*\\*", options: .regularExpression) {
                let before = String(currentText[..<doubleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(TextSegment(text: before))
                }
                
                let doubleText = String(currentText[doubleRange])
                let cleanText = doubleText.replacingOccurrences(of: "**", with: "")
                segments.append(TextSegment(text: cleanText, isBold: true))
                
                currentText = String(currentText[doubleRange.upperBound...])
            } else {
                segments.append(TextSegment(text: currentText))
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text)] : segments
    }
    
    private func formatMarkdownForOlderVersions(_ text: String) -> String {
        // Basic markdown formatting removal for older iOS versions
        return text
            .replacingOccurrences(of: "***", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "<<[^>]+>>", with: "", options: .regularExpression)
    }
}

// MARK: - Text Segment Model for Inline Bold and URLs
struct TextSegment {
    let text: String
    let isBold: Bool
    let isImportant: Bool
    let isURL: Bool
    let url: String?
    
    init(text: String, isBold: Bool = false, isImportant: Bool = false, isURL: Bool = false, url: String? = nil) {
        self.text = text
        self.isBold = isBold
        self.isImportant = isImportant
        self.isURL = isURL
        self.url = url
    }
}

// MARK: - Markdown Section Models
struct MarkdownSection: Identifiable {
    let id: UUID
    let type: MarkdownSectionType
    var content: String
    var items: [String]
}

enum MarkdownSectionType {
    case boldHeader
    case paragraph
    case bulletList
}

// MARK: - Markdown Section View
struct MarkdownSectionView: View {
    let section: MarkdownSection
    let font: Font
    let color: Color
    
    var body: some View {
        switch section.type {
        case .boldHeader:
            HStack {
                Text(section.content)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            
        case .paragraph:
            InlineFormattedText(section.content, font: font, color: color)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
                
        case .bulletList:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.primary.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .padding(.top, 8)
                        
                        InlineFormattedText(item, font: font, color: color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    private func extractURLsFromText(_ text: String) -> [String] {
        var urls: [String] = []
        var currentText = text
        
        while !currentText.isEmpty {
            if let urlRange = currentText.range(of: "<<([^>]+)>>", options: .regularExpression) {
                let urlText = String(currentText[urlRange])
                let cleanURL = urlText.replacingOccurrences(of: "<<", with: "").replacingOccurrences(of: ">>", with: "")
                urls.append(cleanURL)
                currentText = String(currentText[urlRange.upperBound...])
            } else {
                break
            }
        }
        
        return urls
    }
}

// MARK: - Article Thumbnails View
struct ArticleThumbnailsView: View {
    let urls: [String]
    @State private var matchingArticles: [ArticleData] = []
    
    var body: some View {
        Group {
            if !matchingArticles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("Sources")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ], spacing: 6) {
                        ForEach(Array(matchingArticles.enumerated()), id: \.offset) { index, article in
                            if let thumbnailUrl = article.thumbnail, !thumbnailUrl.isEmpty {
                                ArticleSourceThumbnail(
                                    article: article,
                                    size: 60
                                )
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
            }
        }
        .onAppear {
            findMatchingArticles()
        }
        .onChange(of: urls) { _ in
            findMatchingArticles()
        }
    }
    
    private func findMatchingArticles() {
        let articleData = AIFeedService.shared.articleData
        var foundArticles: [ArticleData] = []
        
        print("🔍 Looking for articles matching URLs: \(urls)")
        
        for url in urls {
            // Search through all topics and articles
            for (topicName, articles) in articleData {
                for article in articles {
                    if article.link == url {
                        foundArticles.append(article)
                        print("✅ Found matching article: \(article.title) for URL: \(url)")
                        break
                    }
                }
            }
        }
        
        // Remove duplicates and limit to 6
        let uniqueArticles = Array(Set(foundArticles.map { $0.id }))
            .compactMap { id in foundArticles.first { $0.id == id } }
            .prefix(6)
        
        matchingArticles = Array(uniqueArticles)
        print("📊 Final matching articles count: \(matchingArticles.count)")
    }
}

// MARK: - Article Source Thumbnail
struct ArticleSourceThumbnail: View {
    let article: ArticleData
    let size: CGFloat
    @State private var showingFullArticle = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Open article URL
            if let url = URL(string: article.link) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 4) {
                // Thumbnail image
                if let thumbnailUrl = article.thumbnail {
                    AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: size, height: size)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.gray)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: size, height: size)
                                .overlay(
                                    Image(systemName: "doc.text")
                                        .font(.system(size: size * 0.3))
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Source label
                Text(article.source)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: size)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Inline Formatted Text View with URL Support
struct InlineFormattedText: View {
    let text: String
    let font: Font
    let color: Color
    
    init(_ text: String, font: Font, color: Color) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    var body: some View {
        let segments = parseInlineFormatting(text)
        
        // Create a flowing text layout with inline buttons and thumbnails
        return FlowingTextViewWithThumbnails(segments: segments, font: font, color: color)
    }
    
    private func parseInlineFormatting(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = text
        
        while !currentText.isEmpty {
            // Check for URL patterns first: <<URL>>
            if let urlRange = currentText.range(of: "<<([^>]+)>>", options: .regularExpression) {
                // Add text before the URL
                let beforeURL = String(currentText[..<urlRange.lowerBound])
                if !beforeURL.isEmpty {
                    segments.append(contentsOf: parseInlineFormattingText(beforeURL))
                }
                
                // Extract the URL
                let urlText = String(currentText[urlRange])
                let cleanURL = urlText.replacingOccurrences(of: "<<", with: "").replacingOccurrences(of: ">>", with: "")
                segments.append(TextSegment(text: "", isURL: true, url: cleanURL))
                
                // Continue with the rest of the text
                currentText = String(currentText[urlRange.upperBound...])
            } else {
                // No more URLs, parse the rest for formatting
                segments.append(contentsOf: parseInlineFormattingText(currentText))
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text)] : segments
    }
    
    private func parseInlineFormattingText(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = text
        
        while !currentText.isEmpty {
            // Check for triple asterisks first: ***text***
            if let tripleRange = currentText.range(of: "\\*\\*\\*([^*]+?)\\*\\*\\*", options: .regularExpression) {
                // Add text before triple asterisks
                let before = String(currentText[..<tripleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(contentsOf: parseDoubleBold(before))
                }
                
                // Add important text
                let tripleText = String(currentText[tripleRange])
                let cleanText = tripleText.replacingOccurrences(of: "***", with: "")
                segments.append(TextSegment(text: cleanText, isImportant: true))
                
                currentText = String(currentText[tripleRange.upperBound...])
            }
            // Check for double asterisks: **text**
            else if let doubleRange = currentText.range(of: "\\*\\*([^*]+?)\\*\\*", options: .regularExpression) {
                // Add text before double asterisks
                let before = String(currentText[..<doubleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(TextSegment(text: before))
                }
                
                // Add bold text
                let doubleText = String(currentText[doubleRange])
                let cleanText = doubleText.replacingOccurrences(of: "**", with: "")
                segments.append(TextSegment(text: cleanText, isBold: true))
                
                currentText = String(currentText[doubleRange.upperBound...])
            }
            else {
                // No more formatting, add remaining text
                segments.append(TextSegment(text: currentText))
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text)] : segments
    }
    
    // Helper function for double bold only
    private func parseDoubleBold(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = text
        
        while !currentText.isEmpty {
            if let doubleRange = currentText.range(of: "\\*\\*([^*]+?)\\*\\*", options: .regularExpression) {
                let before = String(currentText[..<doubleRange.lowerBound])
                if !before.isEmpty {
                    segments.append(TextSegment(text: before))
                }
                
                let doubleText = String(currentText[doubleRange])
                let cleanText = doubleText.replacingOccurrences(of: "**", with: "")
                segments.append(TextSegment(text: cleanText, isBold: true))
                
                currentText = String(currentText[doubleRange.upperBound...])
            } else {
                segments.append(TextSegment(text: currentText))
                break
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text)] : segments
    }
}

// MARK: - Flowing Text View with Inline Thumbnails
struct FlowingTextViewWithThumbnails: View {
    let segments: [TextSegment]
    let font: Font
    let color: Color
    @State private var articleData: [String: ArticleData] = [:]
    
    var body: some View {
        let elements = buildTextAndThumbnailElements()
        let hasImages = elements.contains { if case .thumbnail(_) = $0 { return true } else { return false } }
        
        Group {
            if hasImages {
                // Layout horizontal avec texte à gauche et images à droite
                HStack(alignment: .top, spacing: 12) {
                    // Texte à gauche - une seule vue Text concaténée pour une typographie cohérente
                    buildConcatenatedText(from: elements)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Images à droite
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                            if case .thumbnail(let url) = element {
                                if let article = articleData[url] {
                                    InlineArticleThumbnail(article: article)
                                        .onAppear {
                                            print("🖼️ Rendering thumbnail for URL: \(url)")
                                            print("📄 Article: \(article.title)")
                                            print("🔗 Thumbnail URL: \(article.thumbnail ?? "nil")")
                                        }
                                } else {
                                    EmptyView()
                                        .onAppear {
                                            print("❌ No article found for URL: \(url)")
                                            print("🔍 Available URLs: \(Array(articleData.keys).prefix(3))")
                                        }
                                }
                            }
                        }
                    }
                }
            } else {
                // Pas d'images, layout normal - une seule vue Text concaténée
                buildConcatenatedText(from: segments)
            }
        }
        .onAppear {
            loadArticleData()
        }
    }
    
    // Nouvelle fonction pour construire une seule vue Text concaténée
    private func buildConcatenatedText(from segments: [TextSegment]) -> some View {
        var result: Text?
        
        for segment in segments {
            if segment.isURL, let urlString = segment.url, let url = URL(string: urlString) {
                // Pour les URLs, on utilise encore un bouton séparé car on ne peut pas les inclure dans Text
                // On pourrait améliorer cela plus tard avec des interactions personnalisées
                continue
            } else if !segment.text.isEmpty {
                let segmentText: Text
                
                if segment.isImportant {
                    segmentText = Text(segment.text)
                        .fontWeight(.semibold)
                        .font(font)
                        .foregroundColor(color)
                } else if segment.isBold {
                    segmentText = Text(segment.text)
                        .fontWeight(.bold)
                        .font(font)
                        .foregroundColor(color)
                } else {
                    segmentText = Text(segment.text)
                        .fontWeight(.regular)
                        .font(font)
                        .foregroundColor(color)
                }
                
                if result == nil {
                    result = segmentText
                } else {
                    result = result! + segmentText
                }
            }
        }
        
        return result ?? Text("")
    }
    
    // Version surchargée pour les éléments (avec URLs séparées)
    private func buildConcatenatedText(from elements: [TextElement]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                if case .text(let textSegments) = element {
                    buildConcatenatedText(from: textSegments)
                }
            }
            
            // Ajouter les URLs comme boutons séparés
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                if case .text(let textSegments) = element {
                    ForEach(Array(textSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                        if segment.isURL, let urlString = segment.url, let url = URL(string: urlString) {
                            InlineFaviconButton(url: url, font: font)
                        }
                    }
                }
            }
        }
    }
    
    private func buildTextAndThumbnailElements() -> [TextElement] {
        var elements: [TextElement] = []
        var currentTextSegments: [TextSegment] = []
        
        for segment in segments {
            if segment.isURL {
                // Add current text segments if any
                if !currentTextSegments.isEmpty {
                    currentTextSegments.append(segment) // Include the URL in the text
                    elements.append(.text(currentTextSegments))
                    currentTextSegments = []
                }
                
                // Add thumbnail element if we have the article
                if let url = segment.url {
                    elements.append(.thumbnail(url))
                }
            } else {
                currentTextSegments.append(segment)
            }
        }
        
        // Add remaining text segments
        if !currentTextSegments.isEmpty {
            elements.append(.text(currentTextSegments))
        }
        
        return elements
    }
    
    private func loadArticleData() {
        let allArticleData = AIFeedService.shared.articleData
        var urlToArticle: [String: ArticleData] = [:]
        
        print("🔍 Loading article data for thumbnail matching...")
        print("📊 Total topics in articleData: \(allArticleData.count)")
        
        // Build lookup dictionary from URL to Article
        var totalArticles = 0
        var articlesWithThumbnails = 0
        
        for (topicName, articles) in allArticleData {
            print("📚 Topic '\(topicName)': \(articles.count) articles")
            totalArticles += articles.count
            
            for article in articles {
                urlToArticle[article.link] = article
                
                if let thumbnail = article.thumbnail, !thumbnail.isEmpty {
                    articlesWithThumbnails += 1
                    print("🖼️ Article with thumbnail: '\(article.title)' -> \(article.link)")
                } else {
                    print("❌ No thumbnail for: '\(article.title)' -> \(article.link)")
                }
            }
        }
        
        print("📈 Summary: \(totalArticles) total articles, \(articlesWithThumbnails) with thumbnails")
        print("🔗 URLs in lookup dictionary: \(urlToArticle.keys.count)")
        
        articleData = urlToArticle
    }
    
    enum TextElement {
        case text([TextSegment])
        case thumbnail(String) // URL
    }
}

// MARK: - Inline Article Thumbnail
struct InlineArticleThumbnail: View {
    let article: ArticleData
    @State private var showingFullScreenImage = false
    
    var body: some View {
        Group {
            // Only show the thumbnail image, nothing else
            if let thumbnailUrl = article.thumbnail, !thumbnailUrl.isEmpty {
                AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.gray)
                            )
                    case .success(let image):
                        Button(action: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // Show full screen image
                            showingFullScreenImage = true
                        }) {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "doc.text")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .fullScreenCover(isPresented: $showingFullScreenImage) {
                    FullScreenImageView(
                        imageUrl: thumbnailUrl,
                        article: article,
                        isPresented: $showingFullScreenImage
                    )
                }
                .onAppear {
                    print("🎯 InlineArticleThumbnail appeared for: \(article.title)")
                    print("🔗 Thumbnail URL: \(thumbnailUrl)")
                }
            } else {
                EmptyView()
                    .onAppear {
                        print("❌ No thumbnail for article: \(article.title)")
                    }
            }
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let imageUrl: String
    let article: ArticleData
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header with close button and article info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Button(action: {
                            if let url = URL(string: article.link) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(article.source)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }
                .padding()
                
                Spacer()
                
                // Main image
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                    case .failure(_):
                        VStack(spacing: 16) {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Image could not be loaded")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Spacer()
            }
        }
        .gesture(
            // Allow swipe down to dismiss
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height > 100 {
                        isPresented = false
                    }
                }
        )
    }
}

// MARK: - Inline Favicon Button Component
struct InlineFaviconButton: View {
    let url: URL
    let font: Font
    @State private var faviconImage: UIImage?
    @State private var isLoading = true
    
    // Calculate size based on font
    private var buttonSize: CGFloat {
        switch font {
        case .caption, .caption2:
            return 10
        case .footnote:
            return 11
        case .subheadline:
            return 12
        case .callout:
            return 13
        case .body:
            return 14
        case .headline:
            return 16
        case .title3:
            return 18
        case .title2:
            return 20
        case .title:
            return 22
        case .largeTitle:
            return 26
        default:
            return 14
        }
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Open URL
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }) {
            Group {
                if let faviconImage = faviconImage {
                    Image(uiImage: faviconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    // Show a small loading indicator
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.4)
                                .tint(.gray)
                        )
                } else {
                    // Fallback icon
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: buttonSize * 0.8))
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 1) // Minimal character-like spacing
        .onAppear {
            loadFavicon()
        }
    }
    
    private func loadFavicon() {
        guard let domain = url.host else { 
            isLoading = false
            return 
        }
        
        // Try to load favicon from Google's favicon service
        let faviconURLString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"
        guard let faviconURL = URL(string: faviconURLString) else {
            isLoading = false
            return
        }
        
        print("🔍 Loading favicon for: \(domain)")
        
        URLSession.shared.dataTask(with: faviconURL) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data), data.count > 100 { // Ensure it's not just a placeholder
                    print("✅ Favicon loaded for: \(domain)")
                    faviconImage = image
                } else {
                    print("❌ Favicon failed for: \(domain)")
                }
                isLoading = false
            }
        }.resume()
    }
}

// MARK: - Rich Markdown View (Legacy - keeping for compatibility)
struct RichMarkdownView: View {
    let content: String
    
    var body: some View {
        MarkdownText(content)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownText("""
**Technology Summary**

**Key Developments**
• **Apple releases** new AI chip for MacBooks <<https://apple.com>>
• **Google announces** quantum computing breakthrough <<https://google.com>>
• Microsoft partners with **OpenAI** for business tools <<https://microsoft.com>>

**Market Impact**
• Tech stocks rise **5%** following announcements
• AI startup funding reaches ***$50B*** in Q4 <<https://techcrunch.com>>
• ***Record-breaking*** investment levels seen across the sector

**Looking Ahead**
• CES 2024 expected to showcase **major innovations**
• Regulatory frameworks under development <<https://reuters.com>>
• Industry experts predict ***unprecedented growth*** in AI sector
""")
            .padding()
        }
    }
} 