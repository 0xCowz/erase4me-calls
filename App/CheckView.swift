import SwiftUI

struct CheckView: View {
    @EnvironmentObject var catalog: Catalog
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var showAdd = false

    private var normalized: String? { Rules.normalize(query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Vérifier", title: "Ce numéro est-il bloqué ?",
                             subtitle: "Saisis le numéro d'un appel reçu : l'app dit s'il est bloqué, à qui appartient sa tranche et ce que dit la loi.")

                TextField("03 77 08 72 95", text: $query, prompt: Text("03 77 08 72 95").foregroundColor(Palette.muted))
                    .keyboardType(.phonePad).fieldStyle()

                if let n = normalized {
                    let info = catalog.info(for: n)
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Circle().fill(info.blocked ? Palette.ok : Palette.warn).frame(width: 10, height: 10)
                                Text(info.pretty).font(Typo.mono(20)).foregroundColor(Palette.text)
                            }
                            HStack(spacing: 6) {
                                Chip(text: info.blocked ? "bloqué par l'app" : "non bloqué", color: info.blocked ? Palette.ok : Palette.warn)
                                if info.kind == .demarchage { Chip(text: "plage démarchage", color: Palette.err) }
                                if info.kind == .mobile { Chip(text: "mobile suspect", color: Palette.warn) }
                            }
                            Text(info.why).font(Typo.body(14)).foregroundColor(Palette.text2)
                            if let t = info.tranche, let op = info.op {
                                Hairline()
                                InfoRow(label: "Tranche", value: t.label + " · attribuée le " + t.d, mono: true)
                                InfoRow(label: "Opérateur", value: op.name)
                                InfoRow(label: "Adresse", value: op.address.isEmpty ? "—" : op.address)
                                InfoRow(label: "SIRET", value: op.siret.isEmpty ? "—" : op.siret, mono: true)
                                Text("C'est l'opérateur qui loue le numéro, pas forcément l'entreprise qui appelle.").font(Typo.body(12)).foregroundColor(Palette.muted)
                            } else if info.kind == .demarchage {
                                Text("Aucun opérateur ne détient ce numéro dans les données chargées : l'appel vient probablement d'un numéro usurpé, et cette version ne le bloque pas.")
                                    .font(Typo.body(13)).foregroundColor(Palette.warn)
                            } else if info.kind == .mobile {
                                Text("Les 06 et 07 ne sont pas bloqués par cette app. Signale-le si c'était du démarchage.").font(Typo.body(13)).foregroundColor(Palette.warn)
                            }
                        }
                    }
                    Button("Noter comme appel reçu") { showAdd = true }.buttonStyle(PrimaryButtonStyle())
                    Button("Signaler sur SignalConso") { openURL(Rules.signalConsoURL) }.buttonStyle(GhostButtonStyle())
                } else if !query.isEmpty {
                    Text("Saisis un numéro complet (par exemple 03 77 08 72 95).").font(Typo.body(13)).foregroundColor(Palette.muted)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Palette.bg.ignoresSafeArea())
        .sheet(isPresented: $showAdd) { AddCallView(prefill: normalized) }
    }
}
