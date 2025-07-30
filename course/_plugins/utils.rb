module ArchiDep
  module Utils
    def self.render_icon(name, context, options = {})
      icon_class = options[:class] || "size-6"
      Liquid::Template.parse(%|{% include icons/#{name}.html class="#{icon_class}" %}|).render({}, { registers: context.registers })
    end

    def self.render_markdown(text, context)
      page = context.registers[:page]
      text_with_links = ArchiDep::Utils.replace_markdown_link_references(text, page)
      context.registers[:site].find_converter_instance(
        Jekyll::Converters::Markdown
      ).convert(text_with_links)
    end

    def self.replace_markdown_link_references(text, page)
      refs = self.parse_markdown_link_references(page)

      unless refs.empty?
        refs.reduce(text) do |content, link_reference|
          content.gsub(
            /\]\[#{link_reference[:reference]}\]/,
            "](#{link_reference[:url]})"
          )
        end
      else
        text
      end
    end

    def self.parse_markdown_link_references(page)
      content = page.respond_to?(:content) ? page.content : page["content"]

      content
        .split("\n")
        .reverse
        .map { |line| line.strip }
        .reject { |line| line.empty? }
        .take_while { |line| line.match?(/\A\[[^\]]+\]: ?.+\z/) }
        .map do |line|
          m = line.match(/\A\[([^\]]+)\]: ?(.+)\z/)
          { reference: m[1], url: m[2] }
        end
        .reverse
    end
  end
end
