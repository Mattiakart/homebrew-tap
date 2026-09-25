# frozen_string_literal: true

cask "cocaine" do
  version "1.4"
  sha256 "d23f33ebc77b003363d01e0d76a30d64d4019bc80d3554b64caef71e3c2f6941"

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

  # Homebrew only: clear the quarantine flag so macOS doesn't show "Open Anyway" (the app isn't notarized).
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Cocaine.app"],
        writable_paths: ["{{appdir}}/Cocaine.app"],
        must_succeed:   false
  end

  # Quitting Cocaine turns it off. A real uninstall also removes its sudo rule, passwordless because the rule allows
  # exactly that (older rules fall back to one Touch ID prompt); `brew upgrade`/`reinstall` keep it, so updating
  # never asks for anything. Not `sudo: true`: Homebrew runs that as `sudo -E`, which the narrow rule refuses.
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
                [ -e /etc/sudoers.d/cocaine ] || exit 0
                /usr/bin/sudo -n /bin/rm -f /etc/sudoers.d/cocaine 2>/dev/null || /usr/bin/osascript -e 'do shell script "/bin/rm -f /etc/sudoers.d/cocaine" with prompt "Cocaine: removing its sleep permission." with administrator privileges'
              SH
              must_succeed: false,
            }

  zap trash: "~/Library/Preferences/local.cocaine.toggle.plist"

  caveats <<~EOS
    First launch only: Cocaine asks for Touch ID (or your password) once, to allow exactly
    `pmset -a disablesleep 1|0`. Updates never ask again; `brew uninstall` removes that permission.
  EOS
end
