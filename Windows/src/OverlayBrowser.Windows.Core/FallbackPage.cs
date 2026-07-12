using System.Net;

namespace OverlayBrowser.Windows;

internal static class FallbackPage
{
    internal static string ForInvalidAddress(string? description = null)
    {
        string message = WebUtility.HtmlEncode(description ?? "Enter an http or https URL in the address bar.");
        return $$"""
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Overlay Browser</title>
              <style>
                :root { font-family: "Segoe UI", sans-serif; color: #17202a; background: #ffffff; }
                body { min-height: 100vh; margin: 0; display: grid; place-items: center; }
                main { box-sizing: border-box; width: min(560px, calc(100vw - 48px)); }
                h1 { margin: 0 0 12px; font-size: 24px; font-weight: 650; letter-spacing: 0; }
                p { margin: 0; color: #4b5563; font-size: 15px; line-height: 1.5; }
              </style>
            </head>
            <body>
              <main>
                <h1>Overlay Browser</h1>
                <p>{{message}}</p>
              </main>
            </body>
            </html>
            """;
    }
}
