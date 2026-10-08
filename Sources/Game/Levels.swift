import Foundation

// MARK: - The 34 boards
//
// Layouts are original designs in the spirit of the BlackBerry boards:
// full walls, tunnels, diamonds, fortresses, and the infamous silver
// "U" (board 16) and silver gate (board 13). Capsule bricks (`*`) sit in
// fixed positions per board; the capsule *type* is random each game,
// exactly like the original.

struct LevelSpec {
    var name: String
    var map: BoardMap
}

enum Levels {
    static let columnCount = 10

    static let boards: [LevelSpec] = [
        LevelSpec(name: "First Contact", map: [
            "1111111111",
            "11111*1111",
            "1111111111",
            "....**....",
        ]),
        LevelSpec(name: "Double Row", map: [
            "2222222222",
            "2222**2222",
            "..111111..",
            "..1*11*1..",
        ]),
        LevelSpec(name: "Checker", map: [
            "1.1.1.1.1.",
            ".1.1*1.1.1",
            "1.1.1.1.1.",
            ".2.2.2.2.2",
            "2.2.2.2.2.",
        ]),
        LevelSpec(name: "Columns", map: [
            "11..**..11",
            "11..11..11",
            "22..11..22",
            "22..11..22",
            "11..11..11",
        ]),
        LevelSpec(name: "Pyramid", map: [
            "....11....",
            "...1111...",
            "..11**11..",
            ".11111111.",
            "1111111111",
        ]),
        LevelSpec(name: "Diamond", map: [
            "....11....",
            "...1221...",
            "..12**21..",
            ".12211221.",
            "..12**21..",
            "...1221...",
            "....11....",
        ]),
        LevelSpec(name: "Twin Peaks", map: [
            ".11....11.",
            ".111..111.",
            ".11*..*11.",
            ".111..111.",
            "333....333",
        ]),
        LevelSpec(name: "The Wall", map: [
            "3333333333",
            "3*333333*3",
            "2222222222",
            "1111111111",
        ]),
        LevelSpec(name: "Windows", map: [
            "1111111111",
            "1..1111..1",
            "1..1**1..1",
            "1..1111..1",
            "1111111111",
        ]),
        LevelSpec(name: "Crossfire", map: [
            "....11....",
            "....11....",
            "1111**1111",
            "....11....",
            "....11....",
            "2222222222",
        ]),
        LevelSpec(name: "Side Chutes", map: [
            "11......11",
            "*1......1*",
            "11..33..11",
            "11..33..11",
            "11..33..11",
            "1111111111",
        ]),
        LevelSpec(name: "Honeycomb", map: [
            ".11.11.11.",
            "11*11*11*1",
            ".11.11.11.",
            ".22.22.22.",
            "22.22.22.2",
        ]),
        LevelSpec(name: "Silver Gate", map: [
            "SSSS..SSSS",
            "1111..1111",
            "1*11..11*1",
            "1111..1111",
            "2222112222",
        ]),
        LevelSpec(name: "Fortress", map: [
            ".SSSSSSSS.",
            ".S111111S.",
            ".S1*11*1S.",
            ".S111111S.",
            ".S222222S.",
            "..111111..",
        ]),
        LevelSpec(name: "Moat", map: [
            "3333333333",
            "S33333333S",
            "S32*11*23S",
            "S33333333S",
            ".11111111.",
        ]),
        LevelSpec(name: "The Dreaded U", map: [
            "S........S",
            "S...11...S",
            "S..1221..S",
            "S..1**1..S",
            "S..1221..S",
            "SS..11..SS",
            ".SS....SS.",
            ".S222222S.",
        ]),
        LevelSpec(name: "Teeth", map: [
            "11.11.11.1",
            "11.11.11.1",
            "22.22.22.2",
            "**..**..**",
            "3333333333",
        ]),
        LevelSpec(name: "Bunker", map: [
            "..SSSSSS..",
            "..S1111S..",
            "..S1**1S..",
            "1111111111",
            "1*111111*1",
            "2222222222",
        ]),
        LevelSpec(name: "Stripes", map: [
            "1111111111",
            "2222222222",
            "3333333333",
            "4444**4444",
            "3333333333",
        ]),
        LevelSpec(name: "Bullseye", map: [
            "....SS....",
            "...S11S...",
            "..S1221S..",
            ".S122*221S",
            "..S1221S..",
            "...S11S...",
            "....SS....",
        ]),
        LevelSpec(name: "Waterfall", map: [
            "1....**...",
            "11....1...",
            "111...11..",
            ".111..111.",
            "..11.1111*",
            "...1111111",
        ]),
        LevelSpec(name: "Mirror Fall", map: [
            "...**....1",
            "...1....11",
            "..11...111",
            ".111..111.",
            "*1111.11..",
            "1111111...",
        ]),
        LevelSpec(name: "Gridlock", map: [
            "S1S1S1S1S1",
            "1S1S1S1S1S",
            "S1*1S1*1S1",
            "1111111111",
            "2222222222",
        ]),
        LevelSpec(name: "Vault", map: [
            "SSSSSSSSSS",
            "S11111111S",
            "S1******1S",
            "S11111111S",
            "S22222222S",
            "..111111..",
        ]),
        LevelSpec(name: "Arena", map: [
            "11S1111S11",
            "11S1111S11",
            "**S1111S**",
            "22S2222S22",
            "11S1111S11",
            "..S1111S..",
        ]),
        LevelSpec(name: "High Voltage", map: [
            "4*.4444.*4",
            "4444444444",
            ".33333333.",
            ".3*3333*3.",
            "..222222..",
            "..111111..",
        ]),
        LevelSpec(name: "Cathedral", map: [
            "....SS....",
            "...S44S...",
            "..S4444S..",
            ".S443*344S",
            "S44333344S",
            "SS333333SS",
            ".11111111.",
        ]),
        LevelSpec(name: "Sandstorm", map: [
            "2.2.2.2.2.",
            "*2*2*2*2*2",
            "3.3.3.3.3.",
            ".3.3.3.3.3",
            "4444444444",
        ]),
        LevelSpec(name: "Iron Curtain", map: [
            "SSSSSSSSSS",
            "1111111111",
            "1*111111*1",
            "2222222222",
            "2*222222*2",
            "3333333333",
        ]),
        LevelSpec(name: "Gauntlet", map: [
            "S...11...S",
            "S..1221..S",
            "S..2**2..S",
            "S.122221.S",
            "S.111111.S",
            "SS......SS",
            "4444444444",
        ]),
        LevelSpec(name: "Crown", map: [
            "4...44...4",
            "44..44..44",
            "444.44.444",
            "*44444444*",
            ".44444444.",
            ".22222222.",
        ]),
        LevelSpec(name: "Deep Field", map: [
            "1111111111",
            "1222222221",
            "1233333321",
            "123*44*321",
            "1233333321",
            "1222222221",
            "1111111111",
        ]),
        LevelSpec(name: "Silver Storm", map: [
            "S.S.S.S.S.",
            "4444444444",
            "S.S.S.S.S.",
            "33333*3333",
            "2222222222",
            ".*11..11*.",
        ]),
        LevelSpec(name: "Last Stand", map: [
            "SSSSSSSSSS",
            "S44444444S",
            "S4*4444*4S",
            "S43333334S",
            "S433**334S",
            "S43333334S",
            "S42222224S",
            ".11111111.",
        ]),
    ]

    static var count: Int { boards.count }

    static func spec(forLevel level: Int) -> LevelSpec {
        boards[(level - 1) % boards.count]
    }

    /// Parses a board map into brick specs with (column, row) coordinates.
    static func parse(_ map: BoardMap) -> [(col: Int, row: Int, spec: BrickSpec)] {
        var out: [(col: Int, row: Int, spec: BrickSpec)] = []
        for (row, line) in map.enumerated() {
            for (col, ch) in line.enumerated() {
                let spec: BrickSpec?
                switch ch {
                case "1": spec = BrickSpec(kind: .hits(1))
                case "2": spec = BrickSpec(kind: .hits(2))
                case "3": spec = BrickSpec(kind: .hits(3))
                case "4": spec = BrickSpec(kind: .hits(4))
                case "S": spec = BrickSpec(kind: .silver)
                case "*": spec = BrickSpec(kind: .hits(1), hidesCapsule: true)
                default: spec = nil
                }
                if let spec { out.append((col, row, spec)) }
            }
        }
        return out
    }
}
