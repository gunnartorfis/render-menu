cask "render-menu" do
  version "0.1.0"
  sha256 "b24716ec097fe72c8f2ef864544b484a9232b815bfc08d58e5d52b8bf3b40950"

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
