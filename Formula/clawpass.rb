# Homebrew formula for clawpass
# To use with a tap: brew tap christmas-island/tap && brew install clawpass
# Or copy this file into your own homebrew-tap repository.

class Clawpass < Formula
  desc "Session-scoped prompt handoff queue for OpenClaw agents"
  homepage "https://github.com/christmas-island/clawpass"
  license "MIT"
  version "0.2.0"

  on_macos do
    on_intel do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "PLACEHOLDER_SHA256_X86_64_MACOS"
    end

    on_arm do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "PLACEHOLDER_SHA256_AARCH64_MACOS"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-v#{version}-x86_64-unknown-linux-musl.tar.gz"
      sha256 "PLACEHOLDER_SHA256_X86_64_LINUX"
    end

    on_arm do
      url "https://github.com/christmas-island/clawpass/releases/download/v#{version}/clawpass-v#{version}-aarch64-unknown-linux-musl.tar.gz"
      sha256 "PLACEHOLDER_SHA256_AARCH64_LINUX"
    end
  end

  def install
    bin.install "clawpass"
  end

  test do
    assert_match "clawpass", shell_output("#{bin}/clawpass --help")
  end
end
