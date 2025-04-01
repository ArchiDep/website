module Jekyll
  class NoteTagBlock < Liquid::Block

    Syntax = /(#{Liquid::QuotedFragment}+)?/

    def initialize(tag_name, markup, tokens)
        @attributes = {}

        @attributes['class'] = '';

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
      %|<div class="#{@attributes['class']}">
        #{context.registers[:site].find_converter_instance(
        Jekyll::Converters::Markdown
      ).convert(text)}
      </div>|
    end

  end
end

Liquid::Template.register_tag('note', Jekyll::NoteTagBlock)
