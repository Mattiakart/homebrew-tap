cask "cocaine" do
  version "1.2"
  sha256 "e101c4b499708da3b749b44abc5589cdb790af5bc5a6d108a26d58897ebb6c3a"

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

  # Quitting Cocaine turns it off; the script covers the case where it wasn't running. Not `sudo: true`:
  # Homebrew runs that as `sudo -E`, which Cocaine's narrow sudo rule (no SETENV) refuses.
  uninstall quit:   "local.cocaine.toggle",
            script: {
              executable:   "/bin/sh",
              args:         ["-c", "/usr/bin/pmset -g | /usr/bin/grep -q 'SleepDisabled[[:space:]]*1' || exit 0; " \
                                   "/usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 || " \
                                   "/usr/bin/sudo /usr/bin/pmset -a disablesleep 0"],
              must_succeed: false,
            }

  # The sudo rule is removed only with --zap, so `brew upgrade` doesn't ask for a password on every update.
  zap delete: "/etc/sudoers.d/cocaine",
      trash:  "~/Library/Preferences/local.cocaine.toggle.plist"

  caveats <<~EOS
    Cocaine is not notarized by Apple. The first time you open it, macOS blocks it:
    go to System Settings > Privacy & Security and click "Open Anyway".

    On first launch it asks for your admin password once, to allow exactly
    `pmset -a disablesleep 1` and `pmset -a disablesleep 0`.
    `brew uninstall --zap cocaine` also removes that rule.
  EOS
end
