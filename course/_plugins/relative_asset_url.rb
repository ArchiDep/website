module ArchiDep
  module RelativeAssetUrlFilter
    include Jekyll::Filters::URLFilters

    def relative_file_url(path)
      page = @context.registers[:page]
      return path unless page && page.respond_to?(:permalink)

      relative_url("#{page.permalink}#{path}")
    end

    def relative_asset_url(path)
      site = @context.registers[:site]

      cached_assets = site.data["asset_urls"] || {}
      site.data["asset_urls"] = cached_assets

      return cached_assets[path] if cached_assets.key?(path)

      dest_dir = site.dest
      dest_dir_path = Pathname.new(dest_dir)
      course_dir = File.join(dest_dir, "assets", "course")

      phoenix_cache_manifest_file = File.join(dest_dir, "cache_manifest.json")
      webpack_manifest_file = File.join(course_dir, "manifest.json")

      asset_file = File.join(dest_dir, path)
      asset_dir = File.dirname(asset_file)

      result =
        if asset_dir == course_dir
          course_dir_path = Pathname.new(course_dir)
          determine_course_asset_url(
            Pathname.new(asset_file).relative_path_from(course_dir_path),
            webpack_manifest_file,
            dest_dir_path
          )
        else
          determine_other_asset_url(
            Pathname.new(asset_file).relative_path_from(dest_dir_path),
            phoenix_cache_manifest_file
          )
        end

      cached_assets[path] = result

      result
    end

    private

    def determine_course_asset_url(
      relative_path,
      webpack_manifest_file,
      dest_dir_path
    )
      manifest = JSON.parse(File.read(webpack_manifest_file))
      result = manifest["/assets/course/#{relative_path.to_s}"]
      unless result
        raise "Course asset #{relative_path.to_s.inspect} not found in manifest #{webpack_manifest_file.inspect}"
      end
      Jekyll.logger.info "Relative asset URL for /assets/course/#{relative_path} is #{result} (from manifest in #{Pathname.new(webpack_manifest_file).relative_path_from(dest_dir_path).to_s})"
      result
    end

    def determine_other_asset_url(relative_path, phoenix_cache_manifest_file)
      if not File.exist?(phoenix_cache_manifest_file)
        if Jekyll.env == "production"
          raise "Manifest file #{phoenix_cache_manifest_file.to_s.inspect} does not exist"
        end

        result = relative_url(relative_path.to_s)
        Jekyll.logger.info "Relative asset URL for #{relative_path} is #{result} (no manifest in #{Jekyll.env})"
        return result
      end

      manifest = JSON.parse(File.read(phoenix_cache_manifest_file))
      result = manifest.dig("latest", relative_path.to_s)
      unless result
        raise "Asset #{relative_path.to_s.inspect} not found in manifest #{phoenix_cache_manifest_file.inspect}"
      end

      Jekyll.logger.info "Relative asset URL for #{relative_path} is #{result} (from manifest in #{phoenix_cache_manifest_file})"
      result
    end
  end
end

Liquid::Template.register_filter(ArchiDep::RelativeAssetUrlFilter)
