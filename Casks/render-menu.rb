cask "render-menu" do
  version "0.2.0"
  sha256 "77532ec76a73b6fd5b32e732943ffda3b7ac30aa1eef0943512ecab7612b087a"

  url "https://github.com/gunnartorfis/render-menu/releases/download/v#{version}/RenderMenu-#{version}.zip"
  name "Render Menu"
  desc "macOS menu bar app for Render.com PR preview environments"
  homepage "https://github.com/gunnartorfis/render-menu"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Render Menu.app"

  zap trash: [
    "~/Library/Preferences/com.gunnartorfis.render-menu.plist",
  ]
end
