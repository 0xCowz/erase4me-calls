import CallKit
import Foundation

/// Extension « Call Directory » : bloque les tranches de numéros listées dans ranges.json (format [[début, fin], ...] en E.164 sans « + »).
final class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        guard
            let url = Bundle(for: type(of: self)).url(forResource: "ranges", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let ranges = try? JSONDecoder().decode([[Int64]].self, from: data)
        else {
            context.cancelRequest(withError: NSError(domain: "erase4me.blocker", code: 1,
                                                     userInfo: [NSLocalizedDescriptionKey: "ranges.json introuvable ou illisible"]))
            return
        }

        // Rechargement complet à chaque fois (la liste est petite et générée d'un bloc).
        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        // CallKit exige des numéros en ordre croissant, sans doublon : on trie et on fusionne.
        var merged: [(Int64, Int64)] = []
        for r in ranges.filter({ $0.count == 2 }).map({ ($0[0], $0[1]) }).sorted(by: { $0.0 < $1.0 }) {
            if let last = merged.last, r.0 <= last.1 + 1 {
                merged[merged.count - 1].1 = max(last.1, r.1)
            } else {
                merged.append(r)
            }
        }

        for (start, end) in merged {
            var n = start
            while n <= end {
                context.addBlockingEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(n))
                n += 1
            }
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // Rien à faire : l'extension sera relancée par le système ; l'app affiche l'état.
    }
}
