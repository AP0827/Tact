use adw::prelude::*;
use adw::{Application, ApplicationWindow, HeaderBar, Toast, ToastOverlay, ToolbarView, WindowTitle};
use futures_util::{SinkExt, StreamExt};
use ksni::blocking::TrayMethods;
use gtk::glib::{self, ControlFlow};
use gtk::{
    Align, Box as GtkBox, Button, CssProvider, Entry, Grid, Label, ListBox, Orientation,
    PasswordEntry, ProgressBar, ScrolledWindow, Separator, Stack, StackSidebar,
};
use serde_json::{json, Value};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::mpsc::{self, Receiver, Sender};
use std::time::Duration;
use tokio::sync::mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender};
use tokio_tungstenite::{connect_async, tungstenite::Message};

#[derive(Debug)]
enum ClientCommand {
    Pair { host: String, otp: String, device_id: String },
    Action { id: String, payload: Value },
    Disconnect,
}

#[derive(Debug)]
enum UiMessage {
    Pairing,
    Connected(String),
    Disconnected,
    Snapshot(Value),
    Event { title: String, description: String },
    Error(String),
}

#[derive(Debug, Clone, Copy)]
enum DesktopCommand {
    ShowDashboard,
    ShowPreferences,
    Quit,
}

#[derive(Debug)]
struct TactTray {
    commands: Sender<DesktopCommand>,
}

impl ksni::Tray for TactTray {
    fn id(&self) -> String { "tact".into() }
    fn title(&self) -> String { "Tact".into() }
    fn icon_name(&self) -> String { "computer-symbolic".into() }
    fn activate(&mut self, _x: i32, _y: i32) {
        let _ = self.commands.send(DesktopCommand::ShowDashboard);
    }

    fn menu(&self) -> Vec<ksni::menu::MenuItem<Self>> {
        use ksni::menu::StandardItem;
        vec![
            StandardItem {
                label: "Open Tact".into(),
                activate: Box::new(|tray| {
                    let _ = tray.commands.send(DesktopCommand::ShowDashboard);
                }),
                ..Default::default()
            }.into(),
            StandardItem {
                label: "Preferences…".into(),
                activate: Box::new(|tray| {
                    let _ = tray.commands.send(DesktopCommand::ShowPreferences);
                }),
                ..Default::default()
            }.into(),
            ksni::menu::MenuItem::Separator,
            StandardItem {
                label: "Quit Tact".into(),
                activate: Box::new(|tray| {
                    let _ = tray.commands.send(DesktopCommand::Quit);
                }),
                ..Default::default()
            }.into(),
        ]
    }
}

#[derive(Clone)]
struct Metrics {
    cpu_label: Label,
    cpu_bar: ProgressBar,
    memory_label: Label,
    memory_bar: ProgressBar,
    disk_label: Label,
    disk_bar: ProgressBar,
    battery_label: Label,
    battery_bar: ProgressBar,
}

#[derive(Clone)]
struct DeveloperWidgets {
    branch: Label,
    status: Label,
    containers: ListBox,
}

#[derive(Clone)]
struct MediaWidgets {
    title: Label,
    artist: Label,
}

fn main() {
    let app = Application::builder().application_id("com.tact.Tact").build();
    app.connect_activate(build_host);
    app.run();
}

#[derive(Clone)]
struct HostClient { http: reqwest::blocking::Client, base: String }

impl HostClient {
    fn new() -> Self { Self { http: reqwest::blocking::Client::builder().timeout(Duration::from_secs(3)).build().unwrap(), base: "http://127.0.0.1:8000".into() } }
    fn status(&self) -> Result<Value, String> { self.http.get(format!("{}/api/host/status", self.base)).send().and_then(|response| response.error_for_status()).and_then(|response| response.json()).map_err(|error| error.to_string()) }
    fn post(&self, path: &str, body: Value) { let _ = self.http.post(format!("{}{}", self.base, path)).json(&body).send(); }
}

fn build_host(app: &Application) {
    install_style();
    app.hold();
    let client = HostClient::new();
    let host = Label::new(Some("127.0.0.1:8000")); host.add_css_class("monospace"); host.set_halign(Align::Start);
    let otp = Label::new(Some("—")); otp.add_css_class("title-1"); otp.add_css_class("monospace"); otp.set_halign(Align::Start);
    let status = Label::new(Some("Connecting to the local agent…")); status.add_css_class("dim-label"); status.set_halign(Align::Start);
    let approvals = ListBox::new(); approvals.add_css_class("boxed-list");
    let devices = ListBox::new(); devices.add_css_class("boxed-list");
    let page = page_box();
    let title = Label::new(Some("Tact Host")); title.add_css_class("title-1"); title.set_halign(Align::Start); page.append(&title); page.append(&status);
    let host_card = GtkBox::new(Orientation::Vertical, 10); host_card.add_css_class("card");
    let host_caption = Label::new(Some("THIS HOST")); host_caption.add_css_class("dim-label"); host_caption.set_halign(Align::Start); host_card.append(&host_caption); host_card.append(&host);
    let otp_caption = Label::new(Some("PAIRING CODE")); otp_caption.add_css_class("dim-label"); otp_caption.set_halign(Align::Start); host_card.append(&otp_caption); host_card.append(&otp);
    let controls = GtkBox::new(Orientation::Horizontal, 8);
    let regenerate = Button::with_label("Regenerate OTP"); let refresh = Button::with_label("Refresh"); controls.append(&regenerate); controls.append(&refresh); host_card.append(&controls); page.append(&host_card);
    let approvals_title = Label::new(Some("Pending approvals")); approvals_title.add_css_class("title-3"); approvals_title.set_halign(Align::Start); page.append(&approvals_title); page.append(&approvals);
    let devices_title = Label::new(Some("Authorized controllers")); devices_title.add_css_class("title-3"); devices_title.set_halign(Align::Start); page.append(&devices_title); page.append(&devices);
    let terminate_all = Button::with_label("Terminate all connections"); terminate_all.add_css_class("destructive-action"); page.append(&terminate_all);
    let window = ApplicationWindow::builder().application(app).title("Tact Host").default_width(680).default_height(720).content(&scroll_page(&page)).build();
    window.connect_close_request(|window| { window.set_visible(false); glib::Propagation::Stop });
    let refresh_view: Rc<dyn Fn()> = Rc::new({ let client=client.clone(); let host=host.clone(); let otp=otp.clone(); let status=status.clone(); let approvals=approvals.clone(); let devices=devices.clone(); move || { render_host(&client, &host, &otp, &status, &approvals, &devices); }});
    refresh.connect_clicked({ let refresh_view=refresh_view.clone(); move |_| refresh_view() });
    regenerate.connect_clicked({ let client=client.clone(); let refresh_view=refresh_view.clone(); move |_| { client.post("/api/debug/regenerate-otp", json!({})); refresh_view(); }});
    terminate_all.connect_clicked({ let client=client.clone(); let refresh_view=refresh_view.clone(); move |_| { client.post("/api/pair/reset_all", json!({})); refresh_view(); }});
    refresh_view();
    let (desktop_tx, desktop_rx) = mpsc::channel();
    let tray_handle = TactTray { commands: desktop_tx }.spawn().ok();
    let window_for_tray = window.clone(); let app_for_tray = app.clone();
    glib::timeout_add_local(Duration::from_millis(100), move || { let _keep=&tray_handle; while let Ok(command)=desktop_rx.try_recv() { match command { DesktopCommand::ShowDashboard | DesktopCommand::ShowPreferences => window_for_tray.present(), DesktopCommand::Quit => { app_for_tray.quit(); return ControlFlow::Break; } } } ControlFlow::Continue });
}

fn render_host(client: &HostClient, host: &Label, otp: &Label, status: &Label, approvals: &ListBox, devices: &ListBox) {
    while let Some(child)=approvals.first_child() { approvals.remove(&child); }
    while let Some(child)=devices.first_child() { devices.remove(&child); }
    match client.status() {
        Ok(data) => {
            host.set_text(&format!("{}:{}", data["host"].as_str().unwrap_or("127.0.0.1"), data["port"].as_i64().unwrap_or(8000)));
            otp.set_text(data["pairing_token"].as_str().unwrap_or("—"));
            let pending = data["pending_pairings"].as_array().cloned().unwrap_or_default(); let paired = data["paired_devices"].as_array().cloned().unwrap_or_default();
            status.set_text(&format!("{} connected · {} waiting", paired.iter().filter(|item| item["active"].as_bool().unwrap_or(false)).count(), pending.len()));
            for item in pending { let row=GtkBox::new(Orientation::Horizontal,8); let label=Label::new(item["label"].as_str()); label.set_hexpand(true); label.set_halign(Align::Start); row.append(&label); let allow=Button::with_label("Allow"); let reject=Button::with_label("Reject"); let id=item["pending_id"].as_str().unwrap_or("").to_string(); allow.connect_clicked({let client=client.clone();let id=id.clone();move |_|client.post("/api/pair/approve",json!({"pending_id":id}))}); reject.connect_clicked({let client=client.clone();move |_|client.post("/api/pair/reject",json!({"pending_id":id}))}); row.append(&allow);row.append(&reject);approvals.append(&row); }
            for item in paired { let row=GtkBox::new(Orientation::Horizontal,8); let label=Label::new(Some(&format!("{}{}",if item["active"].as_bool().unwrap_or(false){"● "}else{"○ "},item["label"].as_str().unwrap_or("Controller"))));label.set_hexpand(true);label.set_halign(Align::Start);row.append(&label);let terminate=Button::with_label("Terminate");let id=item["device_id"].as_str().unwrap_or("").to_string();terminate.connect_clicked({let client=client.clone();move |_|client.post("/api/pair/reset",json!({"device_id":id}))});row.append(&terminate);devices.append(&row); }
        }
        Err(error) => status.set_text(&format!("Start the Tact agent · {}", error)),
    }
}

fn build(app: &Application) {
    install_style();
    app.hold();
    let (command_tx, command_rx) = unbounded_channel();
    let (desktop_tx, desktop_rx) = mpsc::channel();
    let tray_handle = TactTray { commands: desktop_tx }.spawn().ok();
    let (ui_tx, ui_rx) = mpsc::channel();
    std::thread::spawn(move || {
        let runtime = tokio::runtime::Runtime::new().expect("network runtime");
        runtime.block_on(client_worker(command_rx, ui_tx));
    });

    let toast_overlay = ToastOverlay::new();
    let root_stack = Stack::builder().transition_type(gtk::StackTransitionType::Crossfade).build();
    let pairing = pairing_view(command_tx.clone());
    root_stack.add_named(&pairing, Some("pairing"));

    let (dashboard, stack, metrics, developer, media, events, host_label, connection_label) =
        dashboard_view(command_tx.clone());
    root_stack.add_named(&dashboard, Some("dashboard"));
    root_stack.set_visible_child_name("pairing");
    toast_overlay.set_child(Some(&root_stack));

    let title = WindowTitle::new("Tact", "Native developer control surface");
    let header = HeaderBar::new();
    header.set_title_widget(Some(&title));
    let toolbar = ToolbarView::new();
    toolbar.add_top_bar(&header);
    toolbar.set_content(Some(&toast_overlay));

    let window = ApplicationWindow::builder()
        .application(app)
        .title("Tact")
        .default_width(1080)
        .default_height(760)
        .content(&toolbar)
        .build();

    window.connect_close_request(|window| {
        window.set_visible(false);
        glib::Propagation::Stop
    });

    process_ui_messages(
        ui_rx,
        root_stack,
        stack,
        metrics,
        developer,
        media,
        events,
        host_label,
        connection_label,
        toast_overlay,
    );
    let preferences: Rc<RefCell<Option<ApplicationWindow>>> = Rc::new(RefCell::new(None));
    let window_for_tray = window.clone();
    let app_for_tray = app.clone();
    let preferences_for_tray = preferences.clone();
    let settings_commands = command_tx.clone();
    glib::timeout_add_local(Duration::from_millis(100), move || {
        let _keep_tray_alive = &tray_handle;
        while let Ok(command) = desktop_rx.try_recv() {
            match command {
                DesktopCommand::ShowDashboard => window_for_tray.present(),
                DesktopCommand::ShowPreferences => {
                    if preferences_for_tray.borrow().is_none() {
                        let content = settings_page(settings_commands.clone());
                        let preferences_window = ApplicationWindow::builder()
                            .application(&app_for_tray)
                            .title("Tact Preferences")
                            .default_width(620)
                            .default_height(520)
                            .content(&content)
                            .build();
                        preferences_window.connect_close_request(|window| {
                            window.set_visible(false);
                            glib::Propagation::Stop
                        });
                        *preferences_for_tray.borrow_mut() = Some(preferences_window);
                    }
                    if let Some(preferences_window) = preferences_for_tray.borrow().as_ref() {
                        preferences_window.present();
                    }
                }
                DesktopCommand::Quit => {
                    app_for_tray.quit();
                    return ControlFlow::Break;
                }
            }
        }
        ControlFlow::Continue
    });
}

fn pairing_view(commands: UnboundedSender<ClientCommand>) -> GtkBox {
    let page = GtkBox::new(Orientation::Vertical, 16);
    page.set_halign(Align::Center);
    page.set_valign(Align::Center);
    page.set_size_request(440, -1);
    page.set_margin_start(24);
    page.set_margin_end(24);

    let mark = Label::new(Some("⚡"));
    mark.add_css_class("tact-mark");
    mark.set_halign(Align::Start);
    let title = Label::new(Some("Tact"));
    title.add_css_class("display-2");
    title.set_halign(Align::Start);
    let subtitle = Label::new(Some("Your computer becomes a live developer control surface."));
    subtitle.add_css_class("dim-label");
    subtitle.set_wrap(true);
    subtitle.set_halign(Align::Start);
    let host = Entry::builder().placeholder_text("Computer address · 192.168.1.42").build();
    let otp = PasswordEntry::builder().placeholder_text("6-digit pairing code").show_peek_icon(true).build();
    let pair = Button::with_label("Pair securely");
    pair.add_css_class("suggested-action");
    pair.add_css_class("pill");
    pair.set_size_request(-1, 48);

    let host_clone = host.clone();
    let otp_clone = otp.clone();
    pair.connect_clicked(move |_| {
        let host = host_clone.text().trim().to_string();
        let otp = otp_clone.text().trim().to_string();
        if host.is_empty() || otp.len() != 6 || !otp.chars().all(|character| character.is_ascii_digit()) {
            return;
        }
        let machine_id = std::fs::read_to_string("/etc/machine-id")
            .unwrap_or_else(|_| format!("process-{}", std::process::id()));
        let device_id = format!("linux-{}", machine_id.trim());
        let _ = commands.send(ClientCommand::Pair { host, otp, device_id });
    });

    page.append(&mark);
    page.append(&title);
    page.append(&subtitle);
    page.append(&host);
    page.append(&otp);
    page.append(&pair);
    let note = Label::new(Some("Pairing stays on your local network. The desktop agent only exposes allowlisted actions."));
    note.add_css_class("dim-label");
    note.add_css_class("caption");
    note.set_wrap(true);
    page.append(&note);
    page
}

#[allow(clippy::type_complexity)]
fn dashboard_view(
    commands: UnboundedSender<ClientCommand>,
) -> (
    GtkBox,
    Stack,
    Metrics,
    DeveloperWidgets,
    MediaWidgets,
    ListBox,
    Label,
    Label,
) {
    let layout = GtkBox::new(Orientation::Horizontal, 0);
    let stack = Stack::builder().hexpand(true).vexpand(true).transition_type(gtk::StackTransitionType::Crossfade).build();
    let sidebar_box = GtkBox::new(Orientation::Vertical, 10);
    sidebar_box.set_size_request(210, -1);
    sidebar_box.add_css_class("navigation-sidebar");
    let sidebar = StackSidebar::new();
    sidebar.set_stack(&stack);
    sidebar.set_vexpand(true);
    sidebar_box.append(&sidebar);
    let host_label = Label::new(Some("Host"));
    host_label.set_halign(Align::Start);
    host_label.set_ellipsize(gtk::pango::EllipsizeMode::End);
    host_label.add_css_class("heading");
    let connection_label = Label::new(Some("Disconnected"));
    connection_label.set_halign(Align::Start);
    connection_label.add_css_class("accent");
    sidebar_box.append(&Separator::new(Orientation::Horizontal));
    sidebar_box.append(&host_label);
    sidebar_box.append(&connection_label);
    sidebar_box.set_margin_bottom(16);
    sidebar_box.set_margin_start(12);
    sidebar_box.set_margin_end(12);

    let (system_page, metrics) = system_page(commands.clone());
    let (developer_page, developer) = developer_page(commands.clone());
    let (media_page, media) = media_page(commands.clone());
    let (events_page, events) = events_page();
    let deck_page = deck_page(commands.clone());
    stack.add_titled(&system_page, Some("system"), "System");
    stack.add_titled(&developer_page, Some("developer"), "Developer");
    stack.add_titled(&media_page, Some("media"), "Media");
    stack.add_titled(&events_page, Some("events"), "Events");
    stack.add_titled(&deck_page, Some("deck"), "Deck");
    layout.append(&sidebar_box);
    layout.append(&Separator::new(Orientation::Vertical));
    layout.append(&stack);
    (layout, stack, metrics, developer, media, events, host_label, connection_label)
}

fn page_box() -> GtkBox {
    let page = GtkBox::new(Orientation::Vertical, 16);
    page.set_margin_top(24);
    page.set_margin_bottom(24);
    page.set_margin_start(24);
    page.set_margin_end(24);
    page
}

fn scroll_page(content: &impl IsA<gtk::Widget>) -> ScrolledWindow {
    ScrolledWindow::builder().hscrollbar_policy(gtk::PolicyType::Never).child(content).build()
}

fn system_page(commands: UnboundedSender<ClientCommand>) -> (ScrolledWindow, Metrics) {
    let page = page_box();
    let greeting = Label::new(Some("Your host is connected and ready."));
    greeting.add_css_class("title-2");
    greeting.set_halign(Align::Start);
    page.append(&greeting);
    let grid = Grid::builder().column_spacing(12).row_spacing(12).column_homogeneous(true).build();
    let (cpu_card, cpu_label, cpu_bar) = metric_card("CPU");
    let (memory_card, memory_label, memory_bar) = metric_card("Memory");
    let (disk_card, disk_label, disk_bar) = metric_card("Disk");
    let (battery_card, battery_label, battery_bar) = metric_card("Battery");
    grid.attach(&cpu_card, 0, 0, 1, 1);
    grid.attach(&memory_card, 1, 0, 1, 1);
    grid.attach(&disk_card, 0, 1, 1, 1);
    grid.attach(&battery_card, 1, 1, 1, 1);
    page.append(&grid);
    let controls = GtkBox::new(Orientation::Horizontal, 10);
    for (label, action) in [
        ("Lock", "system.lock_screen"),
        ("Terminal", "system.open_terminal"),
        ("Mute", "system.mute"),
        ("Screenshot", "system.screenshot"),
    ] {
        let button = Button::with_label(label);
        button.set_hexpand(true);
        let tx = commands.clone();
        button.connect_clicked(move |_| {
            let _ = tx.send(ClientCommand::Action { id: action.into(), payload: json!({}) });
        });
        controls.append(&button);
    }
    page.append(&controls);
    (
        scroll_page(&page),
        Metrics { cpu_label, cpu_bar, memory_label, memory_bar, disk_label, disk_bar, battery_label, battery_bar },
    )
}

fn metric_card(name: &str) -> (GtkBox, Label, ProgressBar) {
    let card = GtkBox::new(Orientation::Vertical, 9);
    card.add_css_class("card");
    card.set_margin_top(1);
    let name_label = Label::new(Some(name));
    name_label.add_css_class("dim-label");
    name_label.set_halign(Align::Start);
    let value = Label::new(Some("—"));
    value.add_css_class("title-1");
    value.set_halign(Align::Start);
    let bar = ProgressBar::new();
    card.append(&name_label);
    card.append(&value);
    card.append(&bar);
    (card, value, bar)
}

fn developer_page(commands: UnboundedSender<ClientCommand>) -> (ScrolledWindow, DeveloperWidgets) {
    let page = page_box();
    let title = Label::new(Some("Repository"));
    title.add_css_class("title-3");
    title.set_halign(Align::Start);
    page.append(&title);
    let repo = GtkBox::new(Orientation::Vertical, 10);
    repo.add_css_class("card");
    let branch = Label::new(Some("No repository"));
    branch.add_css_class("title-2");
    branch.add_css_class("monospace");
    branch.set_halign(Align::Start);
    let status = Label::new(Some("Waiting for host data"));
    status.add_css_class("dim-label");
    status.set_halign(Align::Start);
    repo.append(&branch);
    repo.append(&status);
    let actions = GtkBox::new(Orientation::Horizontal, 8);
    for (label, id) in [("Stage all", "git.add"), ("Pull", "git.pull"), ("Push", "git.push")] {
        let button = Button::with_label(label);
        let tx = commands.clone();
        button.connect_clicked(move |_| {
            let _ = tx.send(ClientCommand::Action { id: id.into(), payload: json!({}) });
        });
        actions.append(&button);
    }
    repo.append(&actions);
    page.append(&repo);
    let docker_title = Label::new(Some("Docker"));
    docker_title.add_css_class("title-3");
    docker_title.set_halign(Align::Start);
    page.append(&docker_title);
    let containers = ListBox::new();
    containers.add_css_class("boxed-list");
    page.append(&containers);
    (scroll_page(&page), DeveloperWidgets { branch, status, containers })
}

fn media_page(commands: UnboundedSender<ClientCommand>) -> (GtkBox, MediaWidgets) {
    let page = page_box();
    page.set_valign(Align::Center);
    let artwork = Label::new(Some("♫"));
    artwork.add_css_class("media-artwork");
    let title = Label::new(Some("Nothing playing"));
    title.add_css_class("title-1");
    let artist = Label::new(None);
    artist.add_css_class("dim-label");
    let controls = GtkBox::new(Orientation::Horizontal, 12);
    controls.set_halign(Align::Center);
    for (label, id) in [("Previous", "media.previous"), ("Play / pause", "media.play_pause"), ("Next", "media.next")] {
        let button = Button::with_label(label);
        let tx = commands.clone();
        button.connect_clicked(move |_| {
            let _ = tx.send(ClientCommand::Action { id: id.into(), payload: json!({}) });
        });
        controls.append(&button);
    }
    page.append(&artwork);
    page.append(&title);
    page.append(&artist);
    page.append(&controls);
    (page, MediaWidgets { title, artist })
}

fn events_page() -> (ScrolledWindow, ListBox) {
    let page = page_box();
    let title = Label::new(Some("Live event feed"));
    title.add_css_class("title-3");
    title.set_halign(Align::Start);
    let events = ListBox::new();
    events.add_css_class("boxed-list");
    page.append(&title);
    page.append(&events);
    (scroll_page(&page), events)
}

fn deck_page(commands: UnboundedSender<ClientCommand>) -> ScrolledWindow {
    let grid = Grid::builder().column_spacing(12).row_spacing(12).column_homogeneous(true).build();
    grid.set_margin_top(24);
    grid.set_margin_bottom(24);
    grid.set_margin_start(24);
    grid.set_margin_end(24);
    let tiles = [
        ("VS Code", "vscode.open_workspace"), ("Terminal", "system.open_terminal"),
        ("Stage all", "git.add"), ("Screenshot", "system.screenshot"),
        ("Pull", "git.pull"), ("Push", "git.push"),
        ("Play / pause", "media.play_pause"), ("Mute", "system.mute"),
    ];
    for (index, (label, action)) in tiles.into_iter().enumerate() {
        let button = Button::with_label(label);
        button.add_css_class("deck-tile");
        let tx = commands.clone();
        button.connect_clicked(move |_| {
            let _ = tx.send(ClientCommand::Action { id: action.into(), payload: json!({}) });
        });
        grid.attach(&button, (index % 3) as i32, (index / 3) as i32, 1, 1);
    }
    scroll_page(&grid)
}

fn settings_page(commands: UnboundedSender<ClientCommand>) -> ScrolledWindow {
    let page = page_box();
    let title = Label::new(Some("Connection"));
    title.add_css_class("title-3");
    title.set_halign(Align::Start);
    let disconnect = Button::with_label("Disconnect and forget host");
    disconnect.add_css_class("destructive-action");
    disconnect.set_halign(Align::Start);
    disconnect.connect_clicked(move |_| { let _ = commands.send(ClientCommand::Disconnect); });
    page.append(&title);
    page.append(&disconnect);
    let version = Label::new(Some("Tact for Linux 2.0"));
    version.add_css_class("dim-label");
    version.set_halign(Align::Start);
    page.append(&version);
    scroll_page(&page)
}

#[allow(clippy::too_many_arguments)]
fn process_ui_messages(
    receiver: Receiver<UiMessage>,
    root_stack: Stack,
    content_stack: Stack,
    metrics: Metrics,
    developer: DeveloperWidgets,
    media: MediaWidgets,
    events: ListBox,
    host_label: Label,
    connection_label: Label,
    toasts: ToastOverlay,
) {
    glib::timeout_add_local(Duration::from_millis(80), move || {
        while let Ok(message) = receiver.try_recv() {
            match message {
                UiMessage::Pairing => connection_label.set_text("Waiting for approval…"),
                UiMessage::Connected(host) => {
                    host_label.set_text(&host);
                    connection_label.set_text("Connected");
                    root_stack.set_visible_child_name("dashboard");
                    content_stack.set_visible_child_name("system");
                }
                UiMessage::Disconnected => {
                    connection_label.set_text("Disconnected");
                    root_stack.set_visible_child_name("pairing");
                }
                UiMessage::Snapshot(value) => apply_snapshot(&value, &metrics, &developer, &media),
                UiMessage::Event { title, description } => {
                    let row = GtkBox::new(Orientation::Vertical, 3);
                    let heading = Label::new(Some(&title));
                    heading.add_css_class("heading");
                    heading.set_halign(Align::Start);
                    let detail = Label::new(Some(&description));
                    detail.add_css_class("dim-label");
                    detail.set_wrap(true);
                    detail.set_halign(Align::Start);
                    row.append(&heading);
                    row.append(&detail);
                    events.prepend(&row);
                }
                UiMessage::Error(message) => toasts.add_toast(Toast::new(&message)),
            }
        }
        ControlFlow::Continue
    });
}

fn apply_snapshot(value: &Value, metrics: &Metrics, developer: &DeveloperWidgets, media: &MediaWidgets) {
    let system = &value["system"];
    set_metric(&metrics.cpu_label, &metrics.cpu_bar, system["cpu"].as_f64());
    set_metric(&metrics.memory_label, &metrics.memory_bar, system["memory"].as_f64());
    set_metric(&metrics.disk_label, &metrics.disk_bar, system["disk"].as_f64());
    let battery = system["battery"]["percent"].as_f64().or_else(|| system["battery"].as_f64());
    set_metric(&metrics.battery_label, &metrics.battery_bar, battery);

    let git = if value["git"].is_object() { &value["git"] } else { &value["workspace"]["git"] };
    developer.branch.set_text(git["branch"].as_str().unwrap_or("No repository"));
    let changed = git["changed_files"].as_i64().unwrap_or(0);
    let clean = git["clean"].as_bool().unwrap_or(false);
    developer.status.set_text(if clean { "Working tree clean" } else { &format!("{changed} changed files") });

    while let Some(child) = developer.containers.first_child() { developer.containers.remove(&child); }
    if let Some(containers) = value["docker"]["containers"].as_array() {
        for container in containers {
            let row = GtkBox::new(Orientation::Vertical, 3);
            let name = Label::new(container["name"].as_str());
            name.add_css_class("heading");
            name.set_halign(Align::Start);
            let detail = Label::new(Some(&format!("{} · {}", container["image"].as_str().unwrap_or(""), container["status"].as_str().unwrap_or(""))));
            detail.add_css_class("dim-label");
            detail.set_halign(Align::Start);
            row.append(&name);
            row.append(&detail);
            developer.containers.append(&row);
        }
    }

    let active = &value["media"]["active"];
    media.title.set_text(active["title"].as_str().unwrap_or("Nothing playing"));
    media.artist.set_text(active["artist"].as_str().unwrap_or(""));
}

fn set_metric(label: &Label, bar: &ProgressBar, value: Option<f64>) {
    label.set_text(&value.map(|number| format!("{number:.0}%")).unwrap_or_else(|| "—".into()));
    bar.set_fraction((value.unwrap_or(0.0) / 100.0).clamp(0.0, 1.0));
}

async fn client_worker(mut commands: UnboundedReceiver<ClientCommand>, ui: Sender<UiMessage>) {
    while let Some(command) = commands.recv().await {
        match command {
            ClientCommand::Pair { host, otp, device_id } => {
                let _ = ui.send(UiMessage::Pairing);
                match pair(&host, &otp, &device_id).await {
                    Ok(()) => run_connection(clean_host(&host), device_id, &mut commands, &ui).await,
                    Err(error) => { let _ = ui.send(UiMessage::Error(error)); }
                }
            }
            ClientCommand::Disconnect => { let _ = ui.send(UiMessage::Disconnected); }
            ClientCommand::Action { .. } => { let _ = ui.send(UiMessage::Error("Connect to a host before using controls.".into())); }
        }
    }
}

async fn pair(host: &str, otp: &str, device_id: &str) -> Result<(), String> {
    let host = clean_host(host);
    let client = reqwest::Client::new();
    let response = client.post(format!("http://{host}:8000/api/pair/request"))
        .json(&json!({"token": otp, "device_id": device_id, "label": "Tact Linux"}))
        .send().await.map_err(|error| error.to_string())?;
    if !response.status().is_success() { return Err("The pairing code is invalid or expired.".into()); }
    for _ in 0..60 {
        tokio::time::sleep(Duration::from_secs(1)).await;
        let response = client.get(format!("http://{host}:8000/api/pair/me?device_id={device_id}"))
            .send().await.map_err(|error| error.to_string())?;
        if response.status().is_success() {
            let body: Value = response.json().await.map_err(|error| error.to_string())?;
            if body["paired"].as_bool() == Some(true) { return Ok(()); }
        }
    }
    Err("Pairing was not approved within one minute.".into())
}

async fn run_connection(host: String, token: String, commands: &mut UnboundedReceiver<ClientCommand>, ui: &Sender<UiMessage>) {
    let url = format!("ws://{host}:8000/ws");
    let Ok((mut socket, _)) = connect_async(&url).await else {
        let _ = ui.send(UiMessage::Error("Could not connect to the Tact host.".into()));
        return;
    };
    let auth = json!({"type":"auth", "token":token, "label":"Tact Linux"}).to_string();
    if socket.send(Message::Text(auth.into())).await.is_err() { return; }
    loop {
        tokio::select! {
            command = commands.recv() => match command {
                Some(ClientCommand::Action { id, payload }) => {
                    let action = json!({"type":"action", "action_id":id, "request_id":format!("r{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis()), "payload":payload});
                    if socket.send(Message::Text(action.to_string().into())).await.is_err() { break; }
                }
                Some(ClientCommand::Disconnect) | None => {
                    let _ = socket.close(None).await;
                    let _ = ui.send(UiMessage::Disconnected);
                    break;
                }
                Some(ClientCommand::Pair { .. }) => {}
            },
            message = socket.next() => match message {
                Some(Ok(Message::Text(text))) => handle_message(&text, &host, ui),
                Some(Ok(_)) => {},
                Some(Err(error)) => { let _ = ui.send(UiMessage::Error(error.to_string())); break; }
                None => break,
            }
        }
    }
}

fn handle_message(text: &str, host: &str, ui: &Sender<UiMessage>) {
    let Ok(message) = serde_json::from_str::<Value>(text) else { return; };
    match message["type"].as_str() {
        Some("init" | "telemetry") => {
            let _ = ui.send(UiMessage::Connected(host.into()));
            let _ = ui.send(UiMessage::Snapshot(message["payload"].clone()));
        }
        Some("event") => {
            let payload = &message["payload"];
            let _ = ui.send(UiMessage::Event {
                title: payload["title"].as_str().unwrap_or("Tact event").into(),
                description: payload["description"].as_str().unwrap_or("").into(),
            });
        }
        Some("error") => { let _ = ui.send(UiMessage::Error(message["message"].as_str().unwrap_or("Connection rejected").into())); }
        Some("action_result") if message["result"]["ok"].as_bool() == Some(false) => {
            let _ = ui.send(UiMessage::Error(message["result"]["error"].as_str().unwrap_or("Action failed").into()));
        }
        _ => {}
    }
}

fn clean_host(host: &str) -> String {
    host.trim().trim_start_matches("http://").trim_start_matches("https://").split(['/', ':']).next().unwrap_or(host).to_string()
}

fn install_style() {
    let provider = CssProvider::new();
    provider.load_from_data(
        "@define-color accent_bg_color #22d3ee; @define-color accent_color #22d3ee;\n\
        .tact-mark { background: #22d3ee; color: #09090b; border-radius: 18px; padding: 14px 18px; font-size: 24px; }\n\
        .accent { color: #22d3ee; }\n\
        .card { padding: 20px; border-radius: 16px; }\n\
        .media-artwork { min-width: 220px; min-height: 220px; background: alpha(@window_fg_color, .06); color: #22d3ee; border-radius: 32px; font-size: 68px; }\n\
        .deck-tile { min-height: 128px; border-radius: 18px; font-size: 16px; font-weight: 600; }",
    );
    gtk::style_context_add_provider_for_display(
        &gtk::gdk::Display::default().expect("display"),
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}
