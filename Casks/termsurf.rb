cask "termsurf" do
  version "1.4.19"
  sha256 "5f6018403a3fb18b3d7bb14bf5e1b30b421b69e6e018269686f2536c59ba993c"

  url "https://github.com/termsurf/termsurf/releases/download/v#{version}/termsurf-#{version}-aarch64-apple-darwin.tar.gz",
      verified: "github.com/termsurf/termsurf/"
  name "TermSurf"
  desc "Protocol for embedding web browsers inside terminal emulators"
  homepage "https://termsurf.com/"

  depends_on arch: :arm64
  depends_on macos: :sequoia
  depends_on formula: "deno"

  app "TermSurf.app"
  binary "web"
  binary "termsurf"
  artifact "roamium", target: "/opt/homebrew/opt/termsurf-roamium"
  artifact "surfari", target: "/opt/homebrew/opt/termsurf-surfari"
  artifact "girlbat", target: "/opt/homebrew/opt/termsurf-girlbat"
  artifact "gtui", target: "/opt/homebrew/opt/termsurf-gtui"

  postflight do
    app_path = "#{appdir}/TermSurf.app"
    surfari_dir = "/opt/homebrew/opt/termsurf-surfari"
    girlbat_dir = "/opt/homebrew/opt/termsurf-girlbat"
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
    girlbat_executable_artifacts = [
      "bin/girlbat",
      "bin/ImageDecoder",
      "bin/RequestServer",
      "bin/WebContent",
      "bin/WebWorker",
      "bin/Compositor",
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
    clear_xattrs.call(girlbat_dir)
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
    Dir["#{girlbat_dir}/lib/*.dylib"].sort.each do |dylib|
      system_command "codesign", args: ["--force", "--sign", "-", dylib]
    end
    girlbat_executable_artifacts.each do |artifact|
      path = "#{girlbat_dir}/#{artifact}"
      next unless File.exist?(path)

      system_command "codesign", args: ["--force", "--deep", "--sign", "-", path]
    end
    system_command "codesign",
                   args: ["--force", "--deep", "--sign", "-",
                          app_path]

    warmup_log = "/opt/homebrew/var/log/termsurf/postflight-warmup.log"
    system_command "mkdir", args: ["-p", File.dirname(warmup_log)]
    warmup_engine = lambda do |engine, binary, framework_path = ""|
      log_path = warmup_log
      timeout_seconds = 180
      start_mono = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      start_wall = (Time.now.to_f * 1000).to_i

      if engine == "roamium"
        ohai "Warming up Roamium. This can take up to two minutes after install or upgrade."
      else
        ohai "Warming up Surfari. This is usually much faster."
      end

      File.open(log_path, "a") do |log|
        log.puts("TermSurfPostflightWarmup event=start engine=#{engine} " \
                 "wall_ms=#{start_wall} binary=#{binary}")
      end

      env = {
        "TERMSURF_ENGINE_STARTUP_TRACE" => "1",
        "TERMSURF_ENGINE_STARTUP_TRACE_FILE" => log_path,
      }
      env["DYLD_FRAMEWORK_PATH"] = framework_path unless framework_path.empty?

      status = nil
      timed_out = false
      pid = nil
      begin
        pid = Process.spawn(env, binary, "--termsurf-warmup")
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
            end
            sleep 1
            begin
              Process.kill("KILL", pid)
            rescue Errno::ESRCH
            end
            begin
              Process.wait(pid)
            rescue Errno::ECHILD
            end
            break
          end
          sleep 0.25
        end
      rescue SystemCallError
      end

      duration_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_mono
      success = status&.success? == true && !timed_out
      exit_status = if status
        status.exitstatus
      else
        "unknown"
      end

      File.open(log_path, "a") do |log|
        log.puts("TermSurfPostflightWarmup event=done engine=#{engine} " \
                 "wall_ms=#{(Time.now.to_f * 1000).to_i} " \
                 "duration_ms=#{duration_ms} success=#{success} " \
                 "timed_out=#{timed_out} exit_status=#{exit_status}")
      end

      unless success
        opoo "TermSurf #{engine} postflight warmup failed or timed out; " \
             "first browser launch may be slower. See #{warmup_log}."
      end
    end

    if ENV["HOMEBREW_TERMSURF_SKIP_POSTFLIGHT_WARMUP"] == "1"
      File.open(warmup_log, "a") do |log|
        log.puts("TermSurfPostflightWarmup event=skipped " \
                 "reason=HOMEBREW_TERMSURF_SKIP_POSTFLIGHT_WARMUP")
      end
    else
      warmup_engine.call("roamium", "/opt/homebrew/opt/termsurf-roamium/roamium")
      warmup_engine.call("surfari", "#{surfari_dir}/surfari", surfari_dir)
    end
  end

  zap trash: [
    "~/.config/termsurf",
    "~/.local/share/termsurf",
    "~/.local/state/termsurf",
  ]
end
