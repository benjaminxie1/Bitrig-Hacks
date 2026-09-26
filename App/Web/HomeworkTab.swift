import SwiftUI
import WebKit

/// The homework comes from a web page. iOS apps can't read Safari's tabs, so the page opens in
/// an in-app tab instead. By default that's the bundled Riverside Learning "Show your work" page
/// (offline, deterministic); any other URL works best-effort. Page reading is read-only: forms
/// are never submitted and nothing is typed into the page.
@MainActor
@Observable
final class HomeworkTabModel {
  var address: String
  var pageTitle = ""
  var equation: LinearEquation?
  var status = "Opening your homework…"
  var isLoading = false
  let recording: Bool
  private(set) var url: URL?
  private(set) var loadToken = 0

  init(recording: Bool) {
    self.recording = recording
    url = Self.bundledPage
    address = Self.bundledAddress
  }

  static let bundledAddress = "riverside-learning.edu/modules/show-your-work"

  static var bundledPage: URL? {
    Bundle.main.url(forResource: "working", withExtension: "html", subdirectory: "WebDemo")
      ?? Bundle.main.url(forResource: "working", withExtension: "html")
  }

  var isBundled: Bool { url?.isFileURL ?? true }

  /// Opens whatever the student typed. Recording mode always stays on the bundled page.
  func open(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if recording || trimmed.isEmpty || trimmed.localizedCaseInsensitiveContains("riverside") {
      url = Self.bundledPage
      address = Self.bundledAddress
    } else {
      let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
      guard let next = URL(string: withScheme), next.scheme == "https" || next.scheme == "http" else {
        status = "That doesn't look like a web address."
        return
      }
      url = next
      address = trimmed
    }
    loadToken += 1
  }

  func reload() { loadToken += 1 }

  /// Called with what the page script found. Returns true when an equation was detected.
  func apply(title: String, primary: String, tex: [String], visible: String) {
    pageTitle = title
    let found = LinearEquation.extract(primary: primary, tex: tex, visibleText: visible)
    equation = found
    if let found {
      status = "Found \(found.text.trimmingCharacters(in: .whitespaces))"
    } else {
      status = "No equation on this page yet."
    }
  }
}

/// Address bar + page, in the Burrow pixel style.
struct HomeworkTab: View {
  @Bindable var model: HomeworkTabModel
  var onEquation: (LinearEquation?) -> Void = { _ in }
  @State private var draft = ""
  @FocusState private var editing: Bool

  var body: some View {
    VStack(spacing: 0) {
      addressBar
      HomeworkWebView(model: model)
        .background(Color.white)
        .overlay(alignment: .top) {
          if model.isLoading {
            Rectangle().fill(BurrowTheme.teal).frame(height: 3).transition(.opacity)
          }
        }
      statusLine
    }
    .background { NineSlice(name: "scroll", scale: 2) }
    .clipShape(Rectangle())
    .onChange(of: model.equation) { _, new in onEquation(new) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Homework tab")
  }

  private var addressBar: some View {
    HStack(spacing: 8) {
      Text(model.isBundled ? "⌂" : "↗")
        .font(BurrowTheme.digits(22)).foregroundStyle(BurrowTheme.tealDeep)
        .accessibilityHidden(true)
      if model.recording {
        Text(model.address)
          .font(BurrowTheme.digits(20)).foregroundStyle(BurrowTheme.ink)
          .lineLimit(1).truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        TextField("Paste your homework link", text: $draft)
          .font(BurrowTheme.digits(20)).foregroundStyle(BurrowTheme.ink)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .keyboardType(.URL).submitLabel(.go)
          .focused($editing)
          .onSubmit { model.open(draft) }
          .frame(maxWidth: .infinity)
          .onAppear { draft = model.address }
          .onChange(of: model.address) { _, new in if !editing { draft = new } }
        Button { model.reload() } label: { Text("↻").font(BurrowTheme.digits(22)) }
          .buttonStyle(.plain).foregroundStyle(BurrowTheme.tealDeep)
          .accessibilityLabel("Reload page")
      }
    }
    .padding(.horizontal, 12).padding(.vertical, 7)
    .background { NineSlice(name: "bubble", scale: 2) }
    .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 6)
  }

  private var statusLine: some View {
    HStack(spacing: 6) {
      Text(model.equation == nil ? "?" : "✓")
        .font(BurrowTheme.digits(20))
        .foregroundStyle(model.equation == nil ? BurrowTheme.muted : BurrowTheme.tealDeep)
      Text(model.status)
        .font(BurrowTheme.ui(14)).foregroundStyle(BurrowTheme.muted)
        .lineLimit(1).minimumScaleFactor(0.8)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 8)
    .accessibilityElement(children: .combine)
  }
}

/// WKWebView wrapper. Reads the page after each load (and once more a moment later for
/// script-rendered pages such as Khan Academy), never submits forms, and in recording mode
/// never leaves the bundled file.
struct HomeworkWebView: UIViewRepresentable {
  let model: HomeworkTabModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.userContentController.addUserScript(
      WKUserScript(source: Self.bundledPageTidy, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = context.coordinator
    view.allowsBackForwardNavigationGestures = !model.recording
    view.isOpaque = false
    view.backgroundColor = .white
    context.coordinator.load(into: view)
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {
    if context.coordinator.loadedToken != model.loadToken { context.coordinator.load(into: view) }
  }

  /// On the bundled page only: fit the desktop LMS layout to the narrow facing page so the
  /// question sits at the top, and hide the page's own text box (the working goes on the paper).
  static let bundledPageTidy = """
  if (location.protocol === 'file:') {
    const s = document.createElement('style');
    s.textContent = [
      'nav.main, header.top .btn, .sub, footer, #working, label[for="working"], #check-working, #working-feedback { display: none !important; }',
      'html, body { overflow-x: hidden !important; }',
      'header.top { position: static !important; }',
      '.top-inner { padding: 8px 14px !important; gap: 8px !important; }',
      '.logo { font-size: 15px !important; } .logo span { width: 18px !important; height: 18px !important; }',
      'main { padding: 10px 12px 16px !important; }',
      'h1 { font-size: 19px !important; margin: 0 0 8px !important; }',
      '.problem { padding: 14px 16px !important; border-radius: 12px !important; }',
      '.problem h2 { font-size: 12px !important; margin: 0 0 4px !important; text-transform: uppercase; letter-spacing: .06em; color: #7a6458; }',
      '.problem p { margin: 0 0 2px !important; font-size: 15px !important; }',
      '.equation { font-size: 38px !important; margin: 6px 0 8px !important; }',
      '.note { font-size: 13px !important; margin: 4px 0 0 !important; }'
    ].join('\\n');
    document.head.appendChild(s);
  }
  """

  static let readPage = """
  (() => {
    const text = (sel) => { const el = document.querySelector(sel); return el ? el.innerText : ''; };
    const primary = text('#working-equation') || text('#equation') || text('[data-equation]');
    // TeX sources, plus MathJax 3 / KaTeX rendered text (Khan Academy). NFKC turns math-italic
    // letters such as 𝑤 into plain w; zero-width joiners are dropped.
    const tex = Array.from(document.querySelectorAll('annotation[encoding="application/x-tex"], script[type^="math/tex"]'))
      .map((e) => e.textContent || '')
      .concat(Array.from(document.querySelectorAll('mjx-container, .katex-mathml'))
        .map((e) => (e.textContent || '').normalize('NFKC').replace(/[\\u200B-\\u200D]/g, '')))
      .slice(0, 60);
    const visible = document.body ? document.body.innerText.slice(0, 20000) : '';
    const eq = document.querySelector('#working-equation, #equation, [data-equation]');
    if (eq && location.protocol !== 'file:') eq.scrollIntoView({ block: 'center' });
    return JSON.stringify({ title: document.title || '', primary, tex, visible });
  })()
  """

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate {
    let model: HomeworkTabModel
    var loadedToken = -1

    init(model: HomeworkTabModel) { self.model = model }

    func load(into view: WKWebView) {
      loadedToken = model.loadToken
      guard let url = model.url else {
        model.status = "The homework page is missing from the app."
        return
      }
      model.isLoading = true
      if url.isFileURL {
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
      } else {
        view.load(URLRequest(url: url))
      }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
      // Read-only: never submit a form on the student's behalf.
      if navigationAction.navigationType == .formSubmitted || navigationAction.navigationType == .formResubmitted {
        decisionHandler(.cancel); return
      }
      if model.recording, let url = navigationAction.request.url, !url.isFileURL, url.scheme != "about" {
        decisionHandler(.cancel); return
      }
      decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      model.isLoading = false
      if let url = webView.url, !url.isFileURL { model.address = url.absoluteString }
      read(webView)
      if !(webView.url?.isFileURL ?? true) {
        // Script-rendered pages (Khan Academy, most LMSs) often draw the math after load.
        Task { @MainActor [weak self, weak webView] in
          try? await Task.sleep(for: .seconds(1.5))
          if let self, let webView, self.model.equation == nil { self.read(webView) }
        }
      }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
      model.isLoading = false
      model.status = "That page didn't load."
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
      model.isLoading = false
      model.status = "That page didn't load."
    }

    private func read(_ webView: WKWebView) {
      let model = self.model
      webView.evaluateJavaScript(HomeworkWebView.readPage) { result, _ in
        guard let json = result as? String else {
          MainActor.assumeIsolated { model.status = "I couldn't read this page." }
          return
        }
        struct Page: Decodable { var title: String; var primary: String; var tex: [String]; var visible: String }
        let page = try? JSONDecoder().decode(Page.self, from: Data(json.utf8))
        MainActor.assumeIsolated {
          if let page {
            model.apply(title: page.title, primary: page.primary, tex: page.tex, visible: page.visible)
          } else {
            model.status = "I couldn't read this page."
          }
        }
      }
    }
  }
}
