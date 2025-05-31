import Foundation

// MARK: - Demo Data for Testing
struct DemoData {
    static let sampleAIFeedResponse = AIFeedResponse(
        success: true,
        formatVersion: "1.0",
        generationStats: GenerationStats(
            failedReports: 0,
            successfulReports: 9,
            topicsProcessed: 9,
            totalTopics: 9
        ),
        generationTimestamp: "2025-05-28T22:30:05.294281",
        language: "en",
        refreshTimestamp: "2025-05-28T21:44:52.471992",
        reports: [
            "technology": sampleTechnologyReport,
            "business": sampleBusinessReport,
            "health": sampleHealthReport,
            "science": sampleScienceReport,
            "sports": sampleSportsReport,
            "entertainment": sampleEntertainmentReport,
            "world": sampleWorldReport,
            "nation": sampleNationReport,
            "general": sampleGeneralReport
        ],
        userId: "demo_user_id"
    )
    
    static let sampleTechnologyReport = TopicReport(
        topicName: "technology",
        pickupLine: "🚨 Breaking: AI revolution accelerates as major tech giants unveil groundbreaking developments that could reshape entire industries.",
        topicSummary: """
# TECHNOLOGY BRIEFING

🔥 **TOP HEADLINES**
• OpenAI announces GPT-5 with unprecedented reasoning capabilities
• Apple reveals revolutionary AR glasses at surprise event
• Tesla's new AI chip promises 10x performance improvement

📊 **SUBTOPIC INSIGHTS**
**Artificial Intelligence**
• GPT-5 demonstrates human-level reasoning in complex scenarios
• Google's Gemini Ultra 2.0 challenges OpenAI's dominance
• AI safety concerns grow as capabilities expand rapidly

**Startups**
• Record $2.3B funding round for autonomous vehicle startup
• New unicorn emerges in quantum computing space
• Y Combinator's latest batch focuses heavily on AI applications

🔍 **TRENDING SEARCHES**
• "GPT-5 capabilities" searches surge 400% in past 24 hours
• "Apple AR glasses price" becomes top trending query
• "AI job displacement" concerns spike across social media

⚡ **KEY TAKEAWAYS**
• AI development pace accelerating beyond expert predictions
• Consumer AR finally reaching mainstream viability
• Investment in deep tech startups at all-time high
• Regulatory frameworks struggling to keep pace with innovation
""",
        subtopics: [
            "Artificial Intelligence": SubtopicReport(
                subtopicSummary: """
**Artificial Intelligence Overview**

Revolutionary breakthroughs in AI technology are reshaping the landscape. GPT-5's announcement has sent shockwaves through the industry, demonstrating capabilities that approach human-level reasoning in complex problem-solving scenarios.

**Key Developments:**
• GPT-5 achieves 95% accuracy on graduate-level reasoning tests
• New multimodal capabilities enable seamless text, image, and video processing
• Reduced hallucination rates by 80% compared to previous models
• Enterprise adoption accelerating across Fortune 500 companies

**Industry Impact:**
The implications are far-reaching, with experts predicting significant disruption across knowledge work sectors. Early beta testers report productivity gains of 300-500% in coding and content creation tasks.
""",
                redditSummary: """
**Key Developments:**
• AI breakthrough sparks intense debate about job displacement
• Tech workers expressing both excitement and concern about automation
• Discussions about universal basic income gaining momentum
"""
            ),
            "Startups": SubtopicReport(
                subtopicSummary: """
**Startup Ecosystem Thriving**

The startup landscape is experiencing unprecedented growth, with venture capital flowing into innovative companies at record levels.

**Funding Highlights:**
• Autonomous vehicle startup raises $2.3B Series C
• Quantum computing company achieves $1B valuation
• AI-powered drug discovery platform secures $500M

**Emerging Trends:**
• Climate tech startups attracting major investment
• B2B AI tools seeing explosive demand
• Quantum computing moving from research to commercial applications
""",
                redditSummary: """
**Startup Trends:**
• Entrepreneurs sharing success stories and funding strategies
• Concerns about market saturation in AI space
• Advice threads about navigating current investment climate
"""
            )
        ],
        generationStats: nil
    )
    
    static let sampleBusinessReport = TopicReport(
        topicName: "business",
        pickupLine: "💼 Market volatility intensifies as Federal Reserve signals potential rate changes while tech earnings exceed expectations.",
        topicSummary: """
# BUSINESS BRIEFING

🔥 **TOP HEADLINES**
• Federal Reserve hints at rate cuts amid inflation concerns
• Tech giants report record Q4 earnings despite market uncertainty
• Major merger announced in pharmaceutical industry

📊 **SUBTOPIC INSIGHTS**
**Finance**
• Stock markets show mixed signals as investors await Fed decision
• Cryptocurrency markets surge on institutional adoption news
• Bond yields fluctuate amid economic uncertainty

**Corporate News**
• Apple reports 15% revenue growth driven by services
• Amazon's cloud division continues rapid expansion
• Tesla's energy business becomes major profit driver

⚡ **KEY TAKEAWAYS**
• Economic indicators suggest cautious optimism
• Technology sector remains resilient despite headwinds
• Consumer spending patterns shifting toward experiences
""",
        subtopics: [
            "Finance": SubtopicReport(
                subtopicSummary: """
**Financial Markets Update**

Markets are navigating complex economic signals as the Federal Reserve considers policy adjustments. Recent data suggests a potential shift in monetary policy direction.

**Market Performance:**
• S&P 500 up 2.3% following tech earnings beats
• Dollar strengthens against major currencies
• Gold prices retreat from recent highs

**Economic Indicators:**
• Unemployment remains at historic lows
• Consumer confidence index shows improvement
• Manufacturing data exceeds expectations
""",
                redditSummary: """
**Market Sentiment:**
• Retail investors optimistic about tech stock performance
• Discussions about optimal portfolio allocation strategies
• Concerns about potential market correction timing
"""
            )
        ],
        generationStats: nil
    )
    
    static let sampleHealthReport = TopicReport(
        topicName: "health",
        pickupLine: "🏥 Medical breakthrough: New gene therapy shows 90% success rate in treating previously incurable genetic disorders.",
        topicSummary: """
# HEALTH BRIEFING

🔥 **TOP HEADLINES**
• Revolutionary gene therapy achieves remarkable success rates
• New Alzheimer's drug shows promising trial results
• WHO declares end to latest health emergency

📊 **SUBTOPIC INSIGHTS**
**Medical Research**
• CRISPR technology reaches new milestone in clinical trials
• Personalized medicine approaches show increased effectiveness
• AI-assisted diagnosis improves accuracy by 40%

⚡ **KEY TAKEAWAYS**
• Gene therapy entering mainstream medical practice
• Preventive care gaining increased focus and funding
• Digital health solutions transforming patient care
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleScienceReport = TopicReport(
        topicName: "science",
        pickupLine: "🔬 Scientists achieve nuclear fusion breakthrough that could revolutionize clean energy production worldwide.",
        topicSummary: """
# SCIENCE BRIEFING

🔥 **TOP HEADLINES**
• Nuclear fusion experiment achieves net energy gain
• James Webb telescope discovers potentially habitable exoplanet
• Quantum computer solves complex problem in record time

⚡ **KEY TAKEAWAYS**
• Clean energy solutions showing unprecedented progress
• Space exploration entering new era of discovery
• Quantum computing approaching practical applications
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleSportsReport = TopicReport(
        topicName: "sports",
        pickupLine: "⚽ Championship drama unfolds as underdog teams defy odds in stunning playoff performances.",
        topicSummary: """
# SPORTS BRIEFING

🔥 **TOP HEADLINES**
• Underdog team reaches championship final
• Record-breaking performance in winter olympics
• Major trade shakes up professional league

⚡ **KEY TAKEAWAYS**
• Unexpected storylines dominating sports headlines
• Athletic performance records continue to be broken
• Fan engagement reaching new heights
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleEntertainmentReport = TopicReport(
        topicName: "entertainment",
        pickupLine: "🎬 Hollywood buzzes with anticipation as streaming wars intensify and blockbuster releases break records.",
        topicSummary: """
# ENTERTAINMENT BRIEFING

🔥 **TOP HEADLINES**
• Streaming platform announces major content expansion
• Box office records shattered by surprise hit
• Award season brings unexpected winners

⚡ **KEY TAKEAWAYS**
• Streaming competition driving content innovation
• Audience preferences shifting toward diverse storytelling
• Technology enhancing entertainment experiences
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleWorldReport = TopicReport(
        topicName: "world",
        pickupLine: "🌍 Global leaders convene for historic climate summit as international cooperation reaches new levels.",
        topicSummary: """
# WORLD BRIEFING

🔥 **TOP HEADLINES**
• Historic climate agreement reached at international summit
• Diplomatic breakthrough in long-standing regional conflict
• Global economic cooperation initiatives launched

⚡ **KEY TAKEAWAYS**
• International collaboration strengthening on key issues
• Climate action gaining unprecedented momentum
• Economic partnerships fostering global stability
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleNationReport = TopicReport(
        topicName: "nation",
        pickupLine: "🇺🇸 Congressional session yields bipartisan breakthrough on infrastructure and economic policy initiatives.",
        topicSummary: """
# NATIONAL BRIEFING

🔥 **TOP HEADLINES**
• Bipartisan infrastructure bill passes with strong support
• Economic policy reforms address inflation concerns
• National security measures updated for modern threats

⚡ **KEY TAKEAWAYS**
• Political cooperation emerging on key issues
• Economic policies adapting to current challenges
• National priorities focusing on long-term stability
""",
        subtopics: [:],
        generationStats: nil
    )
    
    static let sampleGeneralReport = TopicReport(
        topicName: "general",
        pickupLine: "📰 Breaking developments across multiple sectors create ripple effects in global markets and society.",
        topicSummary: """
# GENERAL NEWS BRIEFING

🔥 **TOP HEADLINES**
• Multiple sectors experience significant developments
• Social trends emerge from technological advances
• Cultural shifts reflect changing global perspectives

⚡ **KEY TAKEAWAYS**
• Interconnected global events creating complex dynamics
• Social and cultural evolution accelerating
• Technology continuing to reshape daily life
""",
        subtopics: [:],
        generationStats: nil
    )
} 