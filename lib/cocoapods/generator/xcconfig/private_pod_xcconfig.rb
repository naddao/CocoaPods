module Pod
  module Generator
    module XCConfig
      # Generates the private xcconfigs for the pod targets.
      #
      # The private xcconfig file for a Pod target merges the configuration
      # values of the public namespaced xcconfig with the default private
      # configuration values required by CocoaPods.
      #
      class PrivatePodXCConfig
        # @return [Target] the target represented by this xcconfig.
        #
        attr_reader :target

        # @return [Xcodeproj::Config] The public xcconfig which this one will
        #         use.
        #
        attr_reader :public_xcconfig

        # Init a new instance
        #
        # @param  [Target] target @see target
        # @param  [Xcodeproj::Config] public_xcconfig @see public_xcconfig
        #
        def initialize(target, public_xcconfig)
          @target = target
          @public_xcconfig = public_xcconfig
        end

        # @return [Xcodeproj::Config] The generated xcconfig.
        #
        attr_reader :xcconfig

        # Generates and saves the xcconfig to the given path.
        #
        # @param  [Pathname] path
        #         the path where the prefix header should be stored.
        #
        # @return [void]
        #
        def save_as(path)
          generate.save_as(path)
        end

        # Generates the xcconfig.
        #
        # @return [Xcodeproj::Config]
        #
        def generate
          target_search_paths = target.build_headers.search_paths(target.platform)
          sandbox_search_paths = target.sandbox.public_headers.search_paths(target.platform)
          search_paths = target_search_paths.concat(sandbox_search_paths).uniq

          config = {
            'OTHER_LDFLAGS' => XCConfigHelper.default_ld_flags(target),
            'PODS_ROOT'  => '${SRCROOT}',
            'HEADER_SEARCH_PATHS' => XCConfigHelper.quote(search_paths),
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
            'SKIP_INSTALL' => 'YES',
            # 'USE_HEADERMAP' => 'NO'
          }

          if target.requires_frameworks?
            # Only quote the FRAMEWORK_SEARCH_PATHS entry, because it’s a setting that takes multiple values.
            # In addition, quoting CONFIGURATION_BUILD_DIR would make it be interpreted as a relative path.
            build_settings = {
              'PODS_FRAMEWORK_BUILD_PATH' => target.configuration_build_dir,
              'CONFIGURATION_BUILD_DIR' => '$PODS_FRAMEWORK_BUILD_PATH',
              'FRAMEWORK_SEARCH_PATHS' => '"$PODS_FRAMEWORK_BUILD_PATH"',
            }
            config.merge!(build_settings)
          end

          xcconfig_hash = add_xcconfig_namespaced_keys(public_xcconfig.to_hash, config, target.xcconfig_prefix)
          @xcconfig = Xcodeproj::Config.new(xcconfig_hash)
          XCConfigHelper.add_target_specific_settings(target, @xcconfig)
          @xcconfig.includes = [target.name]
          @xcconfig
        end

        private

        #-----------------------------------------------------------------------#

        # !@group Private Helpers

        # Returns the hash representation of an xcconfig which inherit from the
        # namespaced keys of a given one.
        #
        # @param  [Hash] source_config
        #         The xcconfig whose keys need to be inherited.
        #
        # @param  [Hash] destination_config
        #         The config which should inherit the source config keys.
        #
        # @return [Hash] The inheriting xcconfig.
        #
        def add_xcconfig_namespaced_keys(source_config, destination_config, prefix)
          result = destination_config.dup
          source_config.each do |key, _value|
            prefixed_key = prefix + conditional_less_key(key)
            current_value = destination_config[key]
            if current_value
              result[key] = "#{current_value} ${#{prefixed_key}}"
            else
              result[key] = "${#{prefixed_key}}"
            end
          end
          result
        end

        # Strips the [*]-syntax from the given xcconfig key.
        #
        # @param  [String] key
        #         The key to strip.
        #
        # @return [String] The stripped key.
        #
        def conditional_less_key(key)
          brackets_index = key.index('[')
          if brackets_index
            key[0...brackets_index]
          else
            key
          end
        end

        #-----------------------------------------------------------------------#
      end
    end
  end
end
