module ArchiDep
  module Filters
    def collapse_whitespace(text)
      text.gsub(/\s+/, " ")
    end
  end
end

Liquid::Template.register_filter(ArchiDep::Filters)
