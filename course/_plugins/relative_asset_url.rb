module ArchiDep
  module RelativeAssetUrlFilter
    include Jekyll::Filters::URLFilters

    def relative_file_url(path)
      page = @context.registers[:page]
      return path unless page && page.respond_to?(:permalink)

      relative_url("#{page.permalink}#{path}")
    end

    # Every asset of the site is cache-busted by `mix phx.digest`, which records
    # the name it published each one under in `cache_manifest.json`. That file
    # is the single asset manifest: the bundlers write plain names into the
    # static directory and the digest step, which runs over all of it, is what
    # gives them a content-hashed one.
    def relative_asset_url(path)
      site = @context.registers[:site]

      cached_assets = site.data["asset_urls"] || {}
      site.data["asset_urls"] = cached_assets

      return cached_assets[path] if cached_assets.key?(path)

      dest_dir = site.dest
      manifest_file = File.join(dest_dir, "cache_manifest.json")
      relative_path =
        Pathname.new(File.join(dest_dir, path)).relative_path_from(
          Pathname.new(dest_dir)
        )

      result = determine_asset_url(relative_path, manifest_file)

      cached_assets[path] = result

      result
    end

    private

    def determine_asset_url(relative_path, manifest_file)
      if not File.exist?(manifest_file)
        if Jekyll.env == "production"
          raise "Manifest file #{manifest_file.to_s.inspect} does not exist"
        end

        result = relative_url(relative_path.to_s)
        Jekyll.logger.info "Relative asset URL for #{relative_path} is #{result} (no manifest in #{Jekyll.env})"
        return result
      end

      manifest = JSON.parse(File.read(manifest_file))
      result = manifest.dig("latest", relative_path.to_s)
      unless result
        raise "Asset #{relative_path.to_s.inspect} not found in manifest #{manifest_file.inspect}"
      end

      url = "/#{result}"
      Jekyll.logger.info "Relative asset URL for #{relative_path} is #{url} (from manifest in #{manifest_file})"
      url
    end
  end
end

Liquid::Template.register_filter(ArchiDep::RelativeAssetUrlFilter)
