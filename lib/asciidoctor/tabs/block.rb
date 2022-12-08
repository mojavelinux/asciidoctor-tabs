# frozen_string_literal: true

module Asciidoctor
  module Tabs
    class Block < ::Asciidoctor::Extensions::BlockProcessor
      use_dsl
      on_context :example

      def process parent, reader, attrs
        block = create_block parent, attrs['cloaked-context'], nil, attrs, content_model: :compound
        children = (parse_content block, reader).blocks
        return block unless children.size == 1 && (seed_tabs = children[0]).context == :dlist && seed_tabs.items?
        unless (doc = parent.document).attr? 'filetype', 'html'
          (id = attrs['id']) && (doc.register :refs, [(seed_tabs.id = id), seed_tabs]) unless seed_tabs.id
          (reftext = attrs['reftext']) && (seed_tabs.set_attr 'reftext', reftext) unless seed_tabs.reftext?
          parent << seed_tabs
          return
        end
        tabs_number = doc.counter 'tabs-number'
        tabs_id = attrs['id'] || (generate_id %(tabs #{tabs_number}), doc)
        sync = !(block.option? 'nosync') && ((block.option? 'sync') || (doc.option? 'tabs-sync')) ? ' is-sync' : nil
        parent << (create_html_fragment parent, %(<div id="#{tabs_id}" class="tabs#{sync || ''} is-loading">))
        if (title = attrs['title'])
          parent << (create_html_fragment parent, %(<div class="title">#{parent.apply_subs title}</div>))
        end
        tablist = create_list parent, :ulist
        tablist.role = 'tablist'
        panes = {}
        set_id_on_tab = (doc.backend == 'html5') || (list_item_supports_id? doc)
        seed_tabs.items.each do |labels, content|
          tab_ids = labels.map do |tab|
            tablist << tab
            tab_id = generate_id tab.text, doc, tabs_id
            tab_text_source = tab.instance_variable_get :@text
            set_id_on_tab ? (tab.id = tab_id) : (tab.text = %([[#{tab_id}]]#{tab_text_source}))
            tab.role = 'tab'
            (doc.register :refs, [tab_id, tab]).set_attr 'reftext', tab_text_source
            tab_id
          end
          if content
            tab_blocks = content.text? ?
              [(create_paragraph parent, (content.instance_variable_get :@text), nil, subs: :normal)] : []
            if content.blocks?
              if (block0 = (blocks = content.blocks)[0]).context == :open && blocks.size == 1 && block0.blocks?
                blocks = block0.blocks
              end
              tab_blocks.push(*blocks)
            end
          end
          panes[tab_ids] = tab_blocks || []
        end
        parent << tablist
        parent << (create_html_fragment parent, '<div class="content">')
        panes.each do |tab_ids, blocks|
          attrs = %( id="#{tab_ids[0]}--panel" class="tabpanel" aria-labelledby="#{tab_ids.join ' '}")
          parent << (create_html_fragment parent, %(<div#{attrs}>))
          blocks.each {|it| parent << it }
          parent << (create_html_fragment parent, '</div>')
        end
        parent << (create_html_fragment parent, '</div>')
        create_html_fragment parent, '</div>', 'id' => tabs_id
      end

      private

      def create_html_fragment parent, html, attributes = nil
        create_block parent, :pass, html, attributes
      end

      def generate_id str, doc, base_id = nil
        if base_id
          restore_idprefix = (attrs = doc.attributes)['idprefix']
          attrs['idprefix'] = %(#{base_id}#{attrs['idseparator'] || '_'})
        end
        ::Asciidoctor::Section.generate_id str, doc
      ensure
        restore_idprefix ? (attrs['idprefix'] = restore_idprefix) : (attrs.delete 'idprefix') if base_id
      end

      def list_item_supports_id? doc
        if (converter = doc.converter).instance_variable_defined? :@list_item_supports_id
          converter.instance_variable_get :@list_item_supports_id
        else
          output = (create_list doc, :ulist).tap {|ul| ul << (create_list_item ul).tap {|li| li.id = 'name' } }.convert
          converter.instance_variable_set :@list_item_supports_id, (output.include? ' id="name"')
        end
      end
    end
  end
end
