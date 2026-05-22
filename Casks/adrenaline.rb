cask "adrenaline" do
  version "0.4.0"
  sha256 "fa2942610aef454585ad8cbbb228350518c7e4e5a0cd9baf2f5d3788f2ffd244"

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
