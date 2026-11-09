# frozen_string_literal: true

require_relative "../curtail_rb"
require_relative "rb/version"

# The gem's namespace entry point: `require "curtail/rb"` matches the gem name
# `curtail-rb` and carries the version constant the gemspec reads. The app
# itself lives under `CurtailRb`, one file per upstream source file.
module Curtail
  # Namespace for the gem's packaging metadata.
  module Rb
  end
end
