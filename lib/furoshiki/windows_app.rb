require 'furoshiki/exceptions'
require 'furoshiki/zip/directory'
require 'furoshiki/jar'
require 'fileutils'
require 'plist'
require 'open-uri'
require 'net/http'

module Furoshiki
  class WindowsApp
    include FileUtils

    # @param [Furoshiki::Shoes::Configuration] config user configuration
    def initialize(config)
      @config = config

      unless config.valid?
        raise Furoshiki::ConfigurationError, "Invalid configuration.\n#{config.error_message_list}"
      end

      home = ENV['FUROSHIKI_HOME'] || Dir.home
      @cache_dir = Pathname.new(home).join('.furoshiki', 'cache')
      @default_package_dir = working_dir.join('pkg')
      @package_dir = default_package_dir
      @default_template_path = cache_dir.join(template_filename)
      @template_path = default_template_path
      @tmp = @package_dir.join('tmp')
    end

    # @return [Pathname] default package directory: ./pkg
    attr_reader :default_package_dir

    # @return [Pathname] package directory
    attr_accessor :package_dir

    # @return [Pathname] default path to app template
    attr_reader :default_template_path

    # @return [Pathname] path to app template
    attr_accessor :template_path

    # @return [Pathname] cache directory
    attr_reader :cache_dir

    attr_reader :config

    attr_reader :tmp

    def package
      remove_tmp
      create_tmp
      cache_template
      extract_template
      inject_icon
      inject_config
      jar_path = ensure_jar_exists
      inject_jar jar_path
      rename_application
      move_to_package_dir tmp_app_path
      tweak_permissions
    ensure
      remove_tmp
    end

    private

    def create_tmp
      tmp.mkpath
    end

    def remove_tmp
      tmp.rmtree if tmp.exist?
    end

    def cache_template
      cache_dir.mkpath unless cache_dir.exist?
      download_template unless template_path.size?
    end

    def template_basename
      'windows-app-template'
    end

    def template_extension
      '.zip'
    end

    def template_filename
      "#{template_basename}-#{latest_template_version}#{template_extension}"
    end

    def latest_template_version
      '0.0.1'
    end

    def download_template
      download remote_template_url, template_path
    end

    def download(remote_url, local_path)
      download_following_redirects remote_url, local_path
    end

    def download_following_redirects(remote_url, local_path, redirect_limit = 5)
      if redirect_limit == 0
        raise Furoshiki::DownloadError,
              "Too many redirects trying to reach #{remote_url}"
      end

      uri = URI(remote_url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request request do |response|
          case response
          when Net::HTTPSuccess then
            warn "Downloading #{remote_url} to #{local_path}"
            open(local_path, 'wb') do |file|
              response.read_body do |chunk|
                file.write chunk
              end
            end
          when Net::HTTPRedirection then
            location = response['location']
            warn "Redirected to #{location}"
            download_following_redirects(location, local_path, redirect_limit - 1)
          else
            raise Furoshiki::DownloadError, "Couldn't download app template at #{remote_url}. #{response.value}"
          end
        end
      end
    end

    def remote_template_url
      "https://github.com/jasonrclark/windows-app-templates/releases/download/v0.0.1/windows-app-template-0.0.1.zip"
    end

    def move_to_package_dir(path)
      dest = package_dir.join(app_name)
      dest.rmtree if dest.exist?
      mv path.to_s, dest
    end

    def ensure_jar_exists
      jar = Jar.new(@config)
      path = tmp.join(jar.filename)
      jar.package(tmp) unless File.exist?(path)
      path
    end

    def inject_jar(jar_path)
      cp Pathname.new(jar_path), File.join(tmp_app_path, "app.jar")
    end

    def extract_template
      raise IOError, "Couldn't find app template at #{template_path}." unless template_path.size?
      extracted_app = nil

      ::Zip::File.open(template_path) do |zip_file|
        zip_file.each do |entry|
          p = tmp.join(entry.name)
          p.dirname.mkpath
          entry.extract(p)
        end
      end
    end

    def inject_config
      #plist = tmp_app_path.join 'Contents/Info.plist'
      #template = Plist.parse_xml(plist)
      #template['CFBundleIdentifier'] = "com.hackety.shoes.#{config.shortname}"
      #template['CFBundleDisplayName'] = config.name
      #template['CFBundleName'] = config.name
      #template['CFBundleVersion'] = config.version
      #template['CFBundleIconFile'] = Pathname.new(config.icons[:osx]).basename.to_s if config.icons[:osx]
      #File.open(plist, 'w') { |f| f.write template.to_plist }
    end

    def inject_icon
      #if config.icons[:osx]
        #icon_path = working_dir.join(config.icons[:osx])
        #raise IOError, "Couldn't find app icon at #{icon_path}" unless icon_path.exist?
        #resources_dir = tmp_app_path.join('Contents/Resources')
        #cp icon_path, resources_dir.join(icon_path.basename)
      #end
    end

    def rename_application
      mv File.join(tmp_app_path, "app.bat"), File.join(tmp_app_path, "#{config.name}.bat")
    end

    def tweak_permissions
      #executable_path.chmod 0755
    end

    def app_name
      "#{config.name}-windows"
    end

    def tmp_app_path
      tmp.join "#{template_basename}"
    end

    def app_path
      package_dir.join app_name
    end

    def working_dir
      config.working_dir
    end
  end
end
