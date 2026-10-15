import Foundation

/// Festivals, fasts and notable days printed on the sheet. Lunar ones follow the tithi or star
/// at sunrise and the Tamil month; national days and birthdays follow the Gregorian date.
public enum Observances {
    public static func list(day: CalendarDay, tamil: TamilDate, nextTamil: TamilDate, panchangam p: Panchangam) -> [LocalizedText] {
        var out: [LocalizedText] = []
        let month = tamil.monthIndex, ti = p.tithiIndex, star = p.nakshatraIndex
        func add(_ ta: String, _ en: String) { out.append(LocalizedText(ta: ta, en: en)) }

        // Festivals first: they matter most.
        if month == 0 && tamil.day == 1 { add("தமிழ்ப் புத்தாண்டு", "Tamil New Year") }
        if nextTamil.monthIndex == 9 && nextTamil.day == 1 { add("போகிப் பண்டிகை", "Bhogi") }
        if month == 9 && tamil.day == 1 { add("தைப்பொங்கல்", "Thai Pongal") }
        if month == 9 && tamil.day == 2 { add("திருவள்ளுவர் தினம்", "Thiruvalluvar Day") }
        if month == 3 && tamil.day == 18 { add("ஆடிப் பெருக்கு", "Aadi Perukku") }
        if month == 4 && ti == 3 { add("விநாயகர் சதுர்த்தி", "Vinayagar Chaturthi") }
        if month == 4 && ti == 22 { add("கோகுலாஷ்டமி", "Krishna Jayanthi") }
        let navaratriSeason = month == 5 || (month == 6 && tamil.day <= 12)
        if navaratriSeason && ti == 0 { add("நவராத்திரி ஆரம்பம்", "Navaratri begins") }
        if navaratriSeason && ti == 8 { add("சரஸ்வதி பூஜை, ஆயுத பூஜை", "Saraswathi & Ayudha Pooja") }
        if navaratriSeason && ti == 9 { add("விஜயதசமி", "Vijayadasami") }
        if month == 6 && ti == 28 { add("தீபாவளி", "Deepavali") }
        if month == 7 && star == 2 { add("திருக்கார்த்திகை தீபம்", "Karthigai Deepam") }
        if month == 8 && ti == 10 { add("வைகுண்ட ஏகாதசி", "Vaikunta Ekadasi") }
        if month == 9 && star == 7 { add("தைப்பூசம்", "Thaipusam") }
        if month == 10 && ti == 28 { add("மகா சிவராத்திரி", "Maha Shivaratri") }
        if month == 11 && star == 11 { add("பங்குனி உத்திரம்", "Panguni Uthiram") }

        // Monthly observances by tithi and star.
        switch ti {
        case 29: add("அமாவாசை", "Amavasai")
        case 14: add("பௌர்ணமி", "Pournami")
        case 10, 25: if !(month == 8 && ti == 10) { add("ஏகாதசி விரதம்", "Ekadasi fast") }
        case 5: add("சஷ்டி விரதம்", "Sashti fast")
        case 12, 27: add("பிரதோஷம்", "Pradosham")
        case 18: add("சங்கடஹர சதுர்த்தி", "Sankatahara Chaturthi")
        default: break
        }
        if star == 2 && month != 7 { add("கார்த்திகை விரதம்", "Karthigai fast") }
        if star == 21 { add("திருவோண விரதம்", "Thiruvonam fast") }

        // National days and birthdays.
        switch (day.month, day.day) {
        case (1, 1): add("ஆங்கிலப் புத்தாண்டு", "New Year's Day")
        case (1, 26): add("குடியரசு தினம்", "Republic Day")
        case (5, 1): add("மே தினம்", "May Day")
        case (7, 15): add("காமராஜர் பிறந்த நாள்", "Kamarajar's birthday")
        case (8, 15): add("சுதந்திர தினம்", "Independence Day")
        case (9, 5): add("ஆசிரியர் தினம்", "Teachers' Day")
        case (10, 2): add("காந்தி ஜெயந்தி", "Gandhi Jayanthi")
        case (10, 15): add("அப்துல் கலாம் பிறந்த நாள்", "Abdul Kalam's birthday")
        case (11, 14): add("குழந்தைகள் தினம்", "Children's Day")
        case (12, 11): add("பாரதியார் பிறந்த நாள்", "Bharathiyar's birthday")
        case (12, 25): add("கிறிஸ்துமஸ்", "Christmas")
        default: break
        }
        return out
    }
}
