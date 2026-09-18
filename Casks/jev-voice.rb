cask "jev-voice" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/chris-wozniczek/jev-voice-control/releases/download/v#{version}/Jev-Voice-#{version}.zip"
  name "Jev Voice"
  desc "Menu-bar voice control powered by TypeSafe AI's Jev"
  homepage "https://github.com/chris-wozniczek/jev-voice-control"

  depends_on :macos

  app "Jev Voice.app"

  uninstall quit: "com.chriswozniczek.jevvoice"

  zap trash: "~/Library/Preferences/com.chriswozniczek.jevvoice.plist"

  caveats <<~EOS
    Jev Voice lives in the menu bar (no Dock icon). Press Option+Space to talk.
    The app is ad-hoc signed; if Gatekeeper blocks it, run:
      xattr -dr com.apple.quarantine "#{appdir}/Jev Voice.app"
    Grant Microphone, Speech Recognition and Accessibility permissions when prompted,
    then set your TypeSafe API key in the popover's Settings (gear icon).
  EOS
end
