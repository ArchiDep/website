module ArchiDep
  class Generator < Jekyll::Generator
    def generate(site)
      progress_done = 0
      progress_due = 0
      progress_next = 0
      site.posts.docs.each do |post|
        done_chapter = post.data['done']
        if done_chapter != nil
          m = /^(\d+).(\d+)$/.match(done_chapter)
          if m != nil
            progress_done = Integer(m[1]) * 100 + Integer(m[2])
          end
        end

        due_chapter = post.data['due']
        if due_chapter != nil
          m = /^(\d+).(\d+)$/.match(due_chapter)
          if m != nil
            progress_due = Integer(m[1]) * 100 + Integer(m[2])
          end
        end

        next_chapter = post.data['next']
        if next_chapter != nil
          m = /^(\d+).(\d+)$/.match(next_chapter)
          if m != nil
            progress_next = Integer(m[1]) * 100 + Integer(m[2])
          end
        end
      end

      site.collections['matter'].docs.each do |item|
        m = /^(\d+)-(\d+)-(.+)\.([^.]+)$/.match(item.basename_without_ext)
        if m
          section = Integer(m[1])
          section_chapter = Integer(m[2])
          slug = m[3]
          course_type = m[4]
          item.data['section'] = section
          item.data['section_chapter'] = section_chapter

          progress_value = section * 100 + section_chapter
          item.data['progress_value'] = progress_value
          item.data['progress_done'] = progress_done >= progress_value
          item.data['progress_due'] = progress_done && progress_due >= progress_value
          item.data['progress_next'] = progress_done && progress_next >= progress_value
          item.data['progress_future'] = progress_value > progress_done && progress_value > progress_due && progress_value > progress_next

          item.data['permalink'] = "/course/#{section}.#{section_chapter}/#{slug}/"
          item.data['course_type'] = course_type
          item.data['layout'] = course_type
          item.data['toc'] = course_type == 'exercise' || course_type == 'subject'
        else
          throw %/Invalid filename format for item: "#{item.basename}"/
        end
      end

      sections = site.data['course']['sections']
      sections.each_with_index do |section,i|
        # Attach the items in section to the section
        section['items'] = site.collections['matter'].docs.select{ |item| item.data['section'] == i + 1 }

        progress_value = (i + 1) * 100
        section['progress_done'] = progress_done >= progress_value
      end
    end
  end
end

Jekyll::Hooks.register :documents, :pre_render do |doc, payload|
  return unless /\.md$/.match(doc.basename)

  # make some local variables for convenience
  site = doc.site
  liquid_options = site.config["liquid"]

  # create a template object
  template = site.liquid_renderer.file(doc.path).parse(doc.content)

  # the render method expects this information
  info = {
    :registers        => { :site => site, :page => payload['page'] },
    :strict_filters   => liquid_options["strict_filters"],
    :strict_variables => liquid_options["strict_variables"],
  }

  # render the content into a new property
  doc.data['raw_markdown'] = template.render!(payload, info)
end
