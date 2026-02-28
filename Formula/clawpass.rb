# Homebrew formula for clawpass
# To use with a tap: brew tap christmas-island/tap && brew install clawpass
# Or copy this file into your own homebrew-tap repository.
#
# NOTE: SHA256 values must be updated for each release. This is a template.
# Automate via: download each artifact, run `shasum -a 256`, update values.
# Artifact naming follows release.yml: clawpass-<target>.tar.gz (no version in filename).

class Clawpass < Formula
  desc "Session-scoped prompt handoff queue for OpenClaw agents"
  homepage "https://github.com/christmas-island/clawpass"
  license "MIT"
  version "0.2.0"

  on_macos do
    on_intel do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-x86_64-apple-darwin.tar.gz"
      sha256 "PLACEHOLDER_UPDATE_ON_RELEASE"
    end

    on_arm do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-aarch64-apple-darwin.tar.gz"
      sha256 "PLACEHOLDER_UPDATE_ON_RELEASE"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-x86_64-unknown-linux-musl.tar.gz"
      sha256 "PLACEHOLDER_UPDATE_ON_RELEASE"
    end

    on_arm do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-aarch64-unknown-linux-musl.tar.gz"
      sha256 "PLACEHOLDER_UPDATE_ON_RELEASE"
    end
  end

  def install
    bin.install "clawpass"
  end

  test do
    assert_match "clawpass", shell_output("#{bin}/clawpass --help")
  end
end
