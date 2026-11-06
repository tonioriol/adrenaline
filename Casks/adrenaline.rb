cask "adrenaline" do
  version "0.7.1"
  sha256 "1920b3ae70f509600b6a58c59ed4e821e338351b602ea09d0d58dc8f2bd1ab4e"

  url "https://github.com/tonioriol/adrenaline/releases/download/v#{version}/Adrenaline-v#{version}.zip"
  name "Adrenaline"
  desc "Menu bar app that prevents system sleep, including with the lid closed"
  homepage "https://github.com/tonioriol/adrenaline"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :high_sierra"

  app "Adrenaline.app"
  binary "#{appdir}/Adrenaline.app/Contents/Helpers/adrenaline"

  zap trash: [
    "~/Library/Caches/com.tonioriol.adrenaline",
    "~/Library/Caches/com.tonioriol.adrenaline.helper",
    "~/Library/HTTPStorages/com.tonioriol.adrenaline",
    "~/Library/HTTPStorages/com.tonioriol.adrenaline.helper",
    "~/Library/Preferences/com.tonioriol.adrenaline.plist",
  ]
end
