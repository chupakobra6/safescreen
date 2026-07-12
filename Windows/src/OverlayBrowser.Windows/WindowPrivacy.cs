using System.Runtime.InteropServices;

namespace OverlayBrowser.Windows;

internal sealed record WindowPrivacyResult(
    bool IsProtected,
    uint Affinity,
    int ErrorCode,
    string Message);

internal static class WindowPrivacy
{
    internal static WindowPrivacyResult ApplyAndVerify(nint window)
    {
        if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 19041))
        {
            return Failure("Windows 10 version 2004 or newer is required for capture exclusion.");
        }

        int compositionResult = NativeMethods.DwmIsCompositionEnabled(out bool compositionEnabled);
        if (compositionResult != 0 || !compositionEnabled)
        {
            return Failure("Desktop Window Manager composition is unavailable.", compositionResult);
        }

        if (!NativeMethods.SetWindowDisplayAffinity(
                window,
                NativeMethods.DisplayAffinityExcludeFromCapture))
        {
            int error = Marshal.GetLastWin32Error();
            return Failure("SetWindowDisplayAffinity failed.", error);
        }

        if (!NativeMethods.GetWindowDisplayAffinity(window, out uint affinity))
        {
            int error = Marshal.GetLastWin32Error();
            return Failure("GetWindowDisplayAffinity failed.", error);
        }

        if (affinity != NativeMethods.DisplayAffinityExcludeFromCapture)
        {
            return new WindowPrivacyResult(
                false,
                affinity,
                0,
                $"Unexpected display affinity 0x{affinity:X8}.");
        }

        return new WindowPrivacyResult(
            true,
            affinity,
            0,
            "WDA_EXCLUDEFROMCAPTURE is active.");
    }

    private static WindowPrivacyResult Failure(string message, int errorCode = 0) =>
        new(false, 0, errorCode, message);
}
