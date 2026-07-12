namespace OverlayBrowser.Windows;

internal static class Program
{
    [STAThread]
    private static int Main(string[] arguments)
    {
        AppOptions options = AppOptions.Parse(arguments);
        ApplicationConfiguration.Initialize();

        if (options.RunSelfTest)
        {
            NativeMethods.AttachConsole(NativeMethods.AttachParentProcess);
            return SelfTestRunner.Run();
        }

        using var instance = new SingleInstanceCoordinator();
        if (!instance.IsPrimary)
        {
            instance.SignalExistingInstance();
            return 0;
        }

        Application.ThreadException += (_, eventArgs) =>
        {
            AppLog.Error("app", "thread-exception", new Dictionary<string, string>
            {
                ["error"] = eventArgs.Exception.ToString()
            });
        };
        AppDomain.CurrentDomain.UnhandledException += (_, eventArgs) =>
        {
            AppLog.Error("app", "unhandled-exception", new Dictionary<string, string>
            {
                ["error"] = eventArgs.ExceptionObject.ToString() ?? "unknown"
            });
        };

        using var form = new BrowserForm(options.Destination);
        _ = form.Handle;
        instance.StartListening(() =>
        {
            if (!form.IsDisposed)
            {
                form.BeginInvoke((Action)form.ShowOverlayWithoutActivation);
            }
        });

        AppLog.Info("app", "launch", new Dictionary<string, string>
        {
            ["arguments"] = string.Join(' ', arguments)
        });
        Application.Run(form);
        AppLog.Info("app", "exit");
        return 0;
    }
}
