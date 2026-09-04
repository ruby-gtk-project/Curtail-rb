# frozen_string_literal: true

source "https://rubygems.org"

# libadwaita bindings; pulls in gtk4, glib2, cairo and friends.
gem "adwaita", "~> 4.3"
gem "gem_kit"

group :development, :test do
  # For `rake pot` only: GNU xgettext delegates Ruby extraction to this gem's
  # rxgettext. The app itself reads the .po files directly and needs nothing.
  gem "gettext", "~> 3.4"
  gem "minitest", "~> 5.0"
  gem "rake", "~> 13.0"
  gem "rubocop"
end
