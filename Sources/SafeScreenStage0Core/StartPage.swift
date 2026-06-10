public enum StartPage {
    public static let html = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>SafeScreen Stage 0</title>
      <style>
        :root {
          color-scheme: light dark;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          background: Canvas;
          color: CanvasText;
        }
        body {
          min-height: 100vh;
          margin: 0;
          display: grid;
          place-items: center;
        }
        main {
          width: min(560px, calc(100vw - 48px));
        }
        h1 {
          margin: 0 0 12px;
          font-size: 28px;
          font-weight: 650;
          letter-spacing: 0;
        }
        p {
          margin: 0;
          color: GrayText;
          font-size: 15px;
          line-height: 1.5;
        }
      </style>
    </head>
    <body>
      <main>
        <h1>SafeScreen Stage 0</h1>
        <p>Enter a URL above or launch with: swift run SafeScreenStage0 -- https://example.com</p>
      </main>
    </body>
    </html>
    """
}
