cask "insomnia" do
  version "0.2.1"
  sha256 "08e00e469f115376e9739b7448476f8be14c9820ba724e7dd7c31ecf576c1ada"

  url "https://github.com/tonioriol/insomnia/releases/download/v#{version}/Insomnia-v#{version}.zip"
  name "Insomnia"
  desc "Menu bar app that prevents system sleep"
  homepage "https://github.com/tonioriol/insomnia"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Insomnia.app"

  zap trash: [
    "~/Library/Caches/com.tonioriol.insomnia",
    "~/Library/Caches/com.tonioriol.insomnia.helper",
    "~/Library/HTTPStorages/com.tonioriol.insomnia",
    "~/Library/HTTPStorages/com.tonioriol.insomnia.helper",
    "~/Library/Preferences/com.tonioriol.insomnia.plist",
  ]
end
