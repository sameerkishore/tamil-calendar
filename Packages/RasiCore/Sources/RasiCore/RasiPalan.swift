import Foundation

/// The daily one-word Rasi Palan printed on Tamil tear-off calendars ("மேஷம் – லாபம்").
/// For flavour, not astrology: each rasi's word is picked from a fixed list by date, so a given
/// day always reads the same.
public enum RasiPalan {
    public static let rasis: [LocalizedText] = [
        .init(ta: "மேஷம்", en: "Mesham"), .init(ta: "ரிஷபம்", en: "Rishabam"),
        .init(ta: "மிதுனம்", en: "Mithunam"), .init(ta: "கடகம்", en: "Kadagam"),
        .init(ta: "சிம்மம்", en: "Simmam"), .init(ta: "கன்னி", en: "Kanni"),
        .init(ta: "துலாம்", en: "Thulaam"), .init(ta: "விருச்சிகம்", en: "Viruchigam"),
        .init(ta: "தனுசு", en: "Dhanusu"), .init(ta: "மகரம்", en: "Magaram"),
        .init(ta: "கும்பம்", en: "Kumbam"), .init(ta: "மீனம்", en: "Meenam"),
    ]

    public static let words: [LocalizedText] = [
        .init(ta: "லாபம்", en: "Profit"), .init(ta: "நன்மை", en: "Good"),
        .init(ta: "வெற்றி", en: "Success"), .init(ta: "மகிழ்ச்சி", en: "Joy"),
        .init(ta: "அமைதி", en: "Calm"), .init(ta: "பயணம்", en: "Travel"),
        .init(ta: "செலவு", en: "Expense"), .init(ta: "கவனம்", en: "Caution"),
        .init(ta: "உதவி", en: "Help"), .init(ta: "சுபம்", en: "Auspicious"),
        .init(ta: "அனுகூலம்", en: "Favour"), .init(ta: "தாமதம்", en: "Delay"),
        .init(ta: "போட்டி", en: "Rivalry"), .init(ta: "பாராட்டு", en: "Praise"),
        .init(ta: "நலம்", en: "Wellbeing"), .init(ta: "யோகம்", en: "Fortune"),
        .init(ta: "அலைச்சல்", en: "Hassle"), .init(ta: "ஆதாயம்", en: "Gain"),
        .init(ta: "பரிசு", en: "Gift"), .init(ta: "சோர்வு", en: "Fatigue"),
        .init(ta: "உற்சாகம்", en: "Zeal"), .init(ta: "பொறுமை", en: "Patience"),
        .init(ta: "ஓய்வு", en: "Rest"), .init(ta: "நட்பு", en: "Friendship"),
    ]

    /// The word for each of the 12 rasis on `day`, in order (Mesham first).
    public static func words(for day: CalendarDay) -> [LocalizedText] {
        var state = UInt64(day.year * 10_000 + day.month * 100 + day.day) &* 0x9E37_79B9_7F4A_7C15
        var used = Set<Int>()
        return rasis.indices.map { _ in
            // xorshift; avoid repeating a word on the same day.
            var pick: Int
            repeat {
                state ^= state << 13; state ^= state >> 7; state ^= state << 17
                pick = Int(state % UInt64(words.count))
            } while used.contains(pick)
            used.insert(pick)
            return words[pick]
        }
    }
}
