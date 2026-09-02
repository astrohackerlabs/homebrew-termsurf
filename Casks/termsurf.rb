cask "termsurf" do
  version "0.3.21"
  sha256 "a8935ff0bb1fa83e87ceac539dd54c4aa50f20fc48a09cbdc68d8fba30c47861"

  url "https://github.com/astrohackerlabs/termsurf/releases/download/v#{version}/astrohacker-#{version}-aarch64-apple-darwin.tar.gz",
      verified: "github.com/astrohackerlabs/termsurf/"
  name "Astrohacker TermSurf"
  desc "Terminal, shell, and web tools"
  homepage "https://termsurf.com/"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Astrohacker TermSurf.app"
  binary "Astrohacker TermSurf.app/Contents/MacOS/ahterm", target: "ahterm"
  binary "ahweb"
  binary "ahsh"
  binary "ahcalc/dist/ahcalc", target: "ahcalc"
  binary "ahkey/dist/ahkey", target: "ahkey"
  binary "ahplt/dist/ahplt", target: "ahplt"
  binary "ahebx/dist/ahebx", target: "ahebx"
  binary "ahnexus/ahnexus", target: "ahnexus"
  binary "ah-chromiumd/ah-chromiumd", target: "ah-chromiumd"
  binary "ahtch/bin/ahtch", target: "ahtch"
  artifact "ahcalc", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahcalc"
  artifact "ahkey", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahkey"
  artifact "ahplt", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahplt"
  artifact "ahebx", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahebx"
  artifact "ahnexus", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahnexus"
  artifact "ah-chromiumd", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ah-chromiumd"
  artifact "ahtch", target: "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahtch"

  postflight do
    app_path = "#{appdir}/Astrohacker TermSurf.app"
    ahcalc_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahcalc"
    ahkey_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahkey"
    ahplt_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahplt"
    ahebx_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahebx"
    ahnexus_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahnexus"
    chromiumd_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ah-chromiumd"
    ahtch_dir = "#{HOMEBREW_PREFIX}/opt/astrohacker-terminal-ahtch"

    clear_xattrs = lambda do |path|
      system_command "find", args: [path.to_s, "!", "-type", "l",
                                    "-exec", "xattr", "-c", "{}", "+"]
    end

    clear_xattrs.call(app_path)
    clear_xattrs.call(ahcalc_dir)
    clear_xattrs.call(ahkey_dir)
    clear_xattrs.call(ahplt_dir)
    clear_xattrs.call(ahebx_dir)
    clear_xattrs.call(ahnexus_dir)
    clear_xattrs.call(chromiumd_dir)
    clear_xattrs.call(ahtch_dir)
    clear_xattrs.call(staged_path/"ahweb")
    clear_xattrs.call(staged_path/"ahsh")
    clear_xattrs.call(staged_path/"ahcalc")
    clear_xattrs.call(staged_path/"ahkey")
    clear_xattrs.call(staged_path/"ahplt")
    clear_xattrs.call(staged_path/"ahebx")
    clear_xattrs.call(staged_path/"ahnexus")
    clear_xattrs.call(staged_path/"ahtch")

    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"ahweb"]
    system_command "codesign", args: ["--force", "--sign", "-", staged_path/"ahsh"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahcalc_dir}/dist/ahcalc"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahkey_dir}/dist/ahkey"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahplt_dir}/dist/ahplt"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahebx_dir}/dist/ahebx"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahnexus_dir}/ahnexus"]
    system_command "codesign", args: ["--force", "--sign", "-", "#{chromiumd_dir}/ah-chromiumd"]
    system_command "codesign",
                   args: ["--force", "--sign", "-", "#{ahtch_dir}/bin/ahtch"]
    system_command "codesign",
                   args: ["--force", "--deep", "--sign", "-",
                          app_path]

    warmup_log = "#{HOMEBREW_PREFIX}/var/log/astrohacker/terminal-postflight-warmup.log"
    system_command "mkdir", args: ["-p", File.dirname(warmup_log)]

    warmup_engine = lambda do |engine, binary, args = [], extra_env = {}|
      timeout_seconds = 180
      start_mono = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      start_wall = (Time.now.to_f * 1000).to_i

      ohai "Warming up Astrohacker TermSurf #{engine}. First browser launch may be slow without this step."

      File.open(warmup_log, "a") do |log|
        log.puts("AstrohackerTerminalPostflightWarmup event=start engine=#{engine} " \
                 "wall_ms=#{start_wall} binary=#{binary} args=#{args.join(" ")}")
      end

      env = {
        "TERMSURF_ENGINE_STARTUP_TRACE"      => "1",
        "TERMSURF_ENGINE_STARTUP_TRACE_FILE" => warmup_log,
      }.merge(extra_env)

      status = nil
      timed_out = false
      pid = nil

      begin
        File.open(warmup_log, "a") do |child_log|
          child_log.sync = true
          pid = Process.spawn(env, binary, *args, "--termsurf-warmup",
                              out: child_log, err: child_log)
        end

        deadline = Time.now + timeout_seconds
        loop do
          waited = Process.waitpid2(pid, Process::WNOHANG)
          if waited
            status = waited[1]
            break
          end
          if Time.now >= deadline
            timed_out = true
            begin
              Process.kill("TERM", pid)
            rescue Errno::ESRCH
              timed_out = true
            end
            sleep 1
            begin
              Process.kill("KILL", pid)
            rescue Errno::ESRCH
              timed_out = true
            end
            begin
              Process.wait(pid)
            rescue Errno::ECHILD
              timed_out = true
            end
            break
          end
          sleep 0.25
        end
      rescue SystemCallError => e
        File.open(warmup_log, "a") do |log|
          log.puts("AstrohackerTerminalPostflightWarmup event=spawn_error engine=#{engine} " \
                   "wall_ms=#{(Time.now.to_f * 1000).to_i} error=#{e.class} message=#{e.message.inspect}")
        end
      end

      duration_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_mono
      success = status&.success? == true && !timed_out
      exit_status = if status
        status.exitstatus
      else
        "unknown"
      end

      File.open(warmup_log, "a") do |log|
        log.puts("AstrohackerTerminalPostflightWarmup event=done engine=#{engine} " \
                 "wall_ms=#{(Time.now.to_f * 1000).to_i} " \
                 "duration_ms=#{duration_ms} success=#{success} " \
                 "timed_out=#{timed_out} exit_status=#{exit_status}")
      end

      unless success
        opoo "Astrohacker TermSurf #{engine} postflight warmup failed or timed out; " \
             "first browser launch may be slower. See #{warmup_log}."
      end
    end

    if ENV["HOMEBREW_ASTROHACKER_TERMINAL_SKIP_POSTFLIGHT_WARMUP"] == "1" ||
       ENV["ASTROHACKER_TERMINAL_SKIP_POSTFLIGHT_WARMUP"] == "1" ||
       ENV["HOMEBREW_TERMSURF_SKIP_POSTFLIGHT_WARMUP"] == "1"
      File.open(warmup_log, "a") do |log|
        log.puts("AstrohackerTerminalPostflightWarmup event=skipped " \
                 "wall_ms=#{(Time.now.to_f * 1000).to_i} " \
                 "reason=skip_env")
      end
    else
      warmup_engine.call("chromium", "#{chromiumd_dir}/ah-chromiumd",
                         ["--browser-name=chromium"])
    end

    # End of install/upgrade (after codesign + warmup). Prefer this over caveats,
    # which Homebrew often prints mid-upgrade before the app is ready.
    ohai "Open Astrohacker TermSurf.app from Applications " \
         "(or Spotlight: search \"Astrohacker TermSurf\")."
  end

  uninstall quit: "com.astrohacker.terminal"

  zap trash: [
    "~/.cache/astrohacker/editor",
    "~/.cache/astrohacker/terminal",
    "~/.cache/astrohacker/termsurf",
    "~/.config/astrohacker/editor",
    "~/.config/astrohacker/terminal",
    "~/.config/astrohacker/termsurf",
    "~/.config/termsurf",
    "~/.local/share/astrohacker/editor",
    "~/.local/share/astrohacker/terminal",
    "~/.local/share/astrohacker/termsurf",
    "~/.local/share/termsurf",
    "~/.local/state/astrohacker/terminal",
    "~/.local/state/astrohacker/termsurf",
    "~/.local/state/termsurf",
    "~/Library/Application Support/com.astrohacker.terminal",
    "~/Library/Application Support/com.astrohacker.terminal.debug",
    "~/Library/Application Support/com.mitchellh.ghostty",
    "~/Library/Application Support/com.termsurf",
    "~/Library/Application Support/com.termsurf.debug",
    "~/Library/Application Support/com.termsurf.ghostboard",
    "~/Library/Application Support/com.termsurf.ghostboard.debug",
    "~/Library/Caches/com.astrohacker.terminal",
    "~/Library/Caches/com.astrohacker.terminal.debug",
    "~/Library/Caches/com.mitchellh.ghostty",
    "~/Library/Caches/com.mitchellh.ghostty.debug",
    "~/Library/Caches/com.termsurf",
    "~/Library/Caches/com.termsurf.debug",
    "~/Library/Caches/com.termsurf.ghostboard",
    "~/Library/Caches/com.termsurf.ghostboard.debug",
    "~/Library/Caches/termsurf",
    "~/Library/HTTPStorages/com.astrohacker.terminal",
    "~/Library/HTTPStorages/com.astrohacker.terminal.debug",
    "~/Library/HTTPStorages/com.mitchellh.ghostty",
    "~/Library/HTTPStorages/com.mitchellh.ghostty.debug",
    "~/Library/HTTPStorages/com.termsurf",
    "~/Library/HTTPStorages/com.termsurf.debug",
    "~/Library/HTTPStorages/com.termsurf.ghostboard",
    "~/Library/HTTPStorages/com.termsurf.ghostboard.debug",
    "~/Library/Preferences/com.astrohacker.terminal.debug.plist",
    "~/Library/Preferences/com.astrohacker.terminal.plist",
    "~/Library/Preferences/com.mitchellh.ghostty.debug.plist",
    "~/Library/Preferences/com.mitchellh.ghostty.plist",
    "~/Library/Preferences/com.termsurf.debug.plist",
    "~/Library/Preferences/com.termsurf.ghostboard.debug.plist",
    "~/Library/Preferences/com.termsurf.ghostboard.plist",
    "~/Library/Preferences/com.termsurf.plist",
    "~/Library/Saved Application State/com.astrohacker.terminal.debug.savedState",
    "~/Library/Saved Application State/com.astrohacker.terminal.savedState",
    "~/Library/Saved Application State/com.mitchellh.ghostty.debug.savedState",
    "~/Library/Saved Application State/com.mitchellh.ghostty.savedState",
    "~/Library/Saved Application State/com.termsurf.debug.savedState",
    "~/Library/Saved Application State/com.termsurf.ghostboard.debug.savedState",
    "~/Library/Saved Application State/com.termsurf.ghostboard.savedState",
    "~/Library/Saved Application State/com.termsurf.savedState",
    "~/Library/WebKit/com.astrohacker.terminal",
    "~/Library/WebKit/com.astrohacker.terminal.debug",
    "~/Library/WebKit/com.mitchellh.ghostty",
    "~/Library/WebKit/com.mitchellh.ghostty.debug",
    "~/Library/WebKit/com.termsurf",
    "~/Library/WebKit/com.termsurf.debug",
    "~/Library/WebKit/com.termsurf.ghostboard",
    "~/Library/WebKit/com.termsurf.ghostboard.debug",
  ]
end
