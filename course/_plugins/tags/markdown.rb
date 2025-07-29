module ArchiDep
  class MarkdownTagBlock < Liquid::Block
    Syntax = /(#{Liquid::QuotedFragment}+)?/

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["type"] = ""

      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'loop_directory' plugin.")
      end

      super
    end

    def render(context)
      text = super

      %|<div class="markdown">
      #{
        context.registers[:site].find_converter_instance(
          Jekyll::Converters::Markdown
        ).convert(text)
      }
      </div>|
    end
  end
end

Liquid::Template.register_tag("markdown", ArchiDep::MarkdownTagBlock)
