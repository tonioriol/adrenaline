cask "adrenaline" do
  version "0.2.2"
  sha256 "90da9f8deba56e531a22dc23198d73445c64e098ee513d2a778560b2f0b23bf7"

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
