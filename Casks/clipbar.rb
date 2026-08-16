cask "clipbar" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/LanrenwenStudio/ClipBar/releases/download/v#{version}/ClipBar.zip"
  name "ClipBar"
  desc "macOS menu bar utility for monitoring CLIProxyAPI account quotas"
  homepage "https://clipbar.lanrenwen.com"

  depends_on macos: ">= :sonoma"

  app "ClipBar.app"

  zap trash: [
    "~/Library/Preferences/com.lanrenwen.clipbar.plist",
  ]
end
