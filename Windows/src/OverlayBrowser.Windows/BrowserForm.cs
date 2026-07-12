using System.ComponentModel;
using System.Globalization;
using System.Text.Json;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace OverlayBrowser.Windows;

internal sealed class BrowserForm : Form
{
    private static readonly Size DefaultContentSize = new(420, 820);
    private const int DefaultScreenMargin = 20;

    private readonly StartDestination _initialDestination;
    private readonly Button _backButton;
    private readonly Button _forwardButton;
    private readonly Button _reloadButton;
    private readonly TextBox _addressField;
    private readonly WebView2 _webView;
    private readonly NotifyIcon _trayIcon;
    private readonly ContextMenuStrip _trayMenu;
    private HotKeyController? _hotKeyController;
    private WindowPrivacyResult? _privacyResult;
    private nint _focusReturnWindow;
    private bool _browserInitialized;
    private bool _inputMode;
    private bool _allowClose;
    private bool _failureShown;
    private bool _internalPage;

    internal BrowserForm(StartDestination initialDestination)
    {
        _initialDestination = initialDestination;

        Text = "Overlay Browser";
        ClientSize = DefaultContentSize;
        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.Sizable;
        MaximizeBox = true;
        MinimizeBox = true;
        ShowInTaskbar = false;
        TopMost = true;
        KeyPreview = true;
        AutoScaleMode = AutoScaleMode.Dpi;

        _backButton = CreateToolbarButton("Back");
        _forwardButton = CreateToolbarButton("Forward");
        _reloadButton = CreateToolbarButton("Reload");
        _addressField = new TextBox
        {
            Anchor = AnchorStyles.Left | AnchorStyles.Right,
            BorderStyle = BorderStyle.FixedSingle,
            Cursor = Cursors.Arrow,
            Margin = new Padding(0, 4, 0, 4),
            TabIndex = 0
        };
        _webView = new WebView2
        {
            Dock = DockStyle.Fill,
            Cursor = Cursors.Arrow,
            DefaultBackgroundColor = Color.White,
            TabIndex = 1
        };

        _trayMenu = new ContextMenuStrip();
        _trayMenu.Items.Add("Show / Hide", null, (_, _) => ToggleOverlay());
        _trayMenu.Items.Add("Exit", null, (_, _) => ExitApplication());
        _trayIcon = new NotifyIcon
        {
            ContextMenuStrip = _trayMenu,
            Icon = SystemIcons.Application,
            Text = "Overlay Browser",
            Visible = true
        };

        BuildLayout();
        WireEvents();
        ApplyDefaultSidebarPlacement();
    }

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams parameters = base.CreateParams;
            parameters.ExStyle |= NativeMethods.WsExToolWindow;
            return parameters;
        }
    }

    internal void ShowOverlayWithoutActivation()
    {
        if (IsDisposed)
        {
            return;
        }

        CaptureReturnFocusWindow();
        WindowPrivacyResult privacy = WindowPrivacy.ApplyAndVerify(Handle);
        if (!privacy.IsProtected)
        {
            FailPrivacy(privacy);
            return;
        }

        _privacyResult = privacy;
        NativeMethods.ShowWindow(Handle, NativeMethods.SwShowNoActivate);
        NativeMethods.SetWindowPos(
            Handle,
            NativeMethods.HwndTopmost,
            0,
            0,
            0,
            0,
            NativeMethods.SwpNoMove
                | NativeMethods.SwpNoSize
                | NativeMethods.SwpNoActivate
                | NativeMethods.SwpShowWindow);
        AppLog.Info("window", "show", PrivacyFields(privacy));
    }

    protected override void OnHandleCreated(EventArgs eventArgs)
    {
        base.OnHandleCreated(eventArgs);
        _privacyResult = WindowPrivacy.ApplyAndVerify(Handle);
        if (_privacyResult.IsProtected)
        {
            AppLog.Info("window", "privacy-applied", PrivacyFields(_privacyResult));
        }
        else
        {
            AppLog.Error("window", "privacy-failed", PrivacyFields(_privacyResult));
        }
    }

    protected override void OnLoad(EventArgs eventArgs)
    {
        base.OnLoad(eventArgs);

        try
        {
            _hotKeyController = new HotKeyController(_ =>
            {
                if (!IsDisposed)
                {
                    BeginInvoke((Action)ToggleOverlay);
                }
            });
            _hotKeyController.Register();
        }
        catch (Win32Exception exception)
        {
            FailStartup("The global Alt+Shift hotkeys could not be registered.", exception);
        }
    }

    protected override async void OnShown(EventArgs eventArgs)
    {
        base.OnShown(eventArgs);

        if (_privacyResult is not { IsProtected: true })
        {
            FailPrivacy(_privacyResult ?? new WindowPrivacyResult(false, 0, 0, "Privacy state is missing."));
            return;
        }

        NativeMethods.SetWindowPos(
            Handle,
            NativeMethods.HwndTopmost,
            0,
            0,
            0,
            0,
            NativeMethods.SwpNoMove | NativeMethods.SwpNoSize | NativeMethods.SwpNoActivate);

        if (_browserInitialized)
        {
            return;
        }

        try
        {
            await InitializeBrowserAsync();
            _browserInitialized = true;
            AppLog.Info("app", "ready");
        }
        catch (WebView2RuntimeNotFoundException exception)
        {
            FailStartup("Microsoft Edge WebView2 Runtime is not installed.", exception);
        }
        catch (Exception exception)
        {
            FailStartup("WebView2 failed to initialize.", exception);
        }
    }

    protected override void OnActivated(EventArgs eventArgs)
    {
        base.OnActivated(eventArgs);
        EnterInputMode();
    }

    protected override void OnDeactivate(EventArgs eventArgs)
    {
        base.OnDeactivate(eventArgs);
        if (_inputMode)
        {
            _inputMode = false;
            AppLog.Info("input", "exit", new Dictionary<string, string> { ["reason"] = "deactivate" });
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs eventArgs)
    {
        if (!_allowClose && eventArgs.CloseReason == CloseReason.UserClosing)
        {
            eventArgs.Cancel = true;
            HideOverlay();
            return;
        }

        base.OnFormClosing(eventArgs);
    }

    protected override void WndProc(ref Message message)
    {
        if (message.Msg == NativeMethods.WmMouseActivate)
        {
            CaptureReturnFocusWindow();
        }

        base.WndProc(ref message);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _hotKeyController?.Dispose();
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            _trayMenu.Dispose();
            _webView.Dispose();
        }

        base.Dispose(disposing);
    }

    private static Button CreateToolbarButton(string text) => new()
    {
        AutoSize = true,
        Cursor = Cursors.Arrow,
        Margin = new Padding(0, 3, 6, 3),
        Text = text,
        UseVisualStyleBackColor = true
    };

    private void BuildLayout()
    {
        var toolbar = new TableLayoutPanel
        {
            AutoSize = true,
            ColumnCount = 4,
            Dock = DockStyle.Top,
            Margin = Padding.Empty,
            Padding = new Padding(8, 5, 8, 5),
            RowCount = 1
        };
        toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        toolbar.Controls.Add(_backButton, 0, 0);
        toolbar.Controls.Add(_forwardButton, 1, 0);
        toolbar.Controls.Add(_reloadButton, 2, 0);
        toolbar.Controls.Add(_addressField, 3, 0);

        var root = new TableLayoutPanel
        {
            ColumnCount = 1,
            Dock = DockStyle.Fill,
            Margin = Padding.Empty,
            Padding = Padding.Empty,
            RowCount = 2
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.Controls.Add(toolbar, 0, 0);
        root.Controls.Add(_webView, 0, 1);
        Controls.Add(root);
    }

    private void WireEvents()
    {
        _backButton.Click += (_, _) =>
        {
            if (_webView.CanGoBack)
            {
                _webView.GoBack();
            }
        };
        _forwardButton.Click += (_, _) =>
        {
            if (_webView.CanGoForward)
            {
                _webView.GoForward();
            }
        };
        _reloadButton.Click += (_, _) => _webView.Reload();
        _addressField.KeyDown += HandleAddressKeyDown;
        _addressField.GotFocus += (_, _) => EnterInputMode();
        _addressField.MouseDown += (_, _) => EnterInputMode();
        _webView.GotFocus += (_, _) => EnterInputMode();
        _webView.MouseDown += (_, _) => EnterInputMode();
        _webView.KeyDown += HandleBrowserKeyDown;
        _trayIcon.DoubleClick += (_, _) => ShowOverlayWithoutActivation();
        KeyDown += HandleBrowserKeyDown;
    }

    private async Task InitializeBrowserAsync()
    {
        Directory.CreateDirectory(AppPaths.WebView2UserDataDirectory);
        var environmentOptions = new CoreWebView2EnvironmentOptions(
            additionalBrowserArguments: "--autoplay-policy=user-gesture-required");
        CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(
            browserExecutableFolder: null,
            userDataFolder: AppPaths.WebView2UserDataDirectory,
            options: environmentOptions);
        await _webView.EnsureCoreWebView2Async(environment);

        CoreWebView2 core = _webView.CoreWebView2;
        core.IsMuted = true;
        await core.AddScriptToExecuteOnDocumentCreatedAsync(BrowserScripts.FixedCursor);
        await core.AddScriptToExecuteOnDocumentCreatedAsync(BrowserScripts.SilentMedia);
        await core.AddScriptToExecuteOnDocumentCreatedAsync(BrowserScripts.EscapeBridge);

        core.SourceChanged += (_, _) => UpdateAddressFromBrowser();
        core.HistoryChanged += (_, _) => UpdateNavigationState();
        core.NavigationStarting += (_, eventArgs) =>
        {
            AppLog.Info("navigation", "start", new Dictionary<string, string> { ["url"] = eventArgs.Uri });
        };
        core.NavigationCompleted += HandleNavigationCompleted;
        core.NewWindowRequested += (_, eventArgs) =>
        {
            eventArgs.Handled = true;
            if (UrlPolicy.TryNormalize(eventArgs.Uri, out Uri? destination))
            {
                Navigate(destination);
            }
        };
        core.ProcessFailed += (_, eventArgs) =>
        {
            AppLog.Error("navigation", "process-failed", new Dictionary<string, string>
            {
                ["kind"] = eventArgs.ProcessFailedKind.ToString(),
                ["reason"] = eventArgs.Reason.ToString()
            });
        };
        core.WebMessageReceived += (_, eventArgs) =>
        {
            try
            {
                using JsonDocument message = JsonDocument.Parse(eventArgs.WebMessageAsJson);
                if (message.RootElement.TryGetProperty("type", out JsonElement type)
                    && type.GetString() == "overlay-escape")
                {
                    ExitInputMode(restoreFocus: true);
                }
            }
            catch (JsonException exception)
            {
                AppLog.Warning("input", "web-message-invalid", new Dictionary<string, string>
                {
                    ["error"] = exception.Message
                });
            }
        };

        switch (_initialDestination)
        {
            case StartDestination.Url destination:
                Navigate(destination.Value, "initial-url");
                break;
            case StartDestination.FallbackPage:
                ShowInternalPage(FallbackPage.ForInvalidAddress());
                AppLog.Warning("navigation", "initial-fallback");
                break;
        }

        UpdateNavigationState();
    }

    private void HandleNavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs eventArgs)
    {
        UpdateNavigationState();
        UpdateAddressFromBrowser();

        if (eventArgs.IsSuccess)
        {
            AppLog.Info("navigation", "finish", new Dictionary<string, string>
            {
                ["url"] = _webView.Source?.AbsoluteUri ?? "unknown"
            });
            return;
        }

        if (eventArgs.WebErrorStatus == CoreWebView2WebErrorStatus.OperationCanceled)
        {
            return;
        }

        string error = eventArgs.WebErrorStatus.ToString();
        AppLog.Error("navigation", "fail", new Dictionary<string, string> { ["error"] = error });
        ShowInternalPage(FallbackPage.ForInvalidAddress($"Page failed to load: {error}."));
    }

    private void HandleAddressKeyDown(object? sender, KeyEventArgs eventArgs)
    {
        if (eventArgs.KeyCode == Keys.Enter)
        {
            eventArgs.Handled = true;
            eventArgs.SuppressKeyPress = true;
            NavigateFromAddress();
        }
        else if (eventArgs.KeyCode == Keys.Escape)
        {
            eventArgs.Handled = true;
            eventArgs.SuppressKeyPress = true;
            ExitInputMode(restoreFocus: true);
        }
    }

    private void HandleBrowserKeyDown(object? sender, KeyEventArgs eventArgs)
    {
        if (eventArgs.KeyCode != Keys.Escape)
        {
            return;
        }

        eventArgs.Handled = true;
        eventArgs.SuppressKeyPress = true;
        ExitInputMode(restoreFocus: true);
    }

    private void NavigateFromAddress()
    {
        if (UrlPolicy.TryNormalize(_addressField.Text, out Uri? destination))
        {
            Navigate(destination);
            return;
        }

        AppLog.Warning("navigation", "invalid-address", new Dictionary<string, string>
        {
            ["value"] = _addressField.Text
        });
        UpdateAddressFromBrowser();
    }

    private void Navigate(Uri destination, string eventName = "load")
    {
        _internalPage = false;
        string url = destination.AbsoluteUri;
        AppLog.Info("navigation", eventName, new Dictionary<string, string> { ["url"] = url });
        _addressField.Text = url;
        _webView.CoreWebView2.Navigate(url);
    }

    private void ShowInternalPage(string html)
    {
        _internalPage = true;
        _webView.CoreWebView2.NavigateToString(html);
    }

    private void UpdateAddressFromBrowser()
    {
        if (_internalPage || _webView.Source is not { } source)
        {
            return;
        }

        if (source.Scheme is "http" or "https")
        {
            _addressField.Text = source.AbsoluteUri;
        }
    }

    private void UpdateNavigationState()
    {
        _backButton.Enabled = _webView.CanGoBack;
        _forwardButton.Enabled = _webView.CanGoForward;
        _reloadButton.Enabled = _browserInitialized || _webView.CoreWebView2 is not null;
    }

    private void ApplyDefaultSidebarPlacement()
    {
        Rectangle workingArea = Screen.PrimaryScreen?.WorkingArea ?? SystemInformation.WorkingArea;
        int width = Width;
        int height = Math.Min(Height, Math.Max(200, workingArea.Height - (DefaultScreenMargin * 2)));
        int x = workingArea.Right - width - DefaultScreenMargin;
        int y = workingArea.Top + Math.Max(DefaultScreenMargin, (workingArea.Height - height) / 2);
        Bounds = new Rectangle(x, y, width, height);
        AppLog.Info("window", "default-frame", new Dictionary<string, string>
        {
            ["height"] = height.ToString(CultureInfo.InvariantCulture),
            ["width"] = width.ToString(CultureInfo.InvariantCulture),
            ["x"] = x.ToString(CultureInfo.InvariantCulture),
            ["y"] = y.ToString(CultureInfo.InvariantCulture)
        });
    }

    private void ToggleOverlay()
    {
        if (Visible && WindowState != FormWindowState.Minimized)
        {
            HideOverlay();
        }
        else
        {
            ShowOverlayWithoutActivation();
        }
    }

    private void HideOverlay()
    {
        ExitInputMode(restoreFocus: true);
        Hide();
        AppLog.Info("window", "hide");
    }

    private void EnterInputMode()
    {
        if (_inputMode)
        {
            return;
        }

        _inputMode = true;
        AppLog.Info("input", "enter");
    }

    private void ExitInputMode(bool restoreFocus)
    {
        bool wasInputMode = _inputMode;
        _inputMode = false;
        ActiveControl = null;

        if (restoreFocus
            && NativeMethods.GetForegroundWindow() == Handle
            && _focusReturnWindow != nint.Zero
            && NativeMethods.IsWindow(_focusReturnWindow))
        {
            NativeMethods.SetForegroundWindow(_focusReturnWindow);
        }

        AppLog.Info("input", wasInputMode ? "exit" : "exit-ignored");
    }

    private void CaptureReturnFocusWindow()
    {
        nint foregroundWindow = NativeMethods.GetForegroundWindow();
        if (foregroundWindow != nint.Zero && foregroundWindow != Handle)
        {
            _focusReturnWindow = foregroundWindow;
        }
    }

    private void FailPrivacy(WindowPrivacyResult result)
    {
        if (_failureShown)
        {
            return;
        }

        _failureShown = true;
        Hide();
        AppLog.Error("window", "privacy-fail-closed", PrivacyFields(result));
        MessageBox.Show(
            $"Overlay Browser could not enable capture exclusion and will close.{Environment.NewLine}{Environment.NewLine}{result.Message}{Environment.NewLine}Win32 error: {result.ErrorCode}",
            "Overlay Browser privacy error",
            MessageBoxButtons.OK,
            MessageBoxIcon.None);
        ExitApplication();
    }

    private void FailStartup(string message, Exception exception)
    {
        if (_failureShown)
        {
            return;
        }

        _failureShown = true;
        AppLog.Error("app", "startup-failed", new Dictionary<string, string>
        {
            ["error"] = exception.Message,
            ["reason"] = message
        });
        MessageBox.Show(
            $"{message}{Environment.NewLine}{Environment.NewLine}{exception.Message}",
            "Overlay Browser startup error",
            MessageBoxButtons.OK,
            MessageBoxIcon.None);
        ExitApplication();
    }

    private void ExitApplication()
    {
        _allowClose = true;
        _trayIcon.Visible = false;
        Close();
        Application.Exit();
    }

    private static Dictionary<string, string> PrivacyFields(WindowPrivacyResult result) =>
        new Dictionary<string, string>
        {
            ["affinity"] = $"0x{result.Affinity:X8}",
            ["error"] = result.ErrorCode.ToString(CultureInfo.InvariantCulture),
            ["message"] = result.Message,
            ["protected"] = result.IsProtected ? "true" : "false"
        };
}
