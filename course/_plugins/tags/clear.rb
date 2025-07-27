module Jekyll
  class ClearTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      %|<div style="clear: both;"></div>|
    end
  end
end

Liquid::Template.register_tag('clear', Jekyll::ClearTag)
