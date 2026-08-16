cask "clipbar" do
  version "0.1.0"
  sha256 "9599261a635298cdb935a37a94c383cbab5d46c00f3ceeddcfdcb2aa6be37ed6"

  url "https://github.com/LanrenwenStudio/ClipBar/releases/download/v#{version}/clipbar-#{version}.dmg"
  name "ClipBar"
  desc "macOS menu bar utility for monitoring CLIProxyAPI account quotas"
  homepage "https://clipbar.lanrenwen.com"

  depends_on macos: ">= :sonoma"

  app "ClipBar.app"

  zap trash: [
    "~/Library/Preferences/com.lanrenwen.clipbar.plist",
  ]
end
