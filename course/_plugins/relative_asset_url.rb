module ArchiDep
  module RelativeAssetUrlFilter
    include Jekyll::Filters::URLFilters

    def relative_file_url(path)
      page = @context.registers[:page]
      return path unless page && page.respond_to?(:permalink)

      relative_url("#{page.permalink}#{path}")
    end

    def relative_asset_url(path)
      dest_dir = @context.registers[:site].dest
      asset_file = File.join(dest_dir, path)

      asset_dir = File.dirname(asset_file)

      phoenix_cache_manifest_file = File.join(asset_dir, "cache_manifest.json")
      webpack_manifest_file = File.join(asset_dir, "manifest.json")
      manifest_file =
        (
          if File.exist?(webpack_manifest_file)
            webpack_manifest_file
          else
            phoenix_cache_manifest_file
          end
        )
      manifest =
        if File.exist?(manifest_file)
          JSON.parse(File.read(manifest_file))
        else
          if Jekyll.env == "production"
            raise "No manifest file found for asset #{path.inspect}"
          end
          {}
        end

      asset_basename = File.basename(path)
      if asset_basename_with_digest = manifest.dig("latest", asset_basename)
        relative_url(path.sub(%r{/[^/]+\z}, "/#{asset_basename_with_digest}"))
      elsif asset_path_with_digest = manifest[path]
        relative_url(asset_path_with_digest)
      else
        relative_url(path)
      end
    end
  end
end

Liquid::Template.register_filter(ArchiDep::RelativeAssetUrlFilter)
