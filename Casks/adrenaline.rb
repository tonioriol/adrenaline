cask "adrenaline" do
  version "0.3.0"
  sha256 "fefc1ab8b556022d051036c198ffbc45d5b4f0632a8a3a40d908ccc91b2ae451"

  url "https://github.com/tonioriol/adrenaline/releases/download/v#{version}/Adrenaline-v#{version}.zip"
  name "Adrenaline"
  desc "Menu bar app that prevents system sleep, including with the lid closed"
  homepage "https://github.com/tonioriol/adrenaline"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Adrenaline.app"

  zap trash: [
    "~/Library/Caches/com.tonioriol.adrenaline",
    "~/Library/Caches/com.tonioriol.adrenaline.helper",
    "~/Library/HTTPStorages/com.tonioriol.adrenaline",
    "~/Library/HTTPStorages/com.tonioriol.adrenaline.helper",
    "~/Library/Preferences/com.tonioriol.adrenaline.plist",
  ]
end
