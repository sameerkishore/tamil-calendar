import Foundation

/// A two-line daily horoscope for one rasi, in the plain style of calendar "palan" columns.
/// For fun, not astrology: lines are picked from fixed lists by date and rasi, so a given day
/// always reads the same for that sign.
public enum Horoscope {
    /// Work, money and outside matters.
    static let first: [LocalizedText] = [
        .init(ta: "பணவரவு திருப்திகரமாக இருக்கும்.", en: "Money matters go smoothly."),
        .init(ta: "வேலையில் பாராட்டு கிடைக்கும்.", en: "Your work earns praise."),
        .init(ta: "புதிய முயற்சிகள் வெற்றி தரும்.", en: "New efforts bring success."),
        .init(ta: "நண்பர்களால் நன்மை உண்டு.", en: "Friends bring good fortune."),
        .init(ta: "பயணங்களில் கவனம் தேவை.", en: "Take care while travelling."),
        .init(ta: "எதிர்பாராத செலவுகள் ஏற்படலாம்.", en: "Unexpected expenses may come up."),
        .init(ta: "தொழிலில் முன்னேற்றம் உண்டு.", en: "Progress at work."),
        .init(ta: "பழைய கடன்கள் வசூலாகும்.", en: "Old dues get repaid."),
        .init(ta: "முக்கிய முடிவுகளைத் தள்ளிப் போடவும்.", en: "Put off big decisions for now."),
        .init(ta: "உழைப்புக்கு ஏற்ற பலன் கிடைக்கும்.", en: "Your effort pays off in full."),
        .init(ta: "அரசு காரியங்கள் சாதகமாகும்.", en: "Official matters go your way."),
        .init(ta: "வியாபாரத்தில் லாபம் பெருகும்.", en: "Business profits grow."),
        .init(ta: "சக ஊழியர்கள் ஒத்துழைப்பார்கள்.", en: "Colleagues lend a hand."),
        .init(ta: "தடைபட்ட வேலைகள் முடியும்.", en: "Stalled work gets finished."),
    ]

    /// Home, health and a word of advice.
    static let second: [LocalizedText] = [
        .init(ta: "குடும்பத்தில் மகிழ்ச்சி நிலவும்.", en: "There is happiness at home."),
        .init(ta: "உடல்நலத்தில் கவனம் தேவை.", en: "Look after your health."),
        .init(ta: "உறவினர் வருகை உண்டு.", en: "Relatives may visit."),
        .init(ta: "பேச்சில் நிதானம் தேவை.", en: "Choose your words calmly."),
        .init(ta: "மனதில் அமைதி கிடைக்கும்.", en: "Peace of mind today."),
        .init(ta: "பிள்ளைகளால் பெருமை சேரும்.", en: "Children make you proud."),
        .init(ta: "இறை வழிபாடு நன்மை தரும்.", en: "Prayer brings blessings."),
        .init(ta: "வாழ்க்கைத் துணையின் ஆதரவு கிடைக்கும்.", en: "Your partner stands by you."),
        .init(ta: "ஓய்வு எடுத்துக்கொள்வது நல்லது.", en: "Rest a little today."),
        .init(ta: "நல்ல செய்தி தேடி வரும்.", en: "Good news comes looking for you."),
        .init(ta: "வாக்குவாதங்களைத் தவிர்க்கவும்.", en: "Avoid arguments."),
        .init(ta: "பொறுமையால் காரியம் கைகூடும்.", en: "Patience gets things done."),
        .init(ta: "பழைய நண்பரைச் சந்திப்பீர்கள்.", en: "You may meet an old friend."),
        .init(ta: "சுப செய்திகள் வந்து சேரும்.", en: "Happy news arrives."),
    ]

    /// Two lines for `rasi` (0 = Mesham … 11 = Meenam) on `day`.
    public static func lines(for day: CalendarDay, rasi: Int) -> [LocalizedText] {
        var state = UInt64(day.year * 10_000 + day.month * 100 + day.day) &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(rasi + 1) &* 0xBF58_476D_1CE4_E5B9
        func next() -> Int {
            state ^= state >> 30; state = state &* 0xBF58_476D_1CE4_E5B9
            state ^= state >> 27; state = state &* 0x94D0_49BB_1331_11EB
            state ^= state >> 31
            return Int(state % 1_000_003)
        }
        return [first[next() % first.count], second[next() % second.count]]
    }
}
