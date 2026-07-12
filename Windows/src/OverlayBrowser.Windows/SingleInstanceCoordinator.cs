namespace OverlayBrowser.Windows;

internal sealed class SingleInstanceCoordinator : IDisposable
{
    private const string MutexName = @"Local\OverlayBrowser.Windows.Instance";
    private const string ShowEventName = @"Local\OverlayBrowser.Windows.Show";

    private readonly Mutex _mutex;
    private readonly EventWaitHandle _showEvent;
    private readonly EventWaitHandle _shutdownEvent = new(false, EventResetMode.ManualReset);
    private Thread? _listenerThread;
    private bool _disposed;

    internal SingleInstanceCoordinator()
    {
        _mutex = new Mutex(true, MutexName, out bool createdNew);
        IsPrimary = createdNew;
        _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
    }

    internal bool IsPrimary { get; }

    internal void SignalExistingInstance() => _showEvent.Set();

    internal void StartListening(Action onShowRequested)
    {
        if (!IsPrimary || _listenerThread is not null)
        {
            return;
        }

        _listenerThread = new Thread(() =>
        {
            WaitHandle[] handles = [_showEvent, _shutdownEvent];
            while (WaitHandle.WaitAny(handles) == 0)
            {
                onShowRequested();
            }
        })
        {
            IsBackground = true,
            Name = "OverlayBrowser.SingleInstance"
        };
        _listenerThread.Start();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _shutdownEvent.Set();
        _listenerThread?.Join(TimeSpan.FromSeconds(1));
        _showEvent.Dispose();
        _shutdownEvent.Dispose();
        if (IsPrimary)
        {
            _mutex.ReleaseMutex();
        }

        _mutex.Dispose();
    }
}
