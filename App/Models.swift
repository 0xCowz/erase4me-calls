import Foundation

// MARK: - Données ARCEP embarquées (App/blocks.json, générées par tools/gen_ranges.py)

struct OperatorInfo: Decodable, Hashable {
    let name: String
    let siret: String
    let address: String

    /// Numéro SIREN (9 chiffres) : les 9 premiers chiffres du SIRET, pour la fiche de l'annuaire des entreprises.
    var siren: String { String(siret.filter { $0.isNumber }.prefix(9)) }
    var companyURL: URL? { siren.count == 9 ? URL(string: "https://annuaire-entreprises.data.gouv.fr/entreprise/\(siren)") : nil }
}

struct Tranche: Decodable, Hashable {
    let s: Int64      // premier numéro, E.164 sans « + »
    let e: Int64      // dernier numéro
    let c: String     // code ARCEP de l'opérateur
    let d: String     // date d'attribution

    var size: Int64 { e - s + 1 }

    /// Numéro national (« 0377087000 »).
    var national: String { "0" + String(String(s).dropFirst(2)) }

    /// « 0377 087 xxx » : la partie fixe de la tranche, le reste en x.
    var label: String {
        var wild = 0
        var x = size
        while x >= 10 { x /= 10; wild += 1 }
        let fixed = max(0, 10 - wild)
        let p = String(national.prefix(fixed)) + String(repeating: "x", count: min(wild, 10))
        let head = String(p.prefix(4))
        let tail = String(p.dropFirst(4))
        return tail.isEmpty ? head : head + " " + tail
    }
    var prefix4: String { String(national.prefix(4)) }
}

struct OperatorSummary: Identifiable, Hashable {
    let code: String
    let info: OperatorInfo
    let tranches: [Tranche]
    var id: String { code }
    var numbers: Int64 { tranches.reduce(0) { $0 + $1.size } }
    var since: String { tranches.map { $0.d }.filter { !$0.isEmpty }.min() ?? "" }
}

struct NumberInfo {
    let number: String
    let pretty: String
    let kind: NumberKind
    let why: String
    let tranche: Tranche?
    let op: OperatorInfo?
    var blocked: Bool { tranche != nil }
}

private struct BlocksFile: Decodable {
    let generated: String
    let prefixes: [String]
    let operators: [String: OperatorInfo]
    let tranches: [Tranche]
}

final class Catalog: ObservableObject {
    let generated: String
    let prefixes: [String]
    let tranches: [Tranche]
    let operators: [OperatorSummary]
    let opByCode: [String: OperatorInfo]
    let totalNumbers: Int64

    init() {
        var file = BlocksFile(generated: "", prefixes: [], operators: [:], tranches: [])
        if let url = Bundle.main.url(forResource: "blocks", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let f = try? JSONDecoder().decode(BlocksFile.self, from: data) {
            file = f
        }
        let sortedTranches = file.tranches.sorted { $0.s < $1.s }
        let grouped = Dictionary(grouping: sortedTranches, by: { $0.c })
        let summaries: [OperatorSummary] = grouped.map { code, list in
            OperatorSummary(code: code, info: file.operators[code] ?? OperatorInfo(name: code, siret: "", address: ""), tranches: list)
        }.sorted { $0.numbers > $1.numbers }

        generated = file.generated
        prefixes = Array(Set(sortedTranches.map { $0.prefix4 })).sorted()   // seulement les plages qui ont des numéros attribués
        tranches = sortedTranches
        opByCode = file.operators
        totalNumbers = sortedTranches.reduce(0) { $0 + $1.size }
        operators = summaries
    }

    /// Tranche bloquée contenant ce numéro national (recherche dichotomique).
    func tranche(for national: String) -> Tranche? {
        guard let n = Rules.e164(national), !tranches.isEmpty else { return nil }
        var lo = 0, hi = tranches.count - 1, found = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if tranches[mid].s <= n { found = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        guard found >= 0, n <= tranches[found].e else { return nil }
        return tranches[found]
    }

    func info(for national: String) -> NumberInfo {
        let (kind, why) = Rules.classify(national)
        let t = tranche(for: national)
        return NumberInfo(number: national, pretty: Rules.pretty(national), kind: kind, why: why, tranche: t, op: t.flatMap { opByCode[$0.c] })
    }
}

// MARK: - Journal des appels (local, dans le dossier Documents de l'app)

struct CallEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var number: String
    var date: Date
    var note: String
}

final class CallStore: ObservableObject {
    @Published private(set) var calls: [CallEntry] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("calls.json")
    }

    init() { load() }

    func add(number: String, date: Date, note: String) {
        calls.insert(CallEntry(number: number, date: date, note: note), at: 0)
        calls.sort { $0.date > $1.date }
        save()
    }

    func remove(_ entry: CallEntry) {
        calls.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        calls = ((try? dec.decode([CallEntry].self, from: data)) ?? []).sorted { $0.date > $1.date }
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(calls) { try? data.write(to: fileURL, options: .atomic) }
    }
}

// MARK: - Date d'expiration de la signature (compte Apple gratuit : 7 jours)

enum Signing {
    /// Lue dans le profil de provisionnement embarqué par Sideloadly / AltStore ; nil si absent (App Store, Xcode…).
    static var expiry: Date? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let data = FileManager.default.contents(atPath: path),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound else { return nil }
        let plist = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let obj = try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil) as? [String: Any] else { return nil }
        return obj["ExpirationDate"] as? Date
    }
}
