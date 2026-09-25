# frozen_string_literal: true

cask "cocaine" do
  version "1.7.4"
  sha256 "4a2d47d487d848d284f0f3270d5bc1ef43abcc8fc5c294b3679cab1ca0ed11a5"

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
        /usr/bin/printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /bin/rm -f /etc/sudoers.d/cocaine\n' "$u" > "$t"
        /usr/sbin/visudo -cf "$t" >/dev/null && /usr/bin/install -m 0440 -o root -g wheel "$t" /etc/sudoers.d/cocaine
        r=$?; /bin/rm -f "$t"; exit $r
      SH
    end
  end

  # Quitting Cocaine turns it off. A real uninstall also removes its AI alerts hooks (from each AI tool's settings,
  # leaving the rest as it was) and its sudo rule, passwordless because the rule allows exactly that (older
  # rules fall back to one Touch ID prompt); `brew upgrade`/`reinstall` keep both, so updates never ask for anything.
  # Not `sudo: true`: Homebrew runs that as `sudo -E`, which the narrow rule refuses.
  uninstall quit:   "local.cocaine.toggle",
            script: {
              executable:   "/bin/sh",
              args:         ["-c", <<~SH],
                up=0; p=$PPID
                for i in 1 2 3 4 5; do
                  case "$(/bin/ps -o args= -p "$p")" in *"brew.rb upgrade"*|*"brew.rb reinstall"*|*"brew.rb install"*) up=1 ;; esac
                  p=$(/bin/ps -o ppid= -p "$p" | /usr/bin/tr -d " "); [ -n "$p" ] && [ "$p" -gt 1 ] || break
                done
                if /usr/bin/pmset -g | /usr/bin/grep -q "SleepDisabled[[:space:]]*1"; then
                  /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null || /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
                fi
                [ "$up" = 1 ] && exit 0
                for a in /Applications/Cocaine.app "$HOME/Applications/Cocaine.app"; do
                  [ -x "$a/Contents/MacOS/Cocaine" ] && { "$a/Contents/MacOS/Cocaine" --ai-alerts off >/dev/null 2>&1; break; }
                done
                [ -e /etc/sudoers.d/cocaine ] || exit 0
                /usr/bin/sudo -n /bin/rm -f /etc/sudoers.d/cocaine 2>/dev/null || /usr/bin/osascript -e 'do shell script "/bin/rm -f /etc/sudoers.d/cocaine" with prompt "Cocaine: removing its sleep permission." with administrator privileges'
              SH
              must_succeed: false,
            }

  zap trash: "~/Library/Preferences/local.cocaine.toggle.plist"

  caveats <<~EOS
    The password asked above (once, on first install) lets Cocaine run exactly `pmset -a disablesleep 1|0`.
    Updates never ask again, and `brew uninstall` removes that permission without asking.
  EOS
end
