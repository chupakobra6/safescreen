using System.Diagnostics.CodeAnalysis;

namespace OverlayBrowser.Windows;

internal static class UrlPolicy
{
    internal static readonly Uri DefaultUri = new("https://chatgpt.com/", UriKind.Absolute);

    internal static StartDestination DestinationFrom(IEnumerable<string> arguments)
    {
        string? rawUrl = arguments.FirstOrDefault(argument =>
        {
            string value = argument.Trim();
            return value.Length > 0 && value != "--" && !value.StartsWith('-');
        });

        if (rawUrl is null)
        {
            return new StartDestination.Url(DefaultUri);
        }

        return TryNormalize(rawUrl, out Uri? uri)
            ? new StartDestination.Url(uri)
            : new StartDestination.FallbackPage();
    }

    internal static bool TryNormalize(string rawValue, [NotNullWhen(true)] out Uri? uri)
    {
        string value = rawValue.Trim();
        if (value.Length == 0)
        {
            uri = null;
            return false;
        }

        string candidate = value.Contains("://", StringComparison.Ordinal)
            ? value
            : $"https://{value}";

        if (!Uri.TryCreate(candidate, UriKind.Absolute, out Uri? parsed)
            || (parsed.Scheme != Uri.UriSchemeHttp && parsed.Scheme != Uri.UriSchemeHttps)
            || string.IsNullOrWhiteSpace(parsed.Host))
        {
            uri = null;
            return false;
        }

        uri = parsed;
        return true;
    }
}
