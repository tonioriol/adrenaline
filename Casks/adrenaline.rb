cask "adrenaline" do
  version "0.8.0"
  sha256 "3cc600c43d3327ab5f47f1fc0d4722cc59c06be342cbba24bf0bbc4704ec13ac"

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
