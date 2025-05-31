import Foundation

// MARK: - Subtopic Metadata Models
struct SubtopicMeta: Codable, Hashable {
    let title: String
    let query: String
    let subreddits: [String]
}

// MARK: - Topic Metadata for fallback when no subtopics selected
struct TopicMeta: Codable, Hashable {
    let title: String
    let query: String
    let subreddits: [String]
}

// MARK: - Topics Catalog (for when no subtopics are selected)
struct TopicsCatalog {
    static let catalog: [String: TopicMeta] = [
        "nation": TopicMeta(
            title: "Nation",
            query: "national politics OR government OR domestic policy",
            subreddits: ["politics", "worldnews", "news"]
        ),
        "technology": TopicMeta(
            title: "Technology",
            query: "technology OR tech news OR innovation",
            subreddits: ["technology", "gadgets", "programming"]
        ),
        "business": TopicMeta(
            title: "Business",
            query: "business news OR economy OR finance",
            subreddits: ["business", "investing", "economics"]
        ),
        "science": TopicMeta(
            title: "Science",
            query: "scientific research OR breakthrough OR discovery",
            subreddits: ["science", "futurology", "space"]
        ),
        "health": TopicMeta(
            title: "Health",
            query: "health news OR medical breakthrough OR healthcare",
            subreddits: ["medicine", "health", "publichealth"]
        ),
        "sports": TopicMeta(
            title: "Sports",
            query: "sports news OR athletic competition OR championship",
            subreddits: ["sports", "soccer", "nba"]
        ),
        "entertainment": TopicMeta(
            title: "Entertainment",
            query: "entertainment news OR movies OR music OR celebrities",
            subreddits: ["entertainment", "movies", "music"]
        ),
        "world": TopicMeta(
            title: "World",
            query: "world news OR international OR global affairs",
            subreddits: ["worldnews", "geopolitics", "europe"]
        )
    ]
    
    static func getTopicMeta(for categoryKey: String) -> TopicMeta? {
        return catalog[categoryKey]
    }
}

// MARK: - Subtopics Catalog
struct SubtopicsCatalog {
    static let catalog: [String: [SubtopicMeta]] = [
        "nation": [
            SubtopicMeta(title: "France", query: "France OR French politics OR Macron", subreddits: ["france", "French", "europe"]),
            SubtopicMeta(title: "Switzerland", query: "Switzerland OR Swiss politics OR Bern", subreddits: ["Switzerland", "europe", "worldnews"]),
            SubtopicMeta(title: "USA", query: "United States OR American politics OR Washington", subreddits: ["politics", "usa", "unitedstates"]),
            SubtopicMeta(title: "Sweden", query: "Sweden OR Swedish politics OR Stockholm", subreddits: ["sweden", "europe", "worldnews"]),
            SubtopicMeta(title: "Japan", query: "Japan OR Japanese politics OR Tokyo", subreddits: ["japan", "japannews", "worldnews"]),
            SubtopicMeta(title: "Morocco", query: "Morocco OR Moroccan politics OR Rabat", subreddits: ["Morocco", "africa", "worldnews"])
        ],
        
        "technology": [
            SubtopicMeta(title: "Artificial Intelligence", query: "artificial intelligence OR AI", subreddits: ["MachineLearning", "Artificial", "singularity"]),
            SubtopicMeta(title: "Large Language Models", query: "\"large language model\" OR LLM", subreddits: ["MachineLearning", "ChatGPT", "LanguageTechnology"]),
            SubtopicMeta(title: "AGI Research", query: "\"artificial general intelligence\" OR AGI", subreddits: ["singularity", "Artificial", "AGI"]),
            SubtopicMeta(title: "Robotics & Drones", query: "robotics OR industrial robot OR drones", subreddits: ["robotics", "drones", "Futurology"]),
            SubtopicMeta(title: "Semiconductors & Chips", query: "semiconductor OR chip fabrication", subreddits: ["hardware", "Semiconductor", "chiphardware"]),
            SubtopicMeta(title: "Quantum Computing", query: "\"quantum computing\"", subreddits: ["QuantumComputing", "QuantumMechanics", "Futurology"]),
            SubtopicMeta(title: "Cyber-Security", query: "cybersecurity OR data breach OR hacking", subreddits: ["cybersecurity", "netsec", "hacking"]),
            SubtopicMeta(title: "Gadgets & Hardware", query: "gadgets OR smartphone launch OR laptop review", subreddits: ["gadgets", "hardware", "apple"]),
            SubtopicMeta(title: "Mobile & 5G", query: "5G rollout OR mobile network", subreddits: ["android", "iphone", "5Gtechnology"]),
            SubtopicMeta(title: "Cloud & DevOps", query: "cloud computing OR DevOps", subreddits: ["devops", "kubernetes", "cloudcomputing"]),
            SubtopicMeta(title: "Start-ups & VC", query: "tech startup funding OR venture capital", subreddits: ["startups", "venturecapital", "Entrepreneur"]),
            SubtopicMeta(title: "Crypto & Web3", query: "crypto OR blockchain OR Web3", subreddits: ["CryptoCurrency", "ethereum", "Bitcoin"])
        ],
        
        "business": [
            SubtopicMeta(title: "Stock Markets", query: "stock market OR equities rally", subreddits: ["stocks", "investing", "wallstreetbets"]),
            SubtopicMeta(title: "Macroeconomics", query: "inflation data OR GDP growth", subreddits: ["economics", "MacroEconomics", "EconomicPolicy"]),
            SubtopicMeta(title: "Fin-Tech", query: "fintech OR mobile payments", subreddits: ["fintech", "CryptoCurrency", "personalfinance"]),
            SubtopicMeta(title: "E-commerce", query: "e-commerce OR online retail", subreddits: ["ecommerce", "Entrepreneur", "Shopify"]),
            SubtopicMeta(title: "Start-up Funding", query: "startup funding round OR seed funding", subreddits: ["startups", "venturecapital", "Ycombinator"]),
            SubtopicMeta(title: "IPO & M&A", query: "initial public offering OR merger acquisition", subreddits: ["stocks", "investing", "finance"]),
            SubtopicMeta(title: "Energy Markets", query: "oil price OR renewable energy investment", subreddits: ["energy", "oil_and_gas", "renewableenergy"]),
            SubtopicMeta(title: "Real-Estate", query: "real estate market OR housing prices", subreddits: ["realestate", "RealEstateInvesting", "housing"]),
            SubtopicMeta(title: "Crypto Markets", query: "bitcoin price OR crypto market cap", subreddits: ["CryptoCurrency", "Bitcoin", "ethereum"])
        ],
        
        "science": [
            SubtopicMeta(title: "Space & Astronomy", query: "astronomy discovery OR space telescope", subreddits: ["space", "astronomy", "SpaceXLounge"]),
            SubtopicMeta(title: "Physics Breakthroughs", query: "physics experiment OR particle collider", subreddits: ["physics", "AskPhysics", "QuantumPhysics"]),
            SubtopicMeta(title: "Genetics & CRISPR", query: "CRISPR gene editing OR genomics study", subreddits: ["genetics", "biology", "CRISPR"]),
            SubtopicMeta(title: "Climate Science", query: "climate change study OR greenhouse emissions", subreddits: ["climate", "environment", "climatechange"]),
            SubtopicMeta(title: "Medical Research", query: "medical research breakthrough OR clinical trial", subreddits: ["science", "medicine", "medicalresearch"]),
            SubtopicMeta(title: "Quantum Science", query: "\"quantum physics\" discovery", subreddits: ["QuantumComputing", "QuantumMechanics", "Futurology"])
        ],
        
        "health": [
            SubtopicMeta(title: "Public Health", query: "public health alert OR CDC guidance", subreddits: ["publichealth", "medicine", "COVID19"]),
            SubtopicMeta(title: "Pharma & Biotech", query: "pharma trial results OR biotech approval", subreddits: ["medicine", "biotech", "pharmacy"]),
            SubtopicMeta(title: "Mental Health", query: "mental health study OR depression treatment", subreddits: ["MentalHealth", "psychology", "depression"]),
            SubtopicMeta(title: "Fitness & Wellness", query: "fitness research OR exercise benefits", subreddits: ["fitness", "loseit", "bodyweightfitness"]),
            SubtopicMeta(title: "Nutrition", query: "nutrition study OR diet health", subreddits: ["nutrition", "HealthyFood", "EatCheapAndHealthy"]),
            SubtopicMeta(title: "Longevity Research", query: "longevity study OR anti aging therapy", subreddits: ["longevity", "AgingScience", "Biohackers"])
        ],
        
        "sports": [
            SubtopicMeta(title: "Soccer (Football)", query: "soccer match OR football transfer", subreddits: ["soccer", "footballhighlights", "footballmanagergames"]),
            SubtopicMeta(title: "NBA Basketball", query: "NBA game OR basketball playoffs", subreddits: ["nba", "nbadiscussion", "nba2k"]),
            SubtopicMeta(title: "NFL Football", query: "NFL game OR football draft", subreddits: ["nfl", "fantasyfootball", "CFB"]),
            SubtopicMeta(title: "Tennis (ATP/WTA)", query: "tennis tournament OR grand slam", subreddits: ["tennis", "tennispro", "tennisbetting"]),
            SubtopicMeta(title: "Formula 1", query: "Formula 1 race OR F1 Grand Prix", subreddits: ["formula1", "F1Technical", "F1Porn"]),
            SubtopicMeta(title: "Esports", query: "esports tournament OR gaming league", subreddits: ["esports", "leagueoflegends", "DotA2"])
        ],
        
        "entertainment": [
            SubtopicMeta(title: "Movies & Box Office", query: "box office OR film release", subreddits: ["movies", "boxoffice", "TrueFilm"]),
            SubtopicMeta(title: "Streaming & TV", query: "new series premiere OR streaming platform", subreddits: ["television", "netflix", "tvPlus"]),
            SubtopicMeta(title: "Music Releases", query: "new album release OR single debut", subreddits: ["music", "hiphopheads", "indieheads"]),
            SubtopicMeta(title: "Celebrities", query: "celebrity news OR Hollywood star", subreddits: ["celebritynews", "popculturechat", "Fauxmoi"]),
            SubtopicMeta(title: "Gaming Culture", query: "video game release OR gaming community", subreddits: ["gaming", "pcgaming", "nintendo"]),
            SubtopicMeta(title: "Awards & Festivals", query: "film festival OR music awards", subreddits: ["Oscars", "movies", "film"])
        ],
        
        "world": [
            SubtopicMeta(title: "Geopolitics", query: "geopolitical tensions OR diplomatic talks", subreddits: ["geopolitics", "worldnews", "politics"]),
            SubtopicMeta(title: "Conflicts & Wars", query: "military conflict OR ceasefire agreement", subreddits: ["worldnews", "combatfootage", "ukraine"]),
            SubtopicMeta(title: "Elections Worldwide", query: "presidential election OR parliamentary vote", subreddits: ["electionpolls", "worldnews", "politics"]),
            SubtopicMeta(title: "Human Rights", query: "human rights report OR NGO statement", subreddits: ["humanrights", "worldnews", "politics"]),
            SubtopicMeta(title: "Climate Policy", query: "climate policy summit OR COP negotiations", subreddits: ["climate", "environment", "sustainability"])
        ]
    ]
    
    static func getSubtopicMeta(for title: String, in category: String) -> SubtopicMeta? {
        return catalog[category]?.first { $0.title == title }
    }
    
    static func getAllSubtopics(for category: String) -> [SubtopicMeta] {
        return catalog[category] ?? []
    }
    
    static func getSubtopicTitles(for category: String) -> [String] {
        return catalog[category]?.map { $0.title } ?? []
    }
} 