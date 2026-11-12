import Foundation

/// Règles françaises du démarchage téléphonique (sources : DGCCRF / ministère de l'Économie, ARCEP).
///  - plages réservées à la prospection commerciale depuis le 01/01/2023 ;
///  - démarchage permis du lundi au vendredi (hors jours fériés), de 10 h à 13 h et de 14 h à 20 h ;
///  - au plus 4 appels par période de 30 jours ;
///  - depuis le 11/08/2026 : interdit sans consentement préalable, sauf contrat en cours.
enum NumberKind { case demarchage, mobile, autre }

struct AnalyzedCall: Identifiable {
    let entry: CallEntry
    let kind: NumberKind
    let why: String
    let violations: [String]
    var id: UUID { entry.id }
}

enum Rules {
    static let demarchagePrefixes = ["0162", "0163", "0270", "0271", "0377", "0378", "0424", "0425", "0568", "0569", "0948", "0949"]
    static let signalConsoURL = URL(string: "https://signal.conso.gouv.fr/fr/demarchage-abusif")!
    static let paris = TimeZone(identifier: "Europe/Paris") ?? .current

    // MARK: numéros

    /// Numéro national à 10 chiffres (« 0377087295 ») à partir d'une saisie libre ; nil si invalide.
    static func normalize(_ raw: String) -> String? {
        var d = raw.filter { $0.isNumber || $0 == "+" }
        if d.hasPrefix("+33") { d = "0" + String(d.dropFirst(3)) }
        else if d.hasPrefix("0033") { d = "0" + String(d.dropFirst(4)) }
        d = d.filter { $0.isNumber }
        return (9...15).contains(d.count) ? d : nil
    }

    static func pretty(_ n: String) -> String {
        guard n.count == 10, n.hasPrefix("0") else { return n }
        let c = Array(n)
        return stride(from: 0, to: 10, by: 2).map { String(c[$0..<($0 + 2)]) }.joined(separator: " ")
    }

    /// Format E.164 sans « + » (ex. 33377087295), celui de CallKit.
    static func e164(_ n: String) -> Int64? {
        guard n.count == 10, n.hasPrefix("0") else { return nil }
        return Int64("33" + String(n.dropFirst()))
    }

    static func classify(_ n: String) -> (NumberKind, String) {
        if n.count == 10, demarchagePrefixes.contains(where: { n.hasPrefix($0) }) {
            return (.demarchage, "Plage réservée par l'ARCEP aux appels de prospection commerciale.")
        }
        if n.count == 10, n.hasPrefix("06") || n.hasPrefix("07") {
            return (.mobile, "Numéro mobile : les démarcheurs n'ont plus le droit d'en utiliser (usurpation possible).")
        }
        if n.count == 10, n.hasPrefix("08") || n.hasPrefix("09") {
            return (.autre, "Préfixe 08 ou 09 : service ou appel non géographique, à vérifier.")
        }
        return (.autre, "Numéro non classé comme démarchage : le signalement reste possible.")
    }

    // MARK: dates, jours fériés, créneaux

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = paris
        return c
    }

    private static func easterMonthDay(_ y: Int) -> (Int, Int) {
        let a = y % 19, b = y / 100, c = y % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return (month, day)
    }

    static func isHoliday(_ date: Date) -> Bool {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return false }
        let fixed: [(Int, Int)] = [(1, 1), (5, 1), (5, 8), (7, 14), (8, 15), (11, 1), (11, 11), (12, 25)]
        if fixed.contains(where: { $0.0 == m && $0.1 == d }) { return true }
        let (em, ed) = easterMonthDay(y)
        guard let easter = cal.date(from: DateComponents(year: y, month: em, day: ed)) else { return false }
        for offset in [1, 39, 50] {   // lundi de Pâques, Ascension, lundi de Pentecôte
            if let h = cal.date(byAdding: .day, value: offset, to: easter) {
                let hc = cal.dateComponents([.month, .day], from: h)
                if hc.month == m && hc.day == d { return true }
            }
        }
        return false
    }

    /// Motif d'infraction aux jours et horaires, ou nil.
    static func hourViolation(_ date: Date) -> String? {
        let c = cal.dateComponents([.weekday, .hour, .minute], from: date)
        if c.weekday == 1 || c.weekday == 7 { return "un week-end" }
        if isHoliday(date) { return "un jour férié" }
        let hm = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if !((600..<780).contains(hm) || (840..<1200).contains(hm)) { return "hors des créneaux 10 h–13 h / 14 h–20 h" }
        return nil
    }

    static func format(_ date: Date, short: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = paris
        f.dateFormat = short ? "dd/MM HH:mm" : "dd/MM/yyyy 'à' HH:mm"
        return f.string(from: date)
    }

    // MARK: analyse du journal

    static func analyze(_ calls: [CallEntry]) -> [AnalyzedCall] {
        calls.map { c in
            let (kind, why) = classify(c.number)
            var v: [String] = []
            if let hv = hourViolation(c.date) { v.append("Appel passé " + hv) }
            let near = calls.filter { $0.number == c.number && abs($0.date.timeIntervalSince(c.date)) <= 30 * 86400 }
            if near.count > 4 { v.append("\(near.count) appels en 30 jours (maximum : 4)") }
            return AnalyzedCall(entry: c, kind: kind, why: why, violations: v)
        }
    }

    /// Texte prêt à coller dans SignalConso (aucune donnée personnelle).
    static func report(number: String, calls: [CallEntry], op: OperatorInfo?) -> String {
        let rows = calls.filter { $0.number == number }.sorted { $0.date < $1.date }
        var lines = ["Je signale des appels de démarchage téléphonique que je n'ai jamais sollicités, venant du numéro \(pretty(number)).", ""]
        if classify(number).0 == .demarchage {
            lines.append("Ce numéro appartient à une plage réservée par l'ARCEP à la prospection commerciale (\(number.prefix(4))).")
        }
        if let op = op {
            lines.append("D'après les données ouvertes de l'ARCEP, cette tranche est attribuée à l'opérateur \(op.name) (SIRET \(op.siret), \(op.address)) : je vous demande d'identifier son client.")
        }
        lines.append("Je n'ai donné aucun consentement préalable à être démarché par téléphone par cette entreprise, et je n'ai pas de contrat en cours avec elle.")
        lines += ["", "Appels reçus :"]
        for c in rows {
            var s = "- " + format(c.date)
            if let v = hourViolation(c.date) { s += " (passé \(v))" }
            if !c.note.isEmpty { s += " — " + c.note }
            lines.append(s)
        }
        if rows.count > 4 { lines.append("\nSoit \(rows.count) appels, au-delà de la limite de 4 par période de 30 jours.") }
        lines.append("\nJe demande la suppression de mes données et l'arrêt immédiat de tout nouvel appel (démarchage interdit sans consentement préalable depuis le 11 août 2026).")
        return lines.joined(separator: "\n")
    }
}
