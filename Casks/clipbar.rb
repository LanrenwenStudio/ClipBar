cask "accessdeck" do
  version "0.1.0"
  sha256 "9599261a635298cdb935a37a94c383cbab5d46c00f3ceeddcfdcb2aa6be37ed6"

  url "https://github.com/LanrenwenStudio/AccessDeck/releases/download/v#{version}/accessdeck-#{version}.dmg"
  name "AccessDeck"
  desc "macOS menu bar utility for monitoring CLIProxyAPI account quotas"
  homepage "https://accessdeck.lanrenwen.com"

  depends_on macos: ">= :sonoma"

  app "AccessDeck.app"

  zap trash: [
    "~/Library/Preferences/com.lanrenwen.accessdeck.plist",
  ]
end
