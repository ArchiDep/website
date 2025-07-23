module ArchiDep
  class Generator < Jekyll::Generator
    def generate(site)
      matter_docs = site.collections['matter'].docs

      progress_docs = site.collections['progress'].docs
      done_chapters = progress_docs.flat_map{ |doc| doc.data['done'] || [] }
      due_chapters = progress_docs.flat_map{ |doc| doc.data['due'] || [] }.reject{ |ch| done_chapters.include?(ch) }
      next_chapters = progress_docs.flat_map{ |doc| doc.data['next'] || [] }.reject{ |ch| done_chapters.include?(ch) || due_chapters.include?(ch) }

      matter_docs.each do |item|
        m = /^([1-9])(\d+)-(.+)\.([^.]+)$/.match(item.basename_without_ext)
        throw %/Invalid filename format for item: "#{item.basename}"/ unless m

        section = Integer(m[1])
        section_chapter = Integer(m[2])
        slug = m[3]
        course_type = m[4]
        item.data['section'] = section
        item.data['section_chapter'] = section_chapter

        chapter_num = section * 100 + section_chapter
        item.data['num'] = chapter_num
        item.data['progress'] = case chapter_num
        when *done_chapters
          'done'
        when *due_chapters
          'due'
        when *next_chapters
          'next'
        else
          'future'
        end

        base_permalink = "/course/#{section}.#{section_chapter}/#{slug}/"
        item.data['permalink'] = if course_type == 'slides'
          "#{base_permalink}/slides/"
        else
          base_permalink
        end

        item.data['course_type'] = course_type
        item.data['layout'] = course_type
        item.data['toc'] = course_type == 'exercise' || course_type == 'subject'
      end

      matter_docs.each do |doc|
        if doc.data['course_type'] == 'subject'
          num = doc.data['num']
          slides_doc = matter_docs.filter{ |item| item.data['num'] == num && item.data['course_type'] == 'slides' }
          if slides_doc.length >= 2
            raise "Multiple slides documents found for subject #{num}"
          elsif slides_doc.length == 1
            doc.data['slides'] = slides_doc[0]
            slides_doc[0].data['subject'] = doc
          end
        end
      end

      sections = site.data['course']['sections']
      sections.each_with_index do |section,i|
        # Attach the items in section to the section
        section_docs = matter_docs.select{ |item| item.data['section'] == i + 1 }
        section['items'] = section_docs.reject{ |item| item.data['course_type'] == 'slides' && matter_docs.any?{ |subject| subject.data['course_type'] == 'subject' && subject.data['num'] == item.data['num'] } }

        section_num = (i + 1) * 100
        section['num'] = section_num
        section['progress'] = case section_num
        when *done_chapters
          'done'
        end
      end

      home_page_doc = site.pages.find{ |doc| doc.data['layout'] == 'home' }

      last_done = progress_docs.reverse.find{ |doc| doc.data['done'] }&.data&.[]('done') || []
      previous_chapters = matter_docs.select{ |doc| doc.data['course_type'] == 'subject' && last_done.include?(doc.data['num']) }
      home_page_doc.data['previous_chapters'] = previous_chapters

      last_due = progress_docs.reverse.find{ |doc| doc.data['due'] }&.data&.[]('due') || []
      next_due_exercises = matter_docs.select{ |doc| doc.data['course_type'] == 'exercise' && last_due.include?(doc.data['num']) }
      home_page_doc.data['next_due_exercises'] = next_due_exercises

      next_chapter_nums = progress_docs.reverse.find{ |doc| doc.data['next'] }&.data&.[]('next') || []
      next_chapters = matter_docs.select{ |doc| doc.data['subject'] == nil && next_chapter_nums.include?(doc.data['num']) }
      home_page_doc.data['next_chapters'] = next_chapters

      site.pages << JsonPage.new(site, {
        'sections' => site.data['course']['sections'].each_with_index.map do |section,i|
          {
            'title' => section['title'],
            'num' => section['num'],
            'progress' => section['progress'],
            'docs' => section['items'].map{ |item| item.data.merge({"url" => item.url}) }
          }
        end
      })
    end
  end

  class JsonPage < Jekyll::Page
    def initialize(site, data)
      @site = site
      @base = site.source
      @dir  = '/'
      @content = JSON.pretty_generate(data)
      @data = {}

      # All pages have the same filename, so define attributes straight away.
      @basename = 'archidep'
      @ext      = '.json'
      @name     = 'archidep.json'
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
