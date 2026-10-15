import RasiCore
import SwiftUI

/// The Classic sheet, laid out like a Tamil Nadu tear-off calendar: Gregorian date on the
/// left, Tamil date on the right, dense timings underneath. In milestone 3 this is split into
/// reusable blocks driven by a JSON layout; for now it is one view.
struct ClassicSheet: View {
    let context: DayContext

    private static let englishWeekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private func tamil(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom("Tamil Sangam MN", size: size).weight(bold ? .bold : .regular)
    }

    var body: some View {
        let c = context
        ZStack(alignment: .top) {
            Rectangle().fill(Ink.paper)

            VStack(spacing: 0) {
                // Two-column top: Gregorian | Tamil
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(c.gregorianMonth.ta) \(String(c.day.year))")
                            .font(tamil(13))
                        Text("\(c.day.day)")
                            .font(.system(size: 112, weight: .black, design: .serif).width(.condensed))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.top, -6)
                        Text(Self.englishWeekdays[c.day.weekday - 1])
                            .font(.system(size: 28, weight: .heavy, design: .serif))
                            .padding(.top, -14)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(Ink.black).frame(width: 1).padding(.vertical, 6)

                    VStack(spacing: 0) {
                        Text(c.tamil.yearName.ta).font(tamil(13))
                        Text(c.tamil.month.ta).font(tamil(16, bold: true)).padding(.top, 2)
                        Text("\(c.tamil.day)")
                            .font(.system(size: 64, weight: .bold, design: .serif))
                            .padding(.top, 2)
                        Text(c.weekday.ta).font(tamil(22, bold: true)).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .frame(height: 200)

                Rectangle().fill(Ink.black).frame(height: 1).padding(.horizontal, 10)

                VStack(spacing: 7) {
                    Text("\(Names.rahuKalam.ta) \(c.range(c.timings.rahuKalam))   "
                         + "\(Names.kuligai.ta) \(c.range(c.timings.kuligai))   "
                         + "\(Names.yamagandam.ta) \(c.range(c.timings.yamagandam))")
                        .font(tamil(12.5, bold: true))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 14) {
                        if let rise = c.sunrise, let set = c.sunset {
                            Text("\(Names.sunrise.ta) \(c.clock(rise))")
                            Text("\(Names.sunset.ta) \(c.clock(set))")
                        }
                        Text("\(Names.soolam.ta): \(c.timings.soolam.ta)")
                    }
                    .font(tamil(11))

                    Text("Tithi, nakshatram, festivals and nalla neram arrive in milestone 8")
                        .font(.system(size: 9.5, design: .serif).italic())
                        .foregroundStyle(Ink.faded)
                        .padding(.top, 4)
                }
                .padding(.top, 12)
                .padding(.horizontal, 10)

                Spacer()

                // Footer: where and how this sheet was reckoned.
                HStack {
                    Text(c.location.name)
                    Spacer()
                    Text(c.style == .traditional ? "வாக்கியம்" : "திருக்கணிதம்")
                }
                .font(tamil(9.5))
                .foregroundStyle(Ink.red)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .foregroundStyle(Ink.black)
        }
    }
}
