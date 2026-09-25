cask "cocaine" do
  version "1.0"
  sha256 "f3eab6ed6bf4ffd7b2ab9817ff93a20d7c7a89080109b12bdd9ac5ab61fd4d54"

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

  # Turn the sleep override off before removing the sudo rule that allows changing it. Not `sudo: true`:
  # Homebrew runs that as `sudo -E`, which Cocaine's narrow rule (no SETENV) refuses. Plain `sudo -n` uses the
  # rule without a password; if the rule is gone, fall back to a normal password prompt.
  uninstall quit:   "local.cocaine.toggle",
            script: {
              executable:   "/bin/sh",
              args:         ["-c", "/usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 || " \
                                   "/usr/bin/sudo /usr/bin/pmset -a disablesleep 0"],
              must_succeed: false,
            },
            delete: "/etc/sudoers.d/cocaine"

  zap trash: "~/Library/Preferences/local.cocaine.toggle.plist"

  caveats <<~EOS
    Cocaine is not notarized by Apple. The first time you open it, macOS blocks it:
    go to System Settings > Privacy & Security and click "Open Anyway".

    On first launch it asks for your admin password once, to allow exactly
    `pmset -a disablesleep 1` and `pmset -a disablesleep 0`.
  EOS
end
