import Foundation

protocol WordProvider {
    func fetchWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry
}

enum WordProviderError: LocalizedError {
    case missingGeminiAPIKey
    case invalidGeminiResponse
    case invalidGeminiLanguage
    case invalidGeminiDifficulty
    case noWordFound

    var errorDescription: String? {
        switch self {
        case .missingGeminiAPIKey:
            return "Missing Gemini API key. Add GEMINI_API_KEY in your app config."
        case .invalidGeminiResponse:
            return "Received an invalid response from Gemini."
        case .invalidGeminiLanguage:
            return "Gemini returned a word in a different language."
        case .invalidGeminiDifficulty:
            return "Gemini returned a word for the wrong difficulty."
        case .noWordFound:
            return "No word could be found right now."
        }
    }
}

struct CompositeWordProvider: WordProvider {
    private let geminiProvider: GeminiWordProvider
    private let commonFallbackProvider: CommonEverydayWordProvider
    private let internetProvider: WikipediaWordProvider

    init(
        geminiProvider: GeminiWordProvider = GeminiWordProvider(),
        commonFallbackProvider: CommonEverydayWordProvider = CommonEverydayWordProvider(),
        internetProvider: WikipediaWordProvider = WikipediaWordProvider()
    ) {
        self.geminiProvider = geminiProvider
        self.commonFallbackProvider = commonFallbackProvider
        self.internetProvider = internetProvider
    }

    func fetchWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry {
        if geminiProvider.hasAPIKey {
            do {
                return try await geminiProvider.fetchWord(for: language, difficulty: difficulty)
            } catch {
                if let fallbackWord = try? await commonFallbackProvider.fetchWord(for: language, difficulty: difficulty) {
                    return fallbackWord
                }
                return try await internetProvider.fetchWord(for: language, difficulty: difficulty)
            }
        }

        if let fallbackWord = try? await commonFallbackProvider.fetchWord(for: language, difficulty: difficulty) {
            return fallbackWord
        }

        return try await internetProvider.fetchWord(for: language, difficulty: difficulty)
    }
}

struct GeminiWordProvider: WordProvider {
    private let session: URLSession
    private let apiKey: String?

    var hasAPIKey: Bool {
        apiKey != nil
    }

    init(session: URLSession = .shared) {
        self.session = session

        let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        let plistKey = Bundle.main.object(forInfoDictionaryKey: AppConfig.geminiAPIKeyPlistKey) as? String
        self.apiKey = Self.sanitizedAPIKey(envKey) ?? Self.sanitizedAPIKey(plistKey)
    }

    func fetchWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry {
        guard apiKey != nil else {
            throw WordProviderError.missingGeminiAPIKey
        }

        var lastError: Error = WordProviderError.invalidGeminiResponse
        let maxAttempts = 2

        for attempt in 0..<maxAttempts {
            do {
                return try await fetchSingleWord(for: language, difficulty: difficulty)
            } catch {
                lastError = error

                if isTimeoutError(error) {
                    break
                }

                if attempt < (maxAttempts - 1) {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 250_000_000))
                }
            }
        }

        throw lastError
    }

    private func fetchSingleWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry {
        guard let apiKey else {
            throw WordProviderError.missingGeminiAPIKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(AppConfig.geminiModel):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(prompt: prompt(for: language, difficulty: difficulty))
        )

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.firstText else {
            throw WordProviderError.invalidGeminiResponse
        }

        let payload = try parseWordPayload(
            from: text,
            expectedLanguage: language,
            expectedDifficulty: difficulty
        )

        let examples = cleanedExamples(from: payload.exampleSentences)
        guard examples.count >= 3 else {
            throw WordProviderError.invalidGeminiResponse
        }

        let characteristics = cleanedCharacteristics(from: payload.characteristics, difficulty: difficulty)

        return WordEntry(
            word: payload.word.trimmingCharacters(in: .whitespacesAndNewlines),
            transliteration: payload.transliteration?.nilIfEmpty,
            englishMeaning: payload.englishMeaning.trimmingCharacters(in: .whitespacesAndNewlines),
            exampleSentences: examples,
            characteristics: characteristics,
            languageCode: language.rawValue,
            difficultyCode: difficulty.rawValue,
            fetchedAt: Date()
        )
    }

    private func prompt(for language: LanguageOption, difficulty: LearningDifficulty) -> String {
        """
        Generate one \(difficulty.displayName.lowercased())-difficulty vocabulary word for a learner of \(language.displayName).
        Difficulty rule: \(difficulty.promptHint)
        The example sentences must sound like real everyday language used by native speakers in normal life.
        Use daily contexts such as home, family, school, shopping, transport, work, friends, and routine activities.

        Respond with strict JSON only (no markdown, no code fences), using exactly these keys:
        {
          "languageCode": "\(language.rawValue)",
          "difficulty": "\(difficulty.rawValue)",
          "word": "",
          "transliteration": "",
          "englishMeaning": "",
          "exampleSentences": [
            { "sentence": "", "englishTranslation": "" },
            { "sentence": "", "englishTranslation": "" },
            { "sentence": "", "englishTranslation": "" },
            { "sentence": "", "englishTranslation": "" },
            { "sentence": "", "englishTranslation": "" }
          ],
          "characteristics": {
            "partOfSpeech": "",
            "cefrLevel": "",
            "register": "",
            "usageTip": ""
          }
        }

        Constraints:
        - "languageCode" must be exactly "\(language.rawValue)"
        - "difficulty" must be exactly "\(difficulty.rawValue)"
        - "word" must be exactly one word
        - "word" must be common in daily life; avoid names, cities, countries, nationalities, brands, technical terms
        - For easy difficulty, choose a very simple beginner word a child would understand immediately
        - For easy difficulty, keep the chosen word short and ordinary (examples: house, water, food, eat, drink, go, sleep, book, friend)
        - For medium difficulty, choose a practical A2-B1 everyday word used in routine conversation (shopping, school, work, travel, home)
        - For hard difficulty, choose a practical B1-B2 everyday word that is more nuanced but still common in real conversations
        - Use lowercase for the word when the language normally allows lowercase dictionary forms
        - "englishMeaning" should be short and clear
        - "exampleSentences" must contain 5 natural everyday-life sentences in \(language.displayName), each with a natural English translation
        - The examples must be how the word is actually used in daily communication, not definition-style writing
        - Do NOT use meta-learning sentences (for example: "this word", "remember this word", "practice this word", dictionary explanations)
        - Do NOT use encyclopedia-style facts, historical summaries, or formal article-like tone
        - "characteristics.partOfSpeech" must be one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection
        - "characteristics.cefrLevel" should be realistic for the chosen difficulty
        """
    }

    private func parseWordPayload(
        from text: String,
        expectedLanguage: LanguageOption,
        expectedDifficulty: LearningDifficulty
    ) throws -> GeminiWordPayload {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleanText) ?? cleanText
        guard let data = jsonString.data(using: .utf8) else {
            throw WordProviderError.invalidGeminiResponse
        }

        let payload = try JSONDecoder().decode(GeminiWordPayload.self, from: data)

        guard !payload.word.nilIfEmpty.isNil,
              !payload.englishMeaning.nilIfEmpty.isNil else {
            throw WordProviderError.invalidGeminiResponse
        }

        if !isLikelySingleWord(payload.word) {
            throw WordProviderError.invalidGeminiResponse
        }

        let validExamples = payload.exampleSentences.filter {
            !$0.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.englishTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard validExamples.count >= 3 else {
            throw WordProviderError.invalidGeminiResponse
        }

        let metaLikeCount = validExamples.filter {
            containsLearningMetaText($0.englishTranslation)
        }.count
        if metaLikeCount >= 2 {
            throw WordProviderError.invalidGeminiResponse
        }

        let veryLongCount = validExamples.filter { $0.englishTranslation.count > 120 }.count
        if veryLongCount >= 2 {
            throw WordProviderError.invalidGeminiResponse
        }

        let normalizedLanguage = payload.languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let expectedCode = expectedLanguage.rawValue.lowercased()
        if normalizedLanguage != expectedCode,
           !normalizedLanguage.hasPrefix(expectedCode + "-") {
            throw WordProviderError.invalidGeminiLanguage
        }

        let normalizedDifficulty = payload.difficulty
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedDifficulty != expectedDifficulty.rawValue.lowercased() {
            throw WordProviderError.invalidGeminiDifficulty
        }

        if !passesDifficultyChecks(payload: payload, language: expectedLanguage, difficulty: expectedDifficulty) {
            throw WordProviderError.invalidGeminiResponse
        }

        return payload
    }

    private func passesDifficultyChecks(
        payload: GeminiWordPayload,
        language: LanguageOption,
        difficulty: LearningDifficulty
    ) -> Bool {
        let word = payload.word.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = payload.englishMeaning.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let partOfSpeech = payload.characteristics.partOfSpeech.lowercased()

        let maxLength: Int
        let maxMeaningWords: Int
        switch difficulty {
        case .easy:
            maxLength = 10
            maxMeaningWords = 4
        case .medium:
            maxLength = 12
            maxMeaningWords = 5
        case .hard:
            maxLength = 14
            maxMeaningWords = 6
        }

        if word.count > maxLength {
            return false
        }

        if language != .german,
           let first = word.first,
           first.isUppercase {
            return false
        }

        if partOfSpeech.contains("proper") || partOfSpeech.contains("name") {
            return false
        }

        if meaning.contains("city") || meaning.contains("country") || meaning.contains("national") {
            return false
        }

        let wordsInMeaning = meaning.split(separator: " ").count
        if wordsInMeaning > maxMeaningWords {
            return false
        }

        return true
    }

    private func cleanedExamples(from items: [GeminiExamplePayload]) -> [ExampleSentence] {
        var unique: [ExampleSentence] = []

        for item in items {
            guard var sentence = item.sentence.nilIfEmpty,
                  let translation = item.englishTranslation.nilIfEmpty else {
                continue
            }

            if !sentence.hasSuffix(".") && !sentence.hasSuffix("!") && !sentence.hasSuffix("?") {
                sentence += "."
            }

            let example = ExampleSentence(sentence: sentence, englishTranslation: translation)
            if !unique.contains(example) {
                unique.append(example)
            }
        }

        return Array(unique.prefix(5))
    }

    private func containsLearningMetaText(_ value: String) -> Bool {
        let text = value.lowercased()
        let markers = [
            "this word",
            "the word ",
            "vocabulary",
            "dictionary",
            "language lesson",
            "practice the word",
            "remember the word"
        ]
        return markers.contains { text.contains($0) }
    }

    private func cleanedCharacteristics(
        from input: GeminiCharacteristicsPayload,
        difficulty: LearningDifficulty
    ) -> WordCharacteristics {
        let partOfSpeech = input.partOfSpeech.nilIfEmpty ?? "Unknown"
        let cefrLevel = input.cefrLevel.nilIfEmpty ?? difficulty.cefrRange
        let register = input.register.nilIfEmpty ?? "General"
        let usageTip = input.usageTip.nilIfEmpty ?? "Use the word in a sentence about your day."

        return WordCharacteristics(
            partOfSpeech: partOfSpeech,
            cefrLevel: cefrLevel,
            register: register,
            usageTip: usageTip
        )
    }

    private func isLikelySingleWord(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains(where: { $0.isWhitespace || $0.isNewline }) else { return false }
        guard !trimmed.contains(",") else { return false }

        let scalars = trimmed.unicodeScalars
        let hasLetter = scalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = scalars.contains { CharacterSet.decimalDigits.contains($0) }
        return hasLetter && !hasDigit
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let first = text.firstIndex(of: "{"),
              let last = text.lastIndex(of: "}"),
              first <= last else {
            return nil
        }
        return String(text[first...last])
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.timedOut.rawValue
    }

    private static func sanitizedAPIKey(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercase = trimmed.lowercased()
        if trimmed.hasPrefix("$(") || lowercase.contains("your_real_key") || lowercase.contains("changeme") {
            return nil
        }

        return trimmed
    }
}

struct CommonEverydayWordProvider: WordProvider {
    func fetchWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry {
        let seed = seedWords(for: difficulty).randomElement() ?? SeedWord(word: "water", partOfSpeech: "noun", cefr: "A1")
        let localizedWord = localizedSeedWord(seed.word, language: language) ?? seed.word
        let examples = buildExamples(
            for: localizedWord,
            englishWord: seed.word,
            language: language
        )

        let characteristics = WordCharacteristics(
            partOfSpeech: seed.partOfSpeech,
            cefrLevel: seed.cefr,
            register: "General",
            usageTip: usageTip(for: difficulty)
        )

        return WordEntry(
            word: localizedWord,
            transliteration: nil,
            englishMeaning: seed.word,
            exampleSentences: examples,
            characteristics: characteristics,
            languageCode: language.rawValue,
            difficultyCode: difficulty.rawValue,
            fetchedAt: Date()
        )
    }

    private func englishExampleSentences(for word: String) -> [String] {
        [
            "I use this word every day: \(word).",
            "Today I say the word \(word) clearly.",
            "My teacher asked me to remember \(word).",
            "I wrote a short sentence with \(word).",
            "I will practice \(word) again tonight."
        ]
    }

    private func buildExamples(
        for localizedWord: String,
        englishWord: String,
        language: LanguageOption
    ) -> [ExampleSentence] {
        let nativeSentences = nativeExampleSentences(for: localizedWord, language: language)
        let englishSentences = englishExampleSentences(for: englishWord)
        let count = min(nativeSentences.count, englishSentences.count)

        var examples: [ExampleSentence] = []
        examples.reserveCapacity(count)

        for index in 0..<count {
            examples.append(
                ExampleSentence(
                    sentence: nativeSentences[index],
                    englishTranslation: englishSentences[index]
                )
            )
        }

        return examples
    }

    private func nativeExampleSentences(for word: String, language: LanguageOption) -> [String] {
        switch language {
        case .spanish:
            return [
                "Hoy use la palabra \(word).",
                "Escucho la palabra \(word) todos los dias.",
                "En clase practico la palabra \(word).",
                "Escribi una frase corta con \(word).",
                "Voy a repetir \(word) esta noche."
            ]
        case .french:
            return [
                "Aujourd'hui, j'ai utilise le mot \(word).",
                "J'entends le mot \(word) tous les jours.",
                "En classe, je pratique le mot \(word).",
                "J'ai ecrit une phrase courte avec \(word).",
                "Je vais revoir \(word) ce soir."
            ]
        case .german:
            return [
                "Heute habe ich das Wort \(word) benutzt.",
                "Ich hore das Wort \(word) jeden Tag.",
                "Im Unterricht ube ich das Wort \(word).",
                "Ich habe einen kurzen Satz mit \(word) geschrieben.",
                "Heute Abend wiederhole ich \(word)."
            ]
        case .italian:
            return [
                "Oggi ho usato la parola \(word).",
                "Sento la parola \(word) ogni giorno.",
                "A lezione pratico la parola \(word).",
                "Ho scritto una frase breve con \(word).",
                "Stasera ripassero \(word)."
            ]
        case .portuguese:
            return [
                "Hoje usei a palavra \(word).",
                "Eu ouco a palavra \(word) todos os dias.",
                "Na aula eu pratico a palavra \(word).",
                "Escrevi uma frase curta com \(word).",
                "Vou revisar \(word) esta noite."
            ]
        case .turkish:
            return [
                "Bugun \(word) kelimesini kullandim.",
                "Her gun \(word) kelimesini duyuyorum.",
                "Okulda \(word) kelimesi geciyor.",
                "Bugun \(word) ile bir cumle yazdim.",
                "Aksam \(word) kelimesini tekrar edecegim."
            ]
        case .japanese:
            return [
                "今日は\(word)という言葉を使いました。",
                "毎日\(word)という言葉を聞きます。",
                "授業で\(word)という言葉を練習します。",
                "\(word)を使って短い文を書きました。",
                "今夜もう一度\(word)を練習します。"
            ]
        case .korean:
            return [
                "오늘 저는 \(word) 단어를 사용했어요.",
                "저는 매일 \(word) 단어를 들어요.",
                "수업에서 \(word) 단어를 연습해요.",
                "저는 \(word)로 짧은 문장을 썼어요.",
                "오늘 밤에 \(word)를 다시 복습할 거예요."
            ]
        case .arabic:
            return [
                "اليوم استخدمت كلمة \(word).",
                "اسمع كلمة \(word) كل يوم.",
                "في الصف اتدرب على كلمة \(word).",
                "كتبت جملة قصيرة باستخدام \(word).",
                "ساراجع كلمة \(word) الليلة."
            ]
        }
    }

    private struct SeedWord {
        let word: String
        let partOfSpeech: String
        let cefr: String
    }

    private func localizedSeedWord(_ englishWord: String, language: LanguageOption) -> String? {
        if language == .turkish {
            return turkishWordMap[englishWord]
        }
        return nil
    }

    private func seedWords(for difficulty: LearningDifficulty) -> [SeedWord] {
        switch difficulty {
        case .easy:
            return easySeeds
        case .medium:
            return mediumSeeds
        case .hard:
            return hardSeeds
        }
    }

    private func usageTip(for difficulty: LearningDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "This is a very common daily-life word. Try using it in one short sentence now."
        case .medium:
            return "This is a practical everyday word. Use it in a short dialogue about your day."
        case .hard:
            return "This is a nuanced everyday word. Use it naturally in a longer sentence today."
        }
    }

    private let easySeeds: [SeedWord] = [
        SeedWord(word: "water", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "food", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "home", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "book", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "friend", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "day", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "night", partOfSpeech: "noun", cefr: "A1"),
        SeedWord(word: "eat", partOfSpeech: "verb", cefr: "A1"),
        SeedWord(word: "drink", partOfSpeech: "verb", cefr: "A1"),
        SeedWord(word: "sleep", partOfSpeech: "verb", cefr: "A1"),
        SeedWord(word: "go", partOfSpeech: "verb", cefr: "A1"),
        SeedWord(word: "small", partOfSpeech: "adjective", cefr: "A1"),
        SeedWord(word: "big", partOfSpeech: "adjective", cefr: "A1"),
        SeedWord(word: "good", partOfSpeech: "adjective", cefr: "A1")
    ]

    private let mediumSeeds: [SeedWord] = [
        SeedWord(word: "market", partOfSpeech: "noun", cefr: "A2"),
        SeedWord(word: "ticket", partOfSpeech: "noun", cefr: "A2"),
        SeedWord(word: "meeting", partOfSpeech: "noun", cefr: "B1"),
        SeedWord(word: "holiday", partOfSpeech: "noun", cefr: "A2"),
        SeedWord(word: "traffic", partOfSpeech: "noun", cefr: "B1"),
        SeedWord(word: "borrow", partOfSpeech: "verb", cefr: "A2"),
        SeedWord(word: "return", partOfSpeech: "verb", cefr: "A2"),
        SeedWord(word: "arrive", partOfSpeech: "verb", cefr: "A2"),
        SeedWord(word: "invite", partOfSpeech: "verb", cefr: "B1"),
        SeedWord(word: "decide", partOfSpeech: "verb", cefr: "B1"),
        SeedWord(word: "careful", partOfSpeech: "adjective", cefr: "A2"),
        SeedWord(word: "busy", partOfSpeech: "adjective", cefr: "A2"),
        SeedWord(word: "useful", partOfSpeech: "adjective", cefr: "B1"),
        SeedWord(word: "simple", partOfSpeech: "adjective", cefr: "A2")
    ]

    private let hardSeeds: [SeedWord] = [
        SeedWord(word: "schedule", partOfSpeech: "noun", cefr: "B1"),
        SeedWord(word: "deadline", partOfSpeech: "noun", cefr: "B2"),
        SeedWord(word: "budget", partOfSpeech: "noun", cefr: "B1"),
        SeedWord(word: "feedback", partOfSpeech: "noun", cefr: "B2"),
        SeedWord(word: "approach", partOfSpeech: "noun", cefr: "B2"),
        SeedWord(word: "improve", partOfSpeech: "verb", cefr: "B1"),
        SeedWord(word: "suggest", partOfSpeech: "verb", cefr: "B1"),
        SeedWord(word: "manage", partOfSpeech: "verb", cefr: "B2"),
        SeedWord(word: "negotiate", partOfSpeech: "verb", cefr: "B2"),
        SeedWord(word: "prefer", partOfSpeech: "verb", cefr: "B1"),
        SeedWord(word: "reliable", partOfSpeech: "adjective", cefr: "B2"),
        SeedWord(word: "efficient", partOfSpeech: "adjective", cefr: "B2"),
        SeedWord(word: "flexible", partOfSpeech: "adjective", cefr: "B2"),
        SeedWord(word: "confident", partOfSpeech: "adjective", cefr: "B1")
    ]

    private let turkishWordMap: [String: String] = [
        "water": "su",
        "food": "yemek",
        "home": "ev",
        "book": "kitap",
        "friend": "arkadas",
        "day": "gun",
        "night": "gece",
        "eat": "yemek",
        "drink": "icmek",
        "sleep": "uyumak",
        "go": "gitmek",
        "small": "kucuk",
        "big": "buyuk",
        "good": "iyi",
        "market": "pazar",
        "ticket": "bilet",
        "meeting": "toplanti",
        "holiday": "tatil",
        "traffic": "trafik",
        "borrow": "odunc",
        "return": "donmek",
        "arrive": "varmak",
        "invite": "davet",
        "decide": "karar",
        "careful": "dikkatli",
        "busy": "mesgul",
        "useful": "faydali",
        "simple": "basit",
        "schedule": "program",
        "deadline": "sontarih",
        "budget": "butce",
        "feedback": "geribildirim",
        "approach": "yaklasim",
        "improve": "gelistirmek",
        "suggest": "onermek",
        "manage": "yonetmek",
        "negotiate": "muzakere",
        "prefer": "tercih",
        "reliable": "guvenilir",
        "efficient": "verimli",
        "flexible": "esnek",
        "confident": "ozguvenli"
    ]
}

struct WikipediaWordProvider: WordProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWord(for language: LanguageOption, difficulty: LearningDifficulty) async throws -> WordEntry {
        for _ in 0..<8 {
            let summary = try await fetchRandomSummary(for: language)
            guard let candidateWord = extractSingleWord(from: summary.title) else {
                continue
            }

            if difficulty == .easy,
               language != .german,
               let first = candidateWord.first,
               first.isUppercase {
                continue
            }

            let translatedMeaning = try? await translateToEnglish(candidateWord, from: language)
            let meaning = translatedMeaning?.nilIfEmpty ?? "Random \(language.displayName) word from the internet."
            let nativeExamples = buildNativeExampleSentences(from: summary.extract, word: candidateWord)
            let examples = await buildTranslatedExamples(from: nativeExamples, language: language)

            if examples.count < 3 {
                continue
            }

            let characteristics = WordCharacteristics(
                partOfSpeech: "Unknown",
                cefrLevel: difficulty.cefrRange,
                register: "General",
                usageTip: "Use this word in one spoken sentence and one written sentence today."
            )

            return WordEntry(
                word: candidateWord,
                transliteration: nil,
                englishMeaning: meaning,
                exampleSentences: examples,
                characteristics: characteristics,
                languageCode: language.rawValue,
                difficultyCode: difficulty.rawValue,
                fetchedAt: Date()
            )
        }

        throw WordProviderError.noWordFound
    }

    private func fetchRandomSummary(for language: LanguageOption) async throws -> WikipediaSummaryResponse {
        let endpoint = "https://\(language.localeIdentifier).wikipedia.org/api/rest_v1/page/random/summary"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(WikipediaSummaryResponse.self, from: data)
    }

    private func translateToEnglish(_ text: String, from language: LanguageOption) async throws -> String {
        guard let escaped = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }

        var lastError: Error = URLError(.unknown)

        for attempt in 0..<3 {
            do {
                let endpoint = "https://api.mymemory.translated.net/get?q=\(escaped)&langpair=\(language.rawValue)|en"
                guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

                var request = URLRequest(url: url)
                request.timeoutInterval = 12

                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
                return normalizeTranslation(decoded.responseData.translatedText)
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 300_000_000))
                }
            }
        }

        throw lastError
    }

    private func normalizeTranslation(_ raw: String) -> String {
        var output = raw.replacingOccurrences(of: "+", with: " ")
        output = output.replacingOccurrences(
            of: "%\\s+([0-9A-Fa-f]{2})",
            with: "%$1",
            options: .regularExpression
        )
        output = output.replacingOccurrences(of: "%20", with: " ")

        for _ in 0..<3 {
            if let decoded = output.removingPercentEncoding {
                output = decoded
            }
        }

        output = output.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractSingleWord(from title: String) -> String? {
        let withoutParens = title.replacingOccurrences(
            of: "\\(.*?\\)",
            with: "",
            options: .regularExpression
        )

        let normalized = withoutParens
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",;:|/\\-–—"))

        let tokens = normalized.components(separatedBy: separators)

        for rawToken in tokens {
            let token = rawToken.trimmingCharacters(in: .punctuationCharacters)
            guard isAcceptableWordToken(token) else { continue }
            return token
        }

        return nil
    }

    private func isAcceptableWordToken(_ token: String) -> Bool {
        guard token.count >= 2, token.count <= 28 else { return false }

        let scalars = token.unicodeScalars
        let hasLetter = scalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = scalars.contains { CharacterSet.decimalDigits.contains($0) }
        let hasWhitespace = token.contains(where: { $0.isWhitespace || $0.isNewline })

        return hasLetter && !hasDigit && !hasWhitespace
    }

    private func buildNativeExampleSentences(from extract: String?, word: String) -> [String] {
        guard let extract,
              let nonEmpty = extract.nilIfEmpty else {
            return [
                "\(word).",
                "\(word) \(word).",
                "\(word)!"
            ]
        }

        let cleaned = nonEmpty
            .replacingOccurrences(of: "!", with: ".")
            .replacingOccurrences(of: "?", with: ".")
            .replacingOccurrences(of: "\n", with: " ")

        let parts = cleaned.components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 8 }

        var prioritized: [String] = []
        let lowerWord = word.lowercased()

        for sentence in parts where sentence.lowercased().contains(lowerWord) {
            let finalized = sentence.hasSuffix(".") ? sentence : sentence + "."
            if !prioritized.contains(finalized) {
                prioritized.append(finalized)
            }
        }

        for sentence in parts where prioritized.count < 5 {
            let finalized = sentence.hasSuffix(".") ? sentence : sentence + "."
            if !prioritized.contains(finalized) {
                prioritized.append(finalized)
            }
        }

        return Array(prioritized.prefix(5))
    }

    private func buildTranslatedExamples(
        from nativeSentences: [String],
        language: LanguageOption
    ) async -> [ExampleSentence] {
        var examples: [ExampleSentence] = []

        for native in nativeSentences.prefix(5) {
            guard let cleanedNative = native.nilIfEmpty else { continue }

            let translated = try? await translateToEnglish(cleanedNative, from: language)
            let english = translated?.nilIfEmpty ?? cleanedNative

            examples.append(
                ExampleSentence(sentence: cleanedNative, englishTranslation: english)
            )
        }

        return examples
    }
}

private struct GeminiRequest: Encodable {
    let contents: [Content]

    init(prompt: String) {
        self.contents = [Content(parts: [Part(text: prompt)])]
    }

    struct Content: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?

    var firstText: String? {
        candidates?
            .first?
            .content?
            .parts?
            .compactMap { $0.text }
            .joined(separator: "\n")
    }

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
    }
}

private struct GeminiWordPayload: Decodable {
    let languageCode: String
    let difficulty: String
    let word: String
    let transliteration: String?
    let englishMeaning: String
    let exampleSentences: [GeminiExamplePayload]
    let characteristics: GeminiCharacteristicsPayload
}

private struct GeminiExamplePayload: Decodable {
    let sentence: String
    let englishTranslation: String
}

private struct GeminiCharacteristicsPayload: Decodable {
    let partOfSpeech: String
    let cefrLevel: String
    let register: String
    let usageTip: String
}

private struct WikipediaSummaryResponse: Decodable {
    let title: String
    let extract: String?
}

private struct MyMemoryResponse: Decodable {
    let responseData: ResponseData

    struct ResponseData: Decodable {
        let translatedText: String
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var isNil: Bool {
        self == nil
    }
}
