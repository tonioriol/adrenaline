cask "insomnia" do
  version "0.2.0"
  sha256 "c65eb36400041f2f5f7acbc2d584fdcf439b32a3bdf908f33475208433fb4ae8"

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
