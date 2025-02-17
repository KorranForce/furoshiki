require 'warbler'
require 'warbler/traits'

module Warbler
  module Traits
    # Hack to stop bundler injecting itself
    class Bundler
      def self.detect?
        false
      end
    end

    class Furoshiki
      include ::Warbler::Trait
      include PathmapHelper

      def self.detect?
        true
      end

      def self.requirements
        [Traits::Jar]
      end

      def update_archive(jar)
        # Not sure why Warbler doesn't do this automatically
        jar.files.delete_if { |k, v| @config.excludes.include? k }
      end
    end
  end
end
