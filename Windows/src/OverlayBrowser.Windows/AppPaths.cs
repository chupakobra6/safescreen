namespace OverlayBrowser.Windows;

internal static class AppPaths
{
    private const string ProductDirectoryName = "OverlayBrowser";

    internal static string DataDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        ProductDirectoryName);

    internal static string WebView2UserDataDirectory { get; } = Path.Combine(DataDirectory, "WebView2");

    internal static string LogDirectory { get; } = Path.Combine(DataDirectory, "logs");

    internal static string LogFilePath { get; } = Path.Combine(LogDirectory, "overlay-browser.log");
}
