/// A term in both card languages. Templates choose which to show (Tamil, English, or both),
/// so no block ever hard-codes a language.
public struct LocalizedText: Hashable, Sendable, Codable {
    public var ta: String
    public var en: String

    public init(ta: String, en: String) {
        self.ta = ta
        self.en = en
    }
}

public enum Names {
    public static let tamilMonths: [LocalizedText] = [
        .init(ta: "சித்திரை", en: "Chithirai"),
        .init(ta: "வைகாசி", en: "Vaikasi"),
        .init(ta: "ஆனி", en: "Aani"),
        .init(ta: "ஆடி", en: "Aadi"),
        .init(ta: "ஆவணி", en: "Aavani"),
        .init(ta: "புரட்டாசி", en: "Purattasi"),
        .init(ta: "ஐப்பசி", en: "Aippasi"),
        .init(ta: "கார்த்திகை", en: "Karthigai"),
        .init(ta: "மார்கழி", en: "Margazhi"),
        .init(ta: "தை", en: "Thai"),
        .init(ta: "மாசி", en: "Maasi"),
        .init(ta: "பங்குனி", en: "Panguni"),
    ]

    /// The 60-year cycle, starting with Prabhava (1987–88).
    public static let tamilYears: [LocalizedText] = [
        .init(ta: "பிரபவ", en: "Prabhava"), .init(ta: "விபவ", en: "Vibhava"),
        .init(ta: "சுக்ல", en: "Sukla"), .init(ta: "பிரமோதூத", en: "Pramodhoota"),
        .init(ta: "பிரசோற்பத்தி", en: "Prajorpathi"), .init(ta: "ஆங்கீரச", en: "Aangirasa"),
        .init(ta: "ஸ்ரீமுக", en: "Srimukha"), .init(ta: "பவ", en: "Bhava"),
        .init(ta: "யுவ", en: "Yuva"), .init(ta: "தாது", en: "Dhaathu"),
        .init(ta: "ஈஸ்வர", en: "Eeswara"), .init(ta: "வெகுதானிய", en: "Vehudhanya"),
        .init(ta: "பிரமாதி", en: "Pramathi"), .init(ta: "விக்கிரம", en: "Vikrama"),
        .init(ta: "விஷு", en: "Vishu"), .init(ta: "சித்திரபானு", en: "Chitrabhanu"),
        .init(ta: "சுபானு", en: "Subhanu"), .init(ta: "தாரண", en: "Dharana"),
        .init(ta: "பார்த்திப", en: "Paarthiba"), .init(ta: "விய", en: "Viya"),
        .init(ta: "சர்வஜித்", en: "Sarvajith"), .init(ta: "சர்வதாரி", en: "Sarvadhari"),
        .init(ta: "விரோதி", en: "Virodhi"), .init(ta: "விக்ருதி", en: "Vikruthi"),
        .init(ta: "கர", en: "Kara"), .init(ta: "நந்தன", en: "Nandhana"),
        .init(ta: "விஜய", en: "Vijaya"), .init(ta: "ஜய", en: "Jaya"),
        .init(ta: "மன்மத", en: "Manmatha"), .init(ta: "துன்முகி", en: "Dhunmuki"),
        .init(ta: "ஹேவிளம்பி", en: "Hevilambi"), .init(ta: "விளம்பி", en: "Vilambi"),
        .init(ta: "விகாரி", en: "Vikari"), .init(ta: "சார்வரி", en: "Sarvari"),
        .init(ta: "பிலவ", en: "Plava"), .init(ta: "சுபகிருது", en: "Subhakruthu"),
        .init(ta: "சோபகிருது", en: "Sobhakruthu"), .init(ta: "குரோதி", en: "Krodhi"),
        .init(ta: "விசுவாவசு", en: "Visuvaavasu"), .init(ta: "பராபவ", en: "Parabhava"),
        .init(ta: "பிலவங்க", en: "Plavanga"), .init(ta: "கீலக", en: "Keelaka"),
        .init(ta: "சௌமிய", en: "Saumya"), .init(ta: "சாதாரண", en: "Sadharana"),
        .init(ta: "விரோதகிருது", en: "Virodhakruthu"), .init(ta: "பரிதாபி", en: "Paridhabi"),
        .init(ta: "பிரமாதீச", en: "Pramadhicha"), .init(ta: "ஆனந்த", en: "Aanandha"),
        .init(ta: "ராட்சச", en: "Rakshasa"), .init(ta: "நள", en: "Nala"),
        .init(ta: "பிங்கள", en: "Pingala"), .init(ta: "காளயுக்தி", en: "Kalayukthi"),
        .init(ta: "சித்தார்த்தி", en: "Siddharthi"), .init(ta: "ரௌத்திரி", en: "Raudhri"),
        .init(ta: "துன்மதி", en: "Dhunmathi"), .init(ta: "துந்துபி", en: "Dhundhubhi"),
        .init(ta: "ருத்ரோத்காரி", en: "Rudhrodhgaari"), .init(ta: "ரக்தாட்சி", en: "Raktakshi"),
        .init(ta: "குரோதன", en: "Krodhana"), .init(ta: "அட்சய", en: "Akshaya"),
    ]

    /// Sunday first, matching `CalendarDay.weekday` (1 = Sunday).
    public static let weekdays: [LocalizedText] = [
        .init(ta: "ஞாயிறு", en: "Sunday"),
        .init(ta: "திங்கள்", en: "Monday"),
        .init(ta: "செவ்வாய்", en: "Tuesday"),
        .init(ta: "புதன்", en: "Wednesday"),
        .init(ta: "வியாழன்", en: "Thursday"),
        .init(ta: "வெள்ளி", en: "Friday"),
        .init(ta: "சனி", en: "Saturday"),
    ]

    /// Gregorian month names, as Tamil calendars print them ("அக்டோபர் 2026").
    public static let gregorianMonths: [LocalizedText] = [
        .init(ta: "ஜனவரி", en: "January"), .init(ta: "பிப்ரவரி", en: "February"),
        .init(ta: "மார்ச்", en: "March"), .init(ta: "ஏப்ரல்", en: "April"),
        .init(ta: "மே", en: "May"), .init(ta: "ஜூன்", en: "June"),
        .init(ta: "ஜூலை", en: "July"), .init(ta: "ஆகஸ்ட்", en: "August"),
        .init(ta: "செப்டம்பர்", en: "September"), .init(ta: "அக்டோபர்", en: "October"),
        .init(ta: "நவம்பர்", en: "November"), .init(ta: "டிசம்பர்", en: "December"),
    ]

    public static let directions: [LocalizedText] = [
        .init(ta: "கிழக்கு", en: "East"), .init(ta: "தெற்கு", en: "South"),
        .init(ta: "மேற்கு", en: "West"), .init(ta: "வடக்கு", en: "North"),
    ]

    public static let rahuKalam = LocalizedText(ta: "ராகு", en: "Rahu")
    public static let yamagandam = LocalizedText(ta: "எமகண்டம்", en: "Yamagandam")
    public static let kuligai = LocalizedText(ta: "குளிகை", en: "Kuligai")
    public static let soolam = LocalizedText(ta: "சூலம்", en: "Soolam")
    public static let sunrise = LocalizedText(ta: "சூரிய உதயம்", en: "Sunrise")
    public static let sunset = LocalizedText(ta: "அஸ்தமனம்", en: "Sunset")
}
