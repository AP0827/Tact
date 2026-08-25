using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace TactWindows;

public sealed class PreferencesWindow : Window
{
    public PreferencesWindow()
    {
        Title = "Tact Preferences";
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(560, 430));

        var content = new StackPanel
        {
            Spacing = 18,
            Padding = new Thickness(28),
        };
        content.Children.Add(new TextBlock
        {
            Text = "Preferences",
            Style = Application.Current.Resources["TitleTextBlockStyle"] as Style,
        });
        content.Children.Add(new TextBlock
        {
            Text = "Tact continues running in the notification area when its dashboard is closed.",
            TextWrapping = TextWrapping.Wrap,
            Opacity = 0.72,
        });
        content.Children.Add(new ToggleSwitch
        {
            Header = "Start Tact when I sign in",
            OffContent = "Disabled",
            OnContent = "Enabled",
        });
        content.Children.Add(new ToggleSwitch
        {
            Header = "Extended diagnostics",
            OffContent = "Standard",
            OnContent = "Detailed",
        });
        content.Children.Add(new InfoBar
        {
            Title = "Account service",
            Message = "Provider IDs and service addresses are supplied through deployment configuration.",
            IsOpen = true,
            IsClosable = false,
            Severity = InfoBarSeverity.Informational,
        });
        Content = new ScrollViewer { Content = content };
    }
}
