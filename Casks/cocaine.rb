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

  # Turn the sleep override off before removing the sudo rule that allows changing it.
  uninstall quit:   "local.cocaine.toggle",
            script: {
              executable: "/usr/bin/pmset",
              args:       ["-a", "disablesleep", "0"],
              sudo:       true,
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
