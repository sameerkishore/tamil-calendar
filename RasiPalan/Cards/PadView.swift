import SwiftUI

/// The whole desk object: red binding strip on top, the stack of sheets below.
struct PadView: View {
    let day: CalendarDay
    /// False when rendering offscreen (snapshots), where AppKit-backed views can't draw.
    var interactive = true

    static let sheetSize = CGSize(width: 300, height: 380)
    static let gripHeight: CGFloat = 26
    /// Transparent space around the pad so the shadow isn't clipped by the window.
    static let margin: CGFloat = 28
    /// How many sheet edges peek out under the top sheet to suggest thickness.
    static let stackDepth = 4
    static let stackStep: CGFloat = 2

    static var windowSize: CGSize {
        CGSize(width: sheetSize.width + margin * 2,
               height: gripHeight + sheetSize.height + CGFloat(stackDepth) * stackStep + margin * 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            BindingStrip()
                .frame(height: Self.gripHeight)
                .overlay { if interactive { WindowDragHandle() } }
                .help("Drag here to move the calendar")
                .zIndex(1)

            ZStack(alignment: .top) {
                ForEach((1...Self.stackDepth).reversed(), id: \.self) { i in
                    Rectangle()
                        .fill(Ink.paper)
                        .overlay(Color.black.opacity(0.04 + Double(i) * 0.025))
                        .frame(width: Self.sheetSize.width, height: Self.sheetSize.height)
                        .offset(y: CGFloat(i) * Self.stackStep)
                }
                PlaceholderSheet(day: day)
                    .frame(width: Self.sheetSize.width, height: Self.sheetSize.height)
            }
            .frame(height: Self.sheetSize.height + CGFloat(Self.stackDepth) * Self.stackStep, alignment: .top)
        }
        .frame(width: Self.sheetSize.width)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        .padding(Self.margin)
    }
}

enum Ink {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let black = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let red = Color(red: 0.82, green: 0.10, blue: 0.12)
    static let faded = Color(red: 0.10, green: 0.09, blue: 0.08).opacity(0.35)
}

/// The cloth-and-glue strip the sheets are bound into, with two staples.
struct BindingStrip: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Ink.red)
            // Woven texture hint; the real paper/cloth shader comes in milestone 3.
            Rectangle()
                .fill(.white.opacity(0.10))
                .mask(
                    HStack(spacing: 3) {
                        ForEach(0..<80, id: \.self) { _ in Rectangle().frame(width: 1) }
                    }
                )
            HStack {
                Staple()
                Spacer()
                Staple()
            }
            .padding(.horizontal, 46)
        }
    }
}

private struct Staple: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(LinearGradient(colors: [.white.opacity(0.9), .gray], startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 3)
            .shadow(color: .black.opacity(0.4), radius: 0.5, y: 0.5)
    }
}

/// Milestone-1 stand-in for the Classic card. Real panchangam data arrives in milestone 2,
/// the block-based template system in milestone 3.
struct PlaceholderSheet: View {
    let day: CalendarDay

    private static let tamilGregorianMonths = [
        "ஜனவரி", "பிப்ரவரி", "மார்ச்", "ஏப்ரல்", "மே", "ஜூன்",
        "ஜூலை", "ஆகஸ்ட்", "செப்டம்பர்", "அக்டோபர்", "நவம்பர்", "டிசம்பர்",
    ]
    private static let tamilWeekdays = ["ஞாயிறு", "திங்கள்", "செவ்வாய்", "புதன்", "வியாழன்", "வெள்ளி", "சனி"]
    private static let englishWeekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private func tamil(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom("Tamil Sangam MN", size: size).weight(bold ? .bold : .regular)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Ink.paper)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(Self.tamilGregorianMonths[day.month - 1]) \(String(day.year))")
                            .font(tamil(13))
                        Text("\(day.day)")
                            .font(.system(size: 112, weight: .black, design: .serif).width(.condensed))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.top, -6)
                        Text(Self.englishWeekdays[day.weekday - 1])
                            .font(.system(size: 28, weight: .heavy, design: .serif))
                            .padding(.top, -14)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(Ink.black).frame(width: 1).padding(.vertical, 6)

                    VStack(spacing: 2) {
                        Text("—").font(tamil(13))
                        Text("—").font(tamil(15, bold: true))
                        Text("—")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .foregroundStyle(Ink.faded)
                            .padding(.vertical, 6)
                        Text(Self.tamilWeekdays[day.weekday - 1]).font(tamil(22, bold: true))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .frame(height: 200)

                Rectangle().fill(Ink.black).frame(height: 1).padding(.horizontal, 10)

                VStack(spacing: 6) {
                    Text("திதி —     நட்சத்திரம் —")
                    Text("ராகு —   குளிகை —   எமகண்டம் —")
                    Text("Panchangam details arrive in milestone 2")
                        .font(.system(size: 10, design: .serif).italic())
                        .foregroundStyle(Ink.faded)
                }
                .font(tamil(12))
                .padding(.top, 14)

                Spacer()

                HStack(spacing: 6) {
                    Text("நல்ல நேரம்:").font(tamil(12, bold: true))
                    Text("—").font(tamil(12))
                }
                .foregroundStyle(Ink.red)
                .padding(.bottom, 14)
            }
            .foregroundStyle(Ink.black)
        }
    }
}

#Preview {
    PadView(day: .today())
}
