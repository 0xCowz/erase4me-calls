import SwiftUI
import CallKit

struct ProtectionView: View {
    @EnvironmentObject var catalog: Catalog
    @Environment(\.openURL) private var openURL

    @State private var enabled: Bool? = nil
    @State private var statusText = "Vérification…"
    @State private var message = ""

    private var extensionID: String { (Bundle.main.bundleIdentifier ?? "com.erase4me.calls") + ".blocker" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    LogoMark(size: 42)
                    Wordmark(size: 24)
                    Spacer()
                }

                ScreenHeader(
                    eyebrow: "Anti-démarchage",
                    title: enabled == true ? "Les appels de démarchage sont bloqués." : "La protection n'est pas encore active.",
                    subtitle: "Les numéros attribués par l'ARCEP aux appels de prospection commerciale sont refusés par ton iPhone avant même de sonner."
                )

                statusPanel
                statsStrip
                expiryPanel
                operatorsPanel

                if !message.isEmpty {
                    Text(message).font(Typo.body(13)).foregroundColor(Palette.warn)
                }
                Text("Données ARCEP du \(catalog.generated) · licence ouverte. Un appel venant d'un 06, d'un 07 ou d'un numéro usurpé n'est pas bloqué.")
                    .font(Typo.mono(10)).foregroundColor(Palette.muted)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Palette.bg.ignoresSafeArea())
        .onAppear(perform: refresh)
    }

    // MARK: blocs

    private var statusPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle().fill(enabled == true ? Palette.ok : Palette.warn).frame(width: 10, height: 10)
                    Text(statusText).font(Typo.title(20)).foregroundColor(Palette.text)
                }
                if enabled != true {
                    Text("Réglages > Téléphone > Blocage d'appels et identification > active « Anti-démarchage ».")
                        .font(Typo.body(14)).foregroundColor(Palette.text2)
                }
                Button("Ouvrir les réglages de blocage") {
                    CXCallDirectoryManager.sharedInstance.openSettings { error in
                        DispatchQueue.main.async { message = error?.localizedDescription ?? "" }
                    }
                }.buttonStyle(PrimaryButtonStyle())
                Button("Recharger la liste") { reload() }.buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatCell(value: format(catalog.totalNumbers), label: "numéros bloqués")
            Rectangle().fill(Palette.line).frame(width: 1)
            StatCell(value: "\(catalog.tranches.count)", label: "tranches")
            Rectangle().fill(Palette.line).frame(width: 1)
            StatCell(value: "\(catalog.operators.count)", label: "opérateurs")
        }
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var expiryPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("SIGNATURE DE L'APP").font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
                if let exp = Signing.expiry {
                    let left = exp.timeIntervalSinceNow
                    let days = Int(left / 86400), hours = Int(left.truncatingRemainder(dividingBy: 86400) / 3600)
                    Text(left <= 0 ? "Expirée : le blocage est arrêté" : "Expire dans \(days) j \(hours) h")
                        .font(Typo.title(22)).foregroundColor(left <= 0 ? Palette.err : (days < 2 ? Palette.warn : Palette.text))
                    Text("Avec un compte Apple gratuit, l'app doit être réinstallée (Sideloadly / AltStore) avant cette date, sinon le blocage s'arrête.")
                        .font(Typo.body(13)).foregroundColor(Palette.text2)
                } else {
                    Text("Non détectée").font(Typo.title(22)).foregroundColor(Palette.text)
                    Text("Pas de profil de signature embarqué : installation officielle ou par Xcode.")
                        .font(Typo.body(13)).foregroundColor(Palette.text2)
                }
            }
        }
    }

    private var operatorsPanel: some View {
        let top = Array(catalog.operators.prefix(6))
        let maxN = Double(top.first?.numbers ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Qui détient ces numéros")
            ForEach(top) { op in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(op.info.name).font(Typo.body(15)).foregroundColor(Palette.text).lineLimit(1)
                        Spacer()
                        Text(format(op.numbers)).font(Typo.mono(12)).foregroundColor(Palette.muted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Palette.raise)
                            Rectangle().fill(Palette.paper).frame(width: geo.size.width * CGFloat(Double(op.numbers) / maxN))
                        }
                    }.frame(height: 4)
                }
            }
        }
    }

    // MARK: actions

    private func format(_ n: Int64) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func refresh() {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionID) { s, error in
            DispatchQueue.main.async {
                switch s {
                case .enabled: enabled = true; statusText = "Protection active"
                case .disabled: enabled = false; statusText = "Protection désactivée"
                default: enabled = false; statusText = "État inconnu" + (error.map { " (\($0.localizedDescription))" } ?? "")
                }
            }
        }
    }

    private func reload() {
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionID) { error in
            DispatchQueue.main.async {
                message = error.map { "Échec du rechargement : \($0.localizedDescription)" } ?? "Liste rechargée."
                refresh()
            }
        }
    }
}
