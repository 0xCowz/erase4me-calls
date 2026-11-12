import SwiftUI

struct NumbersView: View {
    @EnvironmentObject var catalog: Catalog
    @State private var query = ""
    @State private var prefix = "Tous"

    private var filtered: [OperatorSummary] {
        catalog.operators.filter { op in
            (prefix == "Tous" || op.tranches.contains { $0.prefix4 == prefix }) &&
            (query.isEmpty || op.info.name.localizedCaseInsensitiveContains(query) || op.info.siret.contains(query) || op.info.address.localizedCaseInsensitiveContains(query))
        }
    }

    private func chipLabel(_ p: String) -> String {
        p == "Tous" ? "Tous" : String(p.prefix(2)) + " " + String(p.dropFirst(2))   // « 0377 » -> « 03 77 »
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(eyebrow: "Numéros bloqués", title: "Qui détient ces tranches.",
                                 subtitle: "Chaque tranche de 1 000 numéros est attribuée par l'ARCEP à un opérateur. Il connaît le client qui appelle ; la DGCCRF peut le lui demander.")

                    TextField("Rechercher un opérateur, un SIRET…", text: $query,
                              prompt: Text("Rechercher un opérateur, un SIRET…").foregroundColor(Palette.muted))
                        .fieldStyle().autocorrectionDisabled().textInputAutocapitalization(.never)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Tous"] + catalog.prefixes, id: \.self) { p in
                                Button { prefix = p } label: {
                                    Text(chipLabel(p))
                                        .font(Typo.mono(12)).foregroundColor(prefix == p ? Palette.ink : Palette.text2)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(prefix == p ? Palette.paper : Color.clear)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(prefix == p ? Palette.paper : Palette.line2, lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }

                    Text("\(filtered.count) opérateur\(filtered.count > 1 ? "s" : "")").font(Typo.mono(11)).foregroundColor(Palette.muted)

                    LazyVStack(spacing: 0) {
                        Hairline()
                        ForEach(filtered) { op in
                            NavigationLink(destination: OperatorView(op: op)) {
                                OperatorRow(op: op)
                            }.buttonStyle(.plain)
                            Hairline()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct OperatorRow: View {
    let op: OperatorSummary
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(op.info.name).font(Typo.title(19)).foregroundColor(Palette.text).lineLimit(2)
                Text(op.info.address.isEmpty ? "Adresse non renseignée" : op.info.address)
                    .font(Typo.body(12)).foregroundColor(Palette.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(count(op.numbers)).font(Typo.mono(14)).foregroundColor(Palette.text)
                Text("\(op.tranches.count) tranche\(op.tranches.count > 1 ? "s" : "")").font(Typo.mono(10)).foregroundColor(Palette.muted)
            }
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }
    private func count(_ n: Int64) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct OperatorView: View {
    let op: OperatorSummary
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Opérateur télécom", title: op.info.name)

                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(label: "Adresse", value: op.info.address.isEmpty ? "—" : op.info.address)
                        InfoRow(label: "SIRET", value: op.info.siret.isEmpty ? "—" : op.info.siret, mono: true)
                        InfoRow(label: "Code ARCEP", value: op.code, mono: true)
                        InfoRow(label: "Numéros bloqués", value: "\(op.numbers) (\(op.tranches.count) tranches)")
                        if !op.since.isEmpty { InfoRow(label: "Premier numéro attribué", value: op.since, mono: true) }
                    }
                }

                Panel {
                    Text("Un opérateur loue ses numéros à des clients, par exemple des centres d'appels. Il sait qui est son client, pas toi. Un signalement à la répression des fraudes lui permet de le demander.")
                        .font(Typo.body(14)).foregroundColor(Palette.text2)
                }

                if let url = op.info.companyURL {
                    Button("Voir la fiche de l'entreprise") { openURL(url) }.buttonStyle(GhostButtonStyle())
                }
                Button("Signaler sur SignalConso") { openURL(Rules.signalConsoURL) }.buttonStyle(PrimaryButtonStyle())

                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Tranches attribuées").padding(.bottom, 12)
                    Hairline()
                    ForEach(op.tranches.sorted { $0.s < $1.s }, id: \.s) { t in
                        HStack {
                            Text(t.label).font(Typo.mono(14)).foregroundColor(Palette.text)
                            Spacer()
                            Text(t.d).font(Typo.mono(11)).foregroundColor(Palette.muted)
                        }.padding(.vertical, 10)
                        Hairline()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
