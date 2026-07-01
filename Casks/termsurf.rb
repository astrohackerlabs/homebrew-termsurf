cask "termsurf" do
  version "1.4.10"
  sha256 "db6f5e3bb92f6ddc4d222a1ec83e5de81429aa908f2cfcef6210106750332522"

  url "https://github.com/termsurf/termsurf/releases/download/v#{version}/termsurf-#{version}-aarch64-apple-darwin.tar.gz",
      verified: "github.com/termsurf/termsurf/"
  name "TermSurf"
  desc "Protocol for embedding web browsers inside terminal emulators"
  homepage "https://termsurf.com/"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "TermSurf.app"
  binary "web"
  binary "termsurf"
  artifact "roamium", target: "/opt/homebrew/opt/termsurf-roamium"
  artifact "surfari", target: "/opt/homebrew/opt/termsurf-surfari"
  artifact "gtui", target: "/opt/homebrew/opt/termsurf-gtui"

  postflight do
    app_path = "#{appdir}/TermSurf.app"
    surfari_dir = "/opt/homebrew/opt/termsurf-surfari"
    surfari_runtime_artifacts = [
      "surfari",
      "libtermsurf_webkit.dylib",
      "WebKit.framework",
      "WebCore.framework",
      "JavaScriptCore.framework",
      "WebKitLegacy.framework",
      "WebInspectorUI.framework",
      "WebGPU.framework",
      "libANGLE-shared.dylib",
      "libWebKitSwift.dylib",
      "libwebrtc.dylib",
      "com.apple.WebKit.GPU.xpc",
      "com.apple.WebKit.Model.xpc",
      "com.apple.WebKit.Networking.xpc",
      "com.apple.WebKit.WebContent.CaptivePortal.xpc",
      "com.apple.WebKit.WebContent.Development.xpc",
      "com.apple.WebKit.WebContent.EnhancedSecurity.xpc",
      "com.apple.WebKit.WebContent.xpc",
    ]

    # Clear quarantine on everything — the tarball propagates the attribute
    # to all extracted files, and Gatekeeper blocks unsigned binaries
    clear_xattrs = lambda do |path|
      system_command "find", args: [path.to_s, "!", "-type", "l",
                                    "-exec", "xattr", "-c", "{}", "+"]
    end

    clear_xattrs.call(app_path)
    clear_xattrs.call("/opt/homebrew/opt/termsurf-roamium")
    clear_xattrs.call("/opt/homebrew/opt/termsurf-gtui")
    surfari_runtime_artifacts.each do |artifact|
      clear_xattrs.call("#{surfari_dir}/#{artifact}")
    end
    clear_xattrs.call(staged_path/"web")
    clear_xattrs.call(staged_path/"termsurf")

    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"web"]
    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"termsurf"]
    system_command "codesign", args: ["--force", "--sign", "-", "/opt/homebrew/opt/termsurf-roamium/roamium"]
    surfari_runtime_artifacts.each do |artifact|
      system_command "codesign", args: ["--force", "--deep", "--sign", "-", "#{surfari_dir}/#{artifact}"]
    end
    system_command "codesign",
                   args: ["--force", "--deep", "--sign", "-",
                          app_path]
  end

  zap trash: [
    "~/.config/termsurf",
    "~/.local/share/termsurf",
    "~/.local/state/termsurf",
  ]
end
