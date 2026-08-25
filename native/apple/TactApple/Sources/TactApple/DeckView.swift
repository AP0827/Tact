import SwiftUI

struct DeckTile: Identifiable { let id = UUID(); let title: String; let icon: String; let action: String }

struct DeckView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var page = 0
    @State private var active = false
    private let pages: [(String, [DeckTile])] = [
        ("Development", [DeckTile(title:"VS Code",icon:"curlybraces",action:"vscode.open_workspace"),DeckTile(title:"Terminal",icon:"terminal",action:"system.open_terminal"),DeckTile(title:"Git Status",icon:"arrow.triangle.branch",action:"git.status"),DeckTile(title:"Build",icon:"hammer",action:"git.status"),DeckTile(title:"Git Pull",icon:"arrow.down",action:"git.pull"),DeckTile(title:"Git Push",icon:"arrow.up",action:"git.push"),DeckTile(title:"Cmd Palette",icon:"command",action:"vscode.open_workspace"),DeckTile(title:"Screenshot",icon:"camera.viewfinder",action:"system.screenshot")]),
        ("Media", [DeckTile(title:"Previous",icon:"backward.end.fill",action:"media.previous"),DeckTile(title:"Play / Pause",icon:"play.fill",action:"media.play_pause"),DeckTile(title:"Next",icon:"forward.end.fill",action:"media.next"),DeckTile(title:"Mute",icon:"speaker.slash",action:"system.mute"),DeckTile(title:"Volume −",icon:"speaker.wave.1",action:"media.volume"),DeckTile(title:"Volume +",icon:"speaker.wave.2",action:"media.volume"),DeckTile(title:"Spotify",icon:"music.note",action:"media.open_spotify"),DeckTile(title:"VLC",icon:"play.rectangle",action:"media.status")]),
        ("Streaming", [DeckTile(title:"OBS",icon:"dot.radiowaves.left.and.right",action:"system.open_url"),DeckTile(title:"Start Stream",icon:"play",action:"system.open_url"),DeckTile(title:"Stop Stream",icon:"stop",action:"system.open_url"),DeckTile(title:"Mute Mic",icon:"mic.slash",action:"system.mute"),DeckTile(title:"Scene 1",icon:"rectangle.on.rectangle",action:"system.open_url"),DeckTile(title:"Scene 2",icon:"rectangle.on.rectangle",action:"system.open_url"),DeckTile(title:"YouTube",icon:"play.rectangle",action:"system.open_url"),DeckTile(title:"Twitch",icon:"tv",action:"system.open_url")]),
        ("Productivity", [DeckTile(title:"Lock Screen",icon:"lock.fill",action:"system.lock_screen"),DeckTile(title:"Open URL",icon:"link",action:"system.open_url"),DeckTile(title:"New Note",icon:"note.text",action:"system.open_url"),DeckTile(title:"Calendar",icon:"calendar",action:"system.open_url"),DeckTile(title:"Slack",icon:"bubble.left.and.bubble.right",action:"system.open_url"),DeckTile(title:"Safari",icon:"safari",action:"system.open_url"),DeckTile(title:"Git Commit",icon:"checkmark.circle",action:"git.commit"),DeckTile(title:"Empty",icon:"plus",action:"")])
    ]
    var body: some View {
        Group { if active { activeDeck } else { config } }
    }
    private var config: some View {
        NavigationStack { List { ForEach(pages.indices, id: \.self) { i in Button { page=i; active=true } label: { Label(pages[i].0, systemImage: "square.grid.2x2") } } }.navigationTitle("Deck").toolbar { Button("Enter Deck") { active=true } } }
    }
    private var activeDeck: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack { Text(pages[page].0).font(.title2.weight(.semibold)); Spacer(); Button { active=false } label: { Image(systemName:"xmark").font(.headline).frame(width:42,height:42) }.tactGlass() } .padding(.horizontal)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) { ForEach(pages[page].1) { tile in Button { if !tile.action.isEmpty { model.action(tile.action) } } label: { VStack(spacing: 12) { Image(systemName: tile.icon).font(.title); Text(tile.title).font(.headline).multilineTextAlignment(.center) }.frame(maxWidth:.infinity,minHeight:150).tactGlass(prominent:true) } } }
                Spacer()
            }.padding(20)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in if value.translation.width < 0 { page = min(page+1,pages.count-1) } else if value.translation.width > 0 { page = max(page-1,0) } })
        #if os(iOS)
        .onAppear { UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation") }
        #endif
    }
}
