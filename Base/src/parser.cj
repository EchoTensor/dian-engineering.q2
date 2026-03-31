package midi

import std.collection.*
import std.convert.*

// ============================================================
// 解析器：文本乐谱 → MIDI 轨道数据（新语法）
// ============================================================

public class NoteInfo {
    public var pitch: UInt8
    public var durationTicks: UInt32

    public init(pitch: UInt8, durationTicks: UInt32) {
        this.pitch = pitch
        this.durationTicks = durationTicks
    }
}

public class ChordInfo {
    public var pitches: ArrayList<UInt8>
    public var durationTicks: UInt32

    public init(pitches: ArrayList<UInt8>, durationTicks: UInt32) {
        this.pitches = pitches
        this.durationTicks = durationTicks
    }
}

public enum MusicElement {
    | SingleNote(NoteInfo)
    | Chord(ChordInfo)
    | Rest(UInt32)
}

public class TrackData {
    var name: String
    var instrument: Int64
    var elements: ArrayList<MusicElement>

    init(name: String) {
        this.name = name
        this.instrument = -1
        this.elements = ArrayList<MusicElement>()
    }
}

public class ScoreData {
    public var tempo: Int64
    public var tracks: ArrayList<TrackData>

    public init() {
        this.tempo = 120
        this.tracks = ArrayList<TrackData>()
    }
}

// ============================================================
// 辅助函数
// ============================================================

func basePitch(noteRune: Rune): Int64 {
    if (noteRune == r'C') { return 0 }
    if (noteRune == r'D') { return 2 }
    if (noteRune == r'E') { return 4 }
    if (noteRune == r'F') { return 5 }
    if (noteRune == r'G') { return 7 }
    if (noteRune == r'A') { return 9 }
    if (noteRune == r'B') { return 11 }
    return -1
}

func instrumentNumber(name: String): Int64 {
    let lower = name.toAsciiLower()
    if (lower == "piano" || lower == "acoustic grand piano") { return 0 }
    if (lower == "bright acoustic piano") { return 1 }
    if (lower == "electric grand piano") { return 2 }
    if (lower == "honky-tonk piano") { return 3 }
    if (lower == "music_box" || lower == "music box") { return 10 }
    if (lower == "glockenspiel") { return 9 }
    if (lower == "vibraphone") { return 11 }
    if (lower == "marimba") { return 12 }
    if (lower == "xylophone") { return 13 }
    if (lower == "nylon guitar" || lower == "acoustic guitar (nylon)") { return 24 }
    if (lower == "steel guitar" || lower == "acoustic guitar (steel)") { return 25 }
    if (lower == "guitar" || lower == "electric guitar") { return 24 }
    if (lower == "clean guitar" || lower == "electric clean guitar") { return 27 }
    if (lower == "overdriven guitar") { return 29 }
    if (lower == "distortion guitar") { return 30 }
    if (lower == "acoustic bass") { return 32 }
    if (lower == "bass" || lower == "electric bass") { return 33 }
    if (lower == "slap bass") { return 36 }
    if (lower == "synth bass") { return 38 }
    if (lower == "violin") { return 40 }
    if (lower == "viola") { return 41 }
    if (lower == "cello") { return 42 }
    if (lower == "contrabass") { return 43 }
    if (lower == "harp") { return 46 }
    if (lower == "strings" || lower == "string ensemble") { return 48 }
    if (lower == "synth strings") { return 50 }
    if (lower == "choir" || lower == "choir aahs") { return 52 }
    if (lower == "voice" || lower == "voice oohs") { return 53 }
    if (lower == "trumpet") { return 56 }
    if (lower == "trombone") { return 57 }
    if (lower == "tuba") { return 58 }
    if (lower == "french horn") { return 60 }
    if (lower == "brass" || lower == "brass section") { return 61 }
    if (lower == "soprano sax") { return 64 }
    if (lower == "alto sax") { return 65 }
    if (lower == "tenor sax") { return 66 }
    if (lower == "baritone sax") { return 67 }
    if (lower == "oboe") { return 68 }
    if (lower == "english horn") { return 69 }
    if (lower == "bassoon") { return 70 }
    if (lower == "clarinet") { return 71 }
    if (lower == "piccolo") { return 72 }
    if (lower == "flute") { return 73 }
    if (lower == "recorder") { return 74 }
    if (lower == "pan flute") { return 75 }
    if (lower == "ocarina") { return 79 }
    if (lower == "lead square" || lower == "square") { return 80 }
    if (lower == "lead sawtooth" || lower == "sawtooth") { return 81 }
    if (lower == "pad strings" || lower == "synth pad") { return 89 }
    if (lower == "sitar") { return 104 }
    if (lower == "banjo") { return 105 }
    if (lower == "steel drums") { return 114 }
    return 0
}

func durationToTicks(duration: Int64, dotted: Bool): UInt32 {
    if (duration <= 0) { return 480 }
    var ticks = UInt32(480 * 4 / duration)
    if (dotted) {
        ticks = ticks + ticks / 2
    }
    ticks
}

func isNoteName(ch: Rune): Bool {
    ch == r'A' || ch == r'B' || ch == r'C' || ch == r'D' || ch == r'E' || ch == r'F' || ch == r'G'
}

func isDigitRune(ch: Rune): Bool {
    ch >= r'0' && ch <= r'9'
}

func isSpaceRune(ch: Rune): Bool {
    ch == r' ' || ch == r'\t'
}

func isWhitespace(ch: Rune): Bool {
    ch == r' ' || ch == r'\t' || ch == r'\n' || ch == r'\r'
}

func isAlpha(ch: Rune): Bool {
    (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || ch == r'_'
}

func isAlphaNum(ch: Rune): Bool {
    isAlpha(ch) || isDigitRune(ch)
}

func runeToDigit(ch: Rune): Int64 {
    ch.position() - r'0'.position()
}

// ============================================================
// Strip // comments from input
// ============================================================
func stripComments(input: String): String {
    let lines = input.split("\n")
    let sb = StringBuilder()
    for (line in lines) {
        let runes = line.toRuneArray()
        let lineSize = runes.size
        var i: Int64 = 0
        let lineSb = StringBuilder()
        while (i < lineSize) {
            if (i + 1 < lineSize && runes[i] == r'/' && runes[i + 1] == r'/') {
                break
            }
            lineSb.append(runes[i])
            i++
        }
        sb.append(lineSb.toString())
        sb.append(r'\n')
    }
    sb.toString()
}

// ============================================================
// 流式解析器
// ============================================================

class Parser {
    var runes: Array<Rune>
    var pos: Int64
    var size: Int64
    var variables: HashMap<String, ArrayList<MusicElement>>

    init(input: String) {
        let cleaned = stripComments(input)
        this.runes = cleaned.toRuneArray()
        this.size = this.runes.size
        this.pos = 0
        this.variables = HashMap<String, ArrayList<MusicElement>>()
    }

    // 跳过所有空白字符（含换行）
    func skipWhitespace(): Unit {
        while (pos < size && isWhitespace(runes[pos])) {
            pos++
        }
    }

    // 仅跳过空格和制表符（不跳换行）
    func skipSpaces(): Unit {
        while (pos < size && isSpaceRune(runes[pos])) {
            pos++
        }
    }

    func peek(): Rune {
        if (pos < size) { runes[pos] } else { r'\0' }
    }

    func advance(): Rune {
        let ch = runes[pos]
        pos++
        ch
    }

    // 读取一个标识符（字母、数字、下划线组成）
    func readIdentifier(): String {
        let sb = StringBuilder()
        while (pos < size && isAlphaNum(runes[pos])) {
            sb.append(runes[pos])
            pos++
        }
        sb.toString()
    }

    // 读取一个整数，默认返回4
    func readNumber(): Int64 {
        var num: Int64 = 0
        var found = false
        while (pos < size && isDigitRune(runes[pos])) {
            num = num * 10 + runeToDigit(runes[pos])
            pos++
            found = true
        }
        if (!found) { return 4 }
        num
    }

    // 读取双引号括起来的字符串
    func readQuotedString(): String {
        if (pos < size && runes[pos] == r'"') {
            pos++
        }
        let sb = StringBuilder()
        while (pos < size && runes[pos] != r'"') {
            sb.append(runes[pos])
            pos++
        }
        if (pos < size && runes[pos] == r'"') {
            pos++
        }
        sb.toString()
    }

    // 解析冒号后的时值: `:4` 或 `:4.`
    func parseDuration(): UInt32 {
        if (pos < size && runes[pos] == r':') {
            pos++
        }
        let dur = readNumber()
        var dotted = false
        if (pos < size && runes[pos] == r'.') {
            dotted = true
            pos++
        }
        durationToTicks(dur, dotted)
    }

    // 解析单个音高，如 C4, D#5, Fb3
    // 返回 MIDI 音高值，失败返回 -1
    func parsePitch(): Int64 {
        if (pos >= size || !isNoteName(runes[pos])) { return -1 }
        let base = basePitch(runes[pos])
        pos++

        var offset: Int64 = 0
        if (pos < size && runes[pos] == r'#') {
            offset = 1
            pos++
        } else if (pos < size && runes[pos] == r'b') {
            // 'b' 作为降号：后面紧跟数字才认定为降号
            if (pos + 1 < size && isDigitRune(runes[pos + 1])) {
                offset = -1
                pos++
            }
            // 否则不消费（可能是 B 音符名后的其他内容）
        }

        if (pos >= size || !isDigitRune(runes[pos])) { return -1 }
        let octave = runeToDigit(runes[pos])
        pos++

        (octave + 1) * 12 + base + offset
    }

    // 解析花括号块内的音乐元素，直到遇到 '}' 或文件尾
    func parseElements(): ArrayList<MusicElement> {
        let elements = ArrayList<MusicElement>()

        while (pos < size) {
            skipWhitespace()
            if (pos >= size) { break }

            let ch = runes[pos]

            // 遇到 '}' 停止（不消费）
            if (ch == r'}') { break }

            // 休止符: _:duration
            if (ch == r'_') {
                pos++
                let ticks = parseDuration()
                elements.add(MusicElement.Rest(ticks))
                continue
            }

            // 和弦: [C4 E4 G4]:duration
            if (ch == r'[') {
                pos++ // 跳过 '['
                let pitches = ArrayList<UInt8>()
                while (pos < size && runes[pos] != r']') {
                    skipWhitespace()
                    if (pos < size && runes[pos] == r']') { break }
                    if (pos < size && isNoteName(runes[pos])) {
                        let p = parsePitch()
                        if (p >= 0) {
                            pitches.add(UInt8(p))
                        }
                    } else {
                        pos++
                    }
                }
                if (pos < size && runes[pos] == r']') { pos++ }
                let ticks = parseDuration()
                elements.add(MusicElement.Chord(ChordInfo(pitches, ticks)))
                continue
            }

            // 大写字母开头：可能是音符 C4:4 或标识符
            if (isNoteName(ch)) {
                let savedPos = pos
                let p = parsePitch()
                if (p >= 0 && pos < size && runes[pos] == r':') {
                    // 确定是音符
                    let ticks = parseDuration()
                    elements.add(MusicElement.SingleNote(NoteInfo(UInt8(p), ticks)))
                    continue
                } else {
                    // 不是音符，回退当作标识符处理
                    pos = savedPos
                    let ident = readIdentifier()
                    // instrument 关键字
                    if (ident == "instrument") {
                        skipSpaces()
                        if (pos < size && runes[pos] == r'"') {
                            let _ = readQuotedString()
                        } else {
                            let _ = readIdentifier()
                        }
                        continue
                    }
                    // 变量引用
                    if (variables.contains(ident)) {
                        let varElements = variables[ident]
                        for (elem in varElements) {
                            elements.add(elem)
                        }
                        continue
                    }
                    continue
                }
            }

            // 小写字母/下划线开头的标识符
            if (isAlpha(ch)) {
                let ident = readIdentifier()
                if (ident == "instrument") {
                    skipSpaces()
                    if (pos < size && runes[pos] == r'"') {
                        let _ = readQuotedString()
                    } else {
                        let _ = readIdentifier()
                    }
                    continue
                }
                // 变量引用
                if (variables.contains(ident)) {
                    let varElements = variables[ident]
                    for (elem in varElements) {
                        elements.add(elem)
                    }
                    continue
                }
                continue
            }

            // 跳过未知字符
            pos++
        }

        elements
    }

    // 在指定范围内扫描 instrument 声明，返回 GM 编号
    func parseInstrumentInBlock(startPos: Int64, endPos: Int64): Int64 {
        let savedPos = pos
        pos = startPos
        var result: Int64 = -1

        while (pos < endPos) {
            skipWhitespace()
            if (pos >= endPos) { break }

            if (isAlpha(runes[pos]) || isNoteName(runes[pos])) {
                let ident = readIdentifier()
                if (ident == "instrument") {
                    skipSpaces()
                    if (pos < endPos && runes[pos] == r'"') {
                        let name = readQuotedString()
                        result = instrumentNumber(name)
                    } else {
                        let name = readIdentifier()
                        result = instrumentNumber(name)
                    }
                    break
                }
                // 跳过其他标识符后面可能跟随的内容
            } else {
                pos++
            }
        }

        pos = savedPos
        result
    }

    // 找到匹配的右花括号位置
    func findMatchingBrace(): Int64 {
        var depth: Int64 = 1
        var p = pos
        while (p < size && depth > 0) {
            if (runes[p] == r'{') { depth++ }
            if (runes[p] == r'}') { depth-- }
            if (depth > 0) { p++ }
        }
        p
    }

    // 主解析入口
    func parse(): ScoreData {
        let score = ScoreData()

        while (pos < size) {
            skipWhitespace()
            if (pos >= size) { break }

            let ch = runes[pos]

            if (isAlpha(ch) || isNoteName(ch)) {
                let ident = readIdentifier()

                // tempo / TEMPO
                if (ident == "tempo" || ident == "TEMPO") {
                    skipWhitespace()
                    let bpm = readNumber()
                    if (bpm > 0) {
                        score.tempo = bpm
                    }
                    continue
                }

                // let name = { ... } 变量定义
                if (ident == "let") {
                    skipWhitespace()
                    let varName = readIdentifier()
                    skipWhitespace()
                    if (pos < size && runes[pos] == r'=') {
                        pos++
                    }
                    skipWhitespace()
                    if (pos < size && runes[pos] == r'{') {
                        pos++ // 跳过 '{'
                        let elements = parseElements()
                        if (pos < size && runes[pos] == r'}') {
                            pos++ // 跳过 '}'
                        }
                        variables[varName] = elements
                    }
                    continue
                }

                // track name { ... } 轨道块
                if (ident == "track") {
                    skipWhitespace()
                    let trackName = readIdentifier()
                    skipWhitespace()
                    if (pos < size && runes[pos] == r'{') {
                        pos++ // 跳过 '{'
                        let blockStart = pos

                        // 先扫描 instrument
                        let braceEnd = findMatchingBrace()
                        let inst = parseInstrumentInBlock(blockStart, braceEnd)

                        // 再解析音乐元素
                        pos = blockStart
                        let elements = parseElements()
                        if (pos < size && runes[pos] == r'}') {
                            pos++ // 跳过 '}'
                        }

                        let track = TrackData(trackName)
                        track.instrument = inst
                        track.elements = elements
                        score.tracks.add(track)
                    }
                    continue
                }

                // 兼容旧语法 TRACK / INSTRUMENT
                if (ident == "TRACK") {
                    skipWhitespace()
                    let _ = readIdentifier()
                    continue
                }
                if (ident == "INSTRUMENT") {
                    skipWhitespace()
                    let _ = readIdentifier()
                    continue
                }

                // 未知顶层标识符，跳过
                continue
            }

            // 跳过顶层未知字符
            pos++
        }

        if (score.tracks.size == 0) {
            score.tracks.add(TrackData("default"))
        }

        score
    }
}

// 解析文本乐谱（公共入口）
public func parseScore(input: String): ScoreData {
    let parser = Parser(input)
    parser.parse()
}