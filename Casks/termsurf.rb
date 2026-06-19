cask "termsurf" do
  version "0.1.6"
  sha256 "2cecf0a518b087b6feb59f8d37203cde6b3d411b59e430234b21e7bad74e2016"

  url "https://github.com/termsurf/termsurf/releases/download/v#{version}/termsurf-#{version}-aarch64-apple-darwin.tar.gz"
  name "TermSurf"
  desc "Protocol for embedding web browsers inside terminal emulators"
  homepage "https://termsurf.com/"

  depends_on macos: :sequoia

  app "TermSurf.app"
  binary "web"
  artifact "roamium", target: "/opt/homebrew/opt/termsurf-roamium"

  postflight do
    app_path = "#{appdir}/TermSurf.app"

    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"web"]
    system_command "codesign", args: ["--force", "--sign", "-", "/opt/homebrew/opt/termsurf-roamium/roamium"]
    system_command "codesign",
                   args: ["--force", "--deep", "--sign", "-",
                          app_path]
    # Clear quarantine on everything — the tarball propagates the attribute
    # to all extracted files, and Gatekeeper blocks unsigned binaries
    system_command "xattr", args: ["-cr", app_path]
    system_command "xattr", args: ["-cr", "/opt/homebrew/opt/termsurf-roamium"]
    system_command "xattr", args: ["-cr", staged_path/"web"]
  end

  zap trash: [
    "~/.config/termsurf",
    "~/.local/share/termsurf",
    "~/.local/state/termsurf",
  ]
end
