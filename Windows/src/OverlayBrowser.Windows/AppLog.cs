using System.Text;

namespace OverlayBrowser.Windows;

internal static class AppLog
{
    private static readonly object Sync = new();

    internal static void Info(string category, string eventName, IReadOnlyDictionary<string, string>? fields = null) =>
        Write("info", category, eventName, fields);

    internal static void Warning(string category, string eventName, IReadOnlyDictionary<string, string>? fields = null) =>
        Write("warning", category, eventName, fields);

    internal static void Error(string category, string eventName, IReadOnlyDictionary<string, string>? fields = null) =>
        Write("error", category, eventName, fields);

    private static void Write(
        string level,
        string category,
        string eventName,
        IReadOnlyDictionary<string, string>? fields)
    {
        var line = new StringBuilder()
            .Append("[OverlayBrowser] app=OverlayBrowser.Windows")
            .Append(" level=").Append(level)
            .Append(" pid=").Append(Environment.ProcessId)
            .Append(" category=").Append(category)
            .Append(" event=").Append(eventName);

        if (fields is not null)
        {
            foreach ((string key, string value) in fields.OrderBy(pair => pair.Key, StringComparer.Ordinal))
            {
                line.Append(' ').Append(key).Append('=').Append(Quote(value));
            }
        }

        string valueToWrite = line.ToString();
        lock (Sync)
        {
            try
            {
                Directory.CreateDirectory(AppPaths.LogDirectory);
                File.AppendAllText(AppPaths.LogFilePath, $"{DateTimeOffset.UtcNow:O} {valueToWrite}{Environment.NewLine}");
            }
            catch (Exception exception)
            {
                Console.Error.WriteLine($"[OverlayBrowser] log-write-failed error={Quote(exception.Message)}");
            }

            Console.Error.WriteLine(valueToWrite);
        }
    }

    private static string Quote(string value)
    {
        if (!value.Any(character => char.IsWhiteSpace(character) || character is '"' or '\\'))
        {
            return value;
        }

        return $"\"{value.Replace("\\", "\\\\", StringComparison.Ordinal).Replace("\"", "\\\"", StringComparison.Ordinal).Replace("\r", "\\r", StringComparison.Ordinal).Replace("\n", "\\n", StringComparison.Ordinal)}\"";
    }
}
