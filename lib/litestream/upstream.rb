module Litestream
  module Upstream
    VERSION = "0.5.9"

    # rubygems platform name => upstream release filename
    NATIVE_PLATFORMS = {
      "aarch64-linux" => "litestream-#{VERSION}-linux-arm64.tar.gz",
      "arm64-darwin" => "litestream-#{VERSION}-darwin-arm64.tar.gz",
      "arm64-linux" => "litestream-#{VERSION}-linux-arm64.tar.gz",
      "x86_64-darwin" => "litestream-#{VERSION}-darwin-x86_64.tar.gz",
      "x86_64-linux" => "litestream-#{VERSION}-linux-x86_64.tar.gz"
    }
  end
end
