import Foundation

/// A couplet from the Thirukkural (c. 2,000 years old), printed as the day's thought, as many
/// Tamil calendars do. English lines are plain-language paraphrases.
public struct Kural: Hashable, Sendable {
    public var number: Int
    public var tamil: String
    public var meaning: String

    /// One couplet per day, cycling through the list.
    public static func of(_ day: CalendarDay) -> Kural {
        let dayNumber = CalendarDay(year: 2000, month: 1, day: 1).days(to: day)
        return all[((dayNumber % all.count) + all.count) % all.count]
    }

    public static let all: [Kural] = [
        .init(number: 1, tamil: "அகர முதல எழுத்தெல்லாம் ஆதி\nபகவன் முதற்றே உலகு",
              meaning: "As A is the first of letters, God is the first of the world."),
        .init(number: 391, tamil: "கற்க கசடறக் கற்பவை கற்றபின்\nநிற்க அதற்குத் தக",
              meaning: "Learn well what is worth learning, then live by it."),
        .init(number: 396, tamil: "தொட்டனைத் தூறும் மணற்கேணி மாந்தர்க்குக்\nகற்றனைத் தூறும் அறிவு",
              meaning: "Dig a sand well deeper and more water springs; learn more and more wisdom flows."),
        .init(number: 100, tamil: "இனிய உளவாக இன்னாத கூறல்\nகனியிருப்பக் காய்கவர்ந் தற்று",
              meaning: "Harsh words when kind ones are at hand: like picking raw fruit beside the ripe."),
        .init(number: 72, tamil: "அன்பிலார் எல்லாம் தமக்குரியர் அன்புடையார்\nஎன்பும் உரியர் பிறர்க்கு",
              meaning: "The loveless keep all for themselves; the loving give even their bones to others."),
        .init(number: 423, tamil: "எப்பொருள் யார்யார்வாய்க் கேட்பினும் அப்பொருள்\nமெய்ப்பொருள் காண்பது அறிவு",
              meaning: "Whoever says it, wisdom is finding the truth in what is said."),
        .init(number: 110, tamil: "எந்நன்றி கொன்றார்க்கும் உய்வுண்டாம் உய்வில்லை\nசெய்ந்நன்றி கொன்ற மகற்கு",
              meaning: "Every wrong can be redeemed, except forgetting a kindness."),
        .init(number: 314, tamil: "இன்னாசெய் தாரை ஒறுத்தல் அவர்நாண\nநன்னயம் செய்து விடல்",
              meaning: "Answer those who harm you with good, and let that shame them."),
        .init(number: 619, tamil: "தெய்வத்தான் ஆகா தெனினும் முயற்சிதன்\nமெய்வருத்தக் கூலி தரும்",
              meaning: "Even if fate says no, effort pays the wages of your labour."),
        .init(number: 664, tamil: "சொல்லுதல் யார்க்கும் எளிய அரியவாம்\nசொல்லிய வண்ணம் செயல்",
              meaning: "Saying is easy for anyone; doing what you said is hard."),
        .init(number: 102, tamil: "காலத்தி னாற்செய்த நன்றி சிறிதெனினும்\nஞாலத்தின் மாணப் பெரிது",
              meaning: "Help given in time, however small, is greater than the world."),
        .init(number: 129, tamil: "தீயினாற் சுட்டபுண் உள்ளாறும் ஆறாதே\nநாவினாற் சுட்ட வடு",
              meaning: "A burn from fire heals; a scar from the tongue never does."),
        .init(number: 435, tamil: "வருமுன்னர்க் காவாதான் வாழ்க்கை எரிமுன்னர்\nவைத்தூறு போலக் கெடும்",
              meaning: "A life that doesn't guard against trouble burns like straw before a fire."),
        .init(number: 467, tamil: "எண்ணித் துணிக கருமம் துணிந்தபின்\nஎண்ணுவம் என்பது இழுக்கு",
              meaning: "Think, then act; thinking after acting is a fault."),
        .init(number: 66, tamil: "குழலினிது யாழினிது என்பதம் மக்கள்\nமழலைச்சொல் கேளா தவர்",
              meaning: "Only those who never heard their children's prattle call the flute sweet."),
        .init(number: 948, tamil: "நோய்நாடி நோய்முதல் நாடி அதுதணிக்கும்\nவாய்நாடி வாய்ப்பச் செயல்",
              meaning: "Find the illness, its cause and its cure, then treat it well."),
        .init(number: 225, tamil: "ஆற்றுவார் ஆற்றல் பசியாற்றல் அப்பசியை\nமாற்றுவார் ஆற்றலின் பின்",
              meaning: "Bearing hunger is strength; relieving another's hunger is greater strength."),
        .init(number: 247, tamil: "அருளில்லார்க் கவ்வுலகம் இல்லை பொருளில்லார்க்\nகிவ்வுலகம் இல்லாகி யாங்கு",
              meaning: "As this world is not for the penniless, the next is not for the unkind."),
        .init(number: 31, tamil: "சிறப்பீனும் செல்வமும் ஈனும் அறத்தினூஉங்\nகாக்கம் எவனோ உயிர்க்கு",
              meaning: "Virtue brings honour and wealth; what greater good is there?"),
        .init(number: 397, tamil: "யாதானும் நாடாமால் ஊராமால் என்னொருவன்\nசாந்துணையுங் கல்லாத வாறு",
              meaning: "To the learned every land is home; why stop learning before the end?"),
    ]
}
