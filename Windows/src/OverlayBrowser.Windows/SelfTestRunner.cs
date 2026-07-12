using Microsoft.Web.WebView2.Core;

namespace OverlayBrowser.Windows;

internal sealed record SelfTestCheck(string Name, bool Passed, string Detail);

internal static class SelfTestRunner
{
    internal static int Run()
    {
        var checks = new List<SelfTestCheck>
        {
            CheckWindowsVersion(),
            CheckWebView2Runtime(),
            CheckUrlPolicy(),
            CheckWindowPrivacy()
        };

        foreach (SelfTestCheck check in checks)
        {
            string status = check.Passed ? "PASS" : "FAIL";
            Console.WriteLine($"[{status}] {check.Name}: {check.Detail}");
            AppLog.Info("self-test", "check", new Dictionary<string, string>
            {
                ["detail"] = check.Detail,
                ["name"] = check.Name,
                ["status"] = check.Passed ? "pass" : "fail"
            });
        }

        bool passed = checks.All(check => check.Passed);
        Console.WriteLine(passed ? "Self-test passed." : "Self-test failed.");
        return passed ? 0 : 1;
    }

    private static SelfTestCheck CheckWindowsVersion()
    {
        bool passed = OperatingSystem.IsWindowsVersionAtLeast(10, 0, 19041);
        return new SelfTestCheck(
            "windows-version",
            passed,
            $"{Environment.OSVersion.Version} (minimum 10.0.19041)");
    }

    private static SelfTestCheck CheckWebView2Runtime()
    {
        try
        {
            string version = CoreWebView2Environment.GetAvailableBrowserVersionString();
            return new SelfTestCheck("webview2-runtime", true, version);
        }
        catch (WebView2RuntimeNotFoundException exception)
        {
            return new SelfTestCheck("webview2-runtime", false, exception.Message);
        }
        catch (Exception exception)
        {
            return new SelfTestCheck("webview2-runtime", false, exception.Message);
        }
    }

    private static SelfTestCheck CheckUrlPolicy()
    {
        bool normalized = UrlPolicy.TryNormalize("example.com", out Uri? uri);
        bool passed = normalized
            && uri?.AbsoluteUri == "https://example.com/"
            && UrlPolicy.DefaultUri.AbsoluteUri == "https://chatgpt.com/";
        return new SelfTestCheck(
            "url-policy",
            passed,
            passed ? "default and normalization are valid" : "URL policy invariant failed");
    }

    private static SelfTestCheck CheckWindowPrivacy()
    {
        using var window = new Form
        {
            FormBorderStyle = FormBorderStyle.FixedToolWindow,
            Location = new Point(-10_000, -10_000),
            ShowInTaskbar = false,
            Size = new Size(10, 10),
            StartPosition = FormStartPosition.Manual
        };
        window.CreateControl();
        WindowPrivacyResult result = WindowPrivacy.ApplyAndVerify(window.Handle);
        return new SelfTestCheck(
            "window-capture-exclusion",
            result.IsProtected,
            $"{result.Message} affinity=0x{result.Affinity:X8} error={result.ErrorCode}");
    }
}
