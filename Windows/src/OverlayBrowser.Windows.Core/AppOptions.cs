namespace OverlayBrowser.Windows;

internal sealed record AppOptions(StartDestination Destination, bool RunSelfTest)
{
    internal static AppOptions Parse(IEnumerable<string> arguments)
    {
        string[] values = arguments.ToArray();
        return new AppOptions(
            UrlPolicy.DestinationFrom(values),
            values.Contains("--self-test", StringComparer.Ordinal));
    }
}
