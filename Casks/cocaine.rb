# frozen_string_literal: true

cask "cocaine" do
  version "2.9.2"
  sha256 "6da2f2446b5514827eb33618a4183d5262ac66fdae3354119897d03a122b8d69"

  url "https://github.com/Mattiakart/cocaine/releases/download/v#{version}/Cocaine-#{version}.dmg"
  name "Cocaine"
  desc "Menu bar app that prevents sleep, even with the lid closed"
  homepage "https://github.com/Mattiakart/cocaine"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Cocaine.app"

  postflight_steps do
    # Clear the quarantine flag so macOS doesn't show "Open Anyway" (the app isn't notarized).
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Cocaine.app"],
        writable_paths: ["{{appdir}}/Cocaine.app"],
        must_succeed:   false
    # First install only: set up Cocaine's sudo rule here, where Homebrew asks for your password in Terminal
    # (Touch ID with "Touch ID for sudo" on) instead of the app showing macOS's admin warning.
    # Upgrades find the rule and skip this.
    unless_path_exists "/etc/sudoers.d/cocaine" do
      run "/bin/sh", args: ["-c", <<~SH], sudo: true, must_succeed: false
        u="${SUDO_USER:-$(/usr/bin/stat -f%Su /dev/console)}"
        case "$u" in ""|root|*[!A-Za-z0-9._-]*) exit 1 ;; esac
        t=$(/usr/bin/mktemp /tmp/cocaine.XXXXXX) || exit 1
        /usr/bin/printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset schedule wake * cocaine, /usr/bin/pmset schedule cancel wake * cocaine, /bin/rm -f /etc/sudoers.d/cocaine\n' "$u" > "$t"
        /usr/sbin/visudo -cf "$t" >/dev/null && /usr/bin/install -m 0440 -o root -g wheel "$t" /etc/sudoers.d/cocaine
        r=$?; /bin/rm -f "$t"; exit $r
      SH
    end
  end

  # Quitting Cocaine puts sleep back as it was before Cocaine (its crash watchdog does the same if it dies).
  # `brew upgrade`/`reinstall`: before the old version quits, it is told an update is coming, so sleep stays as it is
  # and the new version takes the session over (3 minutes at most, then the watchdog puts sleep back). Nothing else.
  # A real uninstall also undoes anything a crashed Cocaine left (sleep setting, frozen system HUD, display helper, state
  # files), removes its AI alerts hooks (leaving the rest of each tool's settings as it was) and its sudo rule,
  # passwordless because the rule allows exactly that (older rules fall back to one Touch ID prompt).
  # If Cocaine is still running after `quit` and `signal` (hung), --uninstall-cleanup ends it itself (pid + start time) and
  # waits; if even that fails it exits 75 and the sudo rule is KEPT: the Cocaine left running notices its app was deleted
  # and quits through its engine copy, which still needs the rule to put sleep back.
  # Not `sudo: true`: Homebrew runs that as `sudo -E`, which the narrow rule refuses.
  uninstall early_script: {
              executable:   "/bin/sh",
              args:         ["-c", <<~SH],
                up=0; p=$PPID
                for i in 1 2 3 4 5; do
                  case "$(/bin/ps -o args= -p "$p")" in *"brew.rb upgrade"*|*"brew.rb reinstall"*|*"brew.rb install"*) up=1 ;; esac
                  p=$(/bin/ps -o ppid= -p "$p" | /usr/bin/tr -d " "); [ -n "$p" ] && [ "$p" -gt 1 ] || break
                done
                [ "$up" = 1 ] || exit 0
                for a in /Applications/Cocaine.app "$HOME/Applications/Cocaine.app"; do
                  /usr/bin/grep -q '^# cocaine-recovery: 1' "$a/Contents/Resources/cocaine" 2>/dev/null || continue
                  "$a/Contents/MacOS/Cocaine" --prepare-update >/dev/null 2>&1
                done
                exit 0
              SH
              must_succeed: false,
            },
            quit:         "local.cocaine.toggle",
            signal:       [["TERM", "local.cocaine.toggle"]],
            script:       {
              executable:   "/bin/sh",
              args:         ["-c", <<~SH],
                up=0; p=$PPID
                for i in 1 2 3 4 5; do
                  case "$(/bin/ps -o args= -p "$p")" in *"brew.rb upgrade"*|*"brew.rb reinstall"*|*"brew.rb install"*) up=1 ;; esac
                  p=$(/bin/ps -o ppid= -p "$p" | /usr/bin/tr -d " "); [ -n "$p" ] && [ "$p" -gt 1 ] || break
                done
                [ "$up" = 1 ] && exit 0
                rc=0
                for a in /Applications/Cocaine.app "$HOME/Applications/Cocaine.app"; do
                  [ -x "$a/Contents/MacOS/Cocaine" ] || continue
                  if /usr/bin/grep -q '^# cocaine-recovery: 1' "$a/Contents/Resources/cocaine" 2>/dev/null; then
                    "$a/Contents/MacOS/Cocaine" --uninstall-cleanup >/dev/null 2>&1; rc=$?
                  elif /usr/bin/pmset -g | /usr/bin/grep -q "SleepDisabled[[:space:]]*1"; then   # an older app: as before
                    /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null
                  fi
                  "$a/Contents/MacOS/Cocaine" --ai-alerts off >/dev/null 2>&1
                  break
                done
                if [ "$rc" = 75 ]; then
                  echo "Cocaine is still running and couldn't be stopped: its sleep permission is kept so it can still put sleep back." >&2
                  echo "Quit it (or run: sudo pmset -a disablesleep 0), then remove the permission: sudo rm /etc/sudoers.d/cocaine" >&2
                  exit 0
                fi
                [ -e /etc/sudoers.d/cocaine ] || exit 0
                /usr/bin/sudo -n /bin/rm -f /etc/sudoers.d/cocaine 2>/dev/null || /usr/bin/osascript -e 'do shell script "/bin/rm -f /etc/sudoers.d/cocaine" with prompt "Cocaine: removing its sleep permission." with administrator privileges'
              SH
              must_succeed: false,
            }

  zap trash: [
    "~/Library/Application Support/Cocaine",
    "~/Library/Preferences/local.cocaine.toggle.plist",
  ]

  caveats <<~EOS
    The password asked above (once, on first install) lets Cocaine run exactly `pmset -a disablesleep 1|0`.
    Updates never ask again, and `brew uninstall` removes that permission without asking.
  EOS
end
