cask "insomnia" do
  version "0.1.0"
  sha256 "553081a28b65ee0d2e1046263cc43d5430ad663af7a7ff464e83bd39cd818cc0"

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
