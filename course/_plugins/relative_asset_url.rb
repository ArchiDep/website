module ArchiDep
  module RelativeAssetUrlFilter
    include Jekyll::Filters::URLFilters

    def relative_asset_url(path)
      dest_dir = @context.registers[:site].dest
      asset_file = File.join(dest_dir, path)

      asset_dir = File.dirname(asset_file)

      phoenix_cache_manifest_file = File.join(asset_dir, 'cache_manifest.json')
      webpack_manifest_file = File.join(asset_dir, 'manifest.json')
      manifest_file = File.exist?(webpack_manifest_file) ? webpack_manifest_file : phoenix_cache_manifest_file
      manifest = if File.exist?(manifest_file)
        JSON.parse(File.read(manifest_file))
      else
        raise "No manifest file found for asset #{path.inspect}" if Jekyll.env == 'production'
        {}
      end

      asset_basename = File.basename(path)
      if asset_basename_with_digest = manifest.dig('latest', asset_basename)
        relative_url(path.sub(/\/[^\/]+\z/, "/#{asset_basename_with_digest}"))
      elsif asset_path_with_digest = manifest[path]
        relative_url(asset_path_with_digest)
      else
        relative_url(path)
      end
    end
  end
end

Liquid::Template.register_filter(ArchiDep::RelativeAssetUrlFilter)
