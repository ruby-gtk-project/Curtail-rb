# frozen_string_literal: true

module CurtailRb
  # Where the non-Ruby files live. Upstream compiled these into a GResource;
  # this port reads them off disk, so every consumer goes through here.
  module Paths
    module_function

    def data_dir = File.expand_path('../../data', __dir__)

    def icon_dir = File.join(data_dir, 'icons')

    def schema_file
      File.join(data_dir, 'com.github.huluti.Curtail.Rb.gschema.xml')
    end
  end
end
