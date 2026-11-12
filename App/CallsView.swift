import SwiftUI

struct CallsView: View {
    @EnvironmentObject var catalog: Catalog
    @EnvironmentObject var store: CallStore
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(eyebrow: "Journal", title: "Les appels que tu reçois.",
                                 subtitle: "iOS ne dit à aucune app quels appels il a bloqués. Note ici un appel reçu : l'app le classe, relève les infractions et prépare ton signalement.")

                    Button("Noter un appel") { showAdd = true }.buttonStyle(PrimaryButtonStyle())

                    let analyzed = Rules.analyze(store.calls)
                    if analyzed.isEmpty {
                        Panel { Text("Aucun appel noté pour l'instant.").font(Typo.body(14)).foregroundColor(Palette.muted) }
                    } else {
                        LazyVStack(spacing: 0) {
                            Hairline()
                            ForEach(analyzed) { a in
                                NavigationLink(destination: CallDetailView(entry: a.entry)) {
                                    CallRow(a: a, info: catalog.info(for: a.entry.number))
                                }.buttonStyle(.plain)
                                Hairline()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdd) { AddCallView(prefill: nil) }
        }
    }
}

struct CallRow: View {
    let a: AnalyzedCall
    let info: NumberInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Rules.pretty(a.entry.number)).font(Typo.mono(17)).foregroundColor(Palette.text)
                Spacer()
                Text(Rules.format(a.entry.date, short: true)).font(Typo.mono(11)).foregroundColor(Palette.muted)
            }
            HStack(spacing: 6) {
                Chip(text: info.blocked ? "bloqué" : "non bloqué", color: info.blocked ? Palette.ok : Palette.warn)
                if a.kind == .demarchage { Chip(text: "plage démarchage", color: Palette.err) }
                if a.kind == .mobile { Chip(text: "mobile suspect", color: Palette.warn) }
                if !a.violations.isEmpty { Chip(text: "\(a.violations.count) infraction\(a.violations.count > 1 ? "s" : "")", color: Palette.err) }
            }
            if let op = info.op {
                Text(op.name + (op.address.isEmpty ? "" : " · " + op.address)).font(Typo.body(12)).foregroundColor(Palette.muted).lineLimit(1)
            }
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }
}

struct CallDetailView: View {
    let entry: CallEntry
    @EnvironmentObject var catalog: Catalog
    @EnvironmentObject var store: CallStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let info = catalog.info(for: entry.number)
        let analyzed = Rules.analyze(store.calls).first { $0.entry.id == entry.id }
        let report = Rules.report(number: entry.number, calls: store.calls, op: info.op)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Appel du " + Rules.format(entry.date), title: info.pretty)

                HStack(spacing: 6) {
                    Chip(text: info.blocked ? "bloqué par l'app" : "non bloqué", color: info.blocked ? Palette.ok : Palette.warn)
                    if info.kind == .demarchage { Chip(text: "plage démarchage", color: Palette.err) }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(info.why).font(Typo.body(14)).foregroundColor(Palette.text2)
                        if let t = info.tranche, let op = info.op {
                            InfoRow(label: "Tranche", value: t.label + " · attribuée le " + t.d, mono: true)
                            InfoRow(label: "Opérateur", value: op.name)
                            InfoRow(label: "Adresse", value: op.address.isEmpty ? "—" : op.address)
                            InfoRow(label: "SIRET", value: op.siret.isEmpty ? "—" : op.siret, mono: true)
                        } else if info.kind == .demarchage {
                            Text("Cette tranche n'est attribuée à aucun opérateur dans les données chargées : l'appel vient probablement d'un numéro usurpé.")
                                .font(Typo.body(14)).foregroundColor(Palette.warn)
                        }
                        if !entry.note.isEmpty { InfoRow(label: "Note", value: entry.note) }
                    }
                }

                if let a = analyzed, !a.violations.isEmpty {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("INFRACTIONS RELEVÉES").font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
                            ForEach(a.violations, id: \.self) { v in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("—").foregroundColor(Palette.accent)
                                    Text(v).font(Typo.body(14)).foregroundColor(Palette.text)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Signalement prêt à coller")
                    Text(report).font(Typo.mono(12)).foregroundColor(Palette.text2).textSelection(.enabled)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.bg).overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line, lineWidth: 1))
                }

                Button("Copier le signalement") { UIPasteboard.general.string = report }.buttonStyle(GhostButtonStyle())
                Button("Ouvrir SignalConso") { UIPasteboard.general.string = report; openURL(Rules.signalConsoURL) }.buttonStyle(PrimaryButtonStyle())
                Text("Le texte est copié automatiquement : colle-le dans le formulaire.").font(Typo.body(12)).foregroundColor(Palette.muted)
                Button("Supprimer cet appel du journal") { store.remove(entry); dismiss() }.buttonStyle(GhostButtonStyle(danger: true))
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct AddCallView: View {
    let prefill: String?
    @EnvironmentObject var store: CallStore
    @Environment(\.dismiss) private var dismiss
    @State private var number = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "Nouvel appel", title: "Noter un appel")

                VStack(alignment: .leading, spacing: 8) {
                    Text("NUMÉRO QUI A APPELÉ").font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
                    TextField("03 77 08 72 95", text: $number, prompt: Text("03 77 08 72 95").foregroundColor(Palette.muted))
                        .keyboardType(.phonePad).fieldStyle()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("DATE ET HEURE").font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().environment(\.locale, Locale(identifier: "fr_FR"))
                        .colorScheme(.dark).frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE (FACULTATIF)").font(Typo.mono(10)).tracking(1).foregroundColor(Palette.muted)
                    TextField("Assurance, rénovation, CPF…", text: $note, prompt: Text("Assurance, rénovation, CPF…").foregroundColor(Palette.muted))
                        .fieldStyle()
                }
                if !error.isEmpty { Text(error).font(Typo.body(13)).foregroundColor(Palette.err) }

                Button("Enregistrer l'appel") {
                    guard let n = Rules.normalize(number) else { error = "Numéro invalide."; return }
                    store.add(number: n, date: date, note: String(note.prefix(200)))
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle())
                Button("Annuler") { dismiss() }.buttonStyle(GhostButtonStyle())
            }
            .padding(20)
        }
        .background(Palette.bg.ignoresSafeArea())
        .onAppear { if let p = prefill { number = p } }
        .preferredColorScheme(.dark)
    }
}
