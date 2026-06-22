cask "termsurf" do
  version "1.0.0"
  sha256 "bb6a781cc43aca779b11d2df3c68d2294e02b85c2269f37877c8cacf9ae6411d"

  url "https://github.com/termsurf/termsurf/releases/download/v#{version}/termsurf-#{version}-aarch64-apple-darwin.tar.gz",
      verified: "github.com/termsurf/termsurf/"
  name "TermSurf"
  desc "Protocol for embedding web browsers inside terminal emulators"
  homepage "https://termsurf.com/"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "TermSurf.app"
  binary "web"
  artifact "roamium", target: "/opt/homebrew/opt/termsurf-roamium"
  artifact "surfari", target: "/opt/homebrew/opt/termsurf-surfari"

  postflight do
    app_path = "#{appdir}/TermSurf.app"

    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"web"]
    system_command "codesign", args: ["--force", "--sign", "-", "/opt/homebrew/opt/termsurf-roamium/roamium"]
    system_command "codesign", args: ["--force", "--sign", "-", "/opt/homebrew/opt/termsurf-surfari/surfari"]
    system_command "codesign", args: ["--force", "--sign", "-", "/opt/homebrew/opt/termsurf-surfari/libtermsurf_webkit.dylib"]
    system_command "codesign",
                   args: ["--force", "--deep", "--sign", "-",
                          app_path]
    # Clear quarantine on everything — the tarball propagates the attribute
    # to all extracted files, and Gatekeeper blocks unsigned binaries
    system_command "xattr", args: ["-cr", app_path]
    system_command "xattr", args: ["-cr", "/opt/homebrew/opt/termsurf-roamium"]
    system_command "xattr", args: ["-cr", "/opt/homebrew/opt/termsurf-surfari"]
    system_command "xattr", args: ["-cr", staged_path/"web"]
  end

  zap trash: [
    "~/.config/termsurf",
    "~/.local/share/termsurf",
    "~/.local/state/termsurf",
  ]
end
