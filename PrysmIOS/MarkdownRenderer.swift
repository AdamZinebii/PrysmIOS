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
            
            if trimmedLine.hasPrefix("**") && trimmedLine.hasSuffix("**") && trimmedLine.count > 4 {
                // Bold header section
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
    
    private func formatMarkdownForOlderVersions(_ text: String) -> String {
        // Basic markdown formatting removal for older iOS versions
        return text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
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
            Text(section.content)
                .font(font)
                .foregroundColor(color)
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
                        
                        Text(item)
                            .font(font)
                            .foregroundColor(color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 8)
        }
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
• Apple releases new AI chip for MacBooks
• Google announces quantum computing breakthrough
• Microsoft partners with OpenAI for business tools

**Market Impact**
• Tech stocks rise 5% following announcements
• AI startup funding reaches $50B in Q4

**Looking Ahead**
• CES 2024 expected to showcase major innovations
• Regulatory frameworks under development
""")
            .padding()
        }
    }
} 