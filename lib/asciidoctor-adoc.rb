# coding: utf-8

require 'asciidoctor/converter'

class AsciiDoctorADocConverter < Asciidoctor::Converter::Base

  ATTR_ID = "id"
  ATTR_ROLE = "role"
  ATTR_TITLE = "title"
  ATTR_WINDOW = "window"
  ATTR_OPTS = "opts"
  ATTR_DOC_FILE = "docfile"

  ROLE_BARE = "bare"

  RX_NUM = /^[1-9][0-9]*$/

  LF = Asciidoctor::LF

  ANCHOR_ATTRIBUTES = [ATTR_ID, ATTR_ROLE, ATTR_WINDOW, ATTR_OPTS].to_set

  register_for 'adoc'

  def initialize(backend, opts = {})
    super
  end

  def convert (node, transform = node.node_name, opts = nil)

    if transform == 'inline_quoted'; return convert_inline_quoted node
    elsif transform == 'paragraph'; return convert_paragraph node
    elsif transform == 'inline_anchor'; return convert_inline_anchor node
    elsif transform == 'section'; return convert_section node
    elsif transform == 'listing'; return convert_listing node
    elsif transform == 'literal'; return convert_literal node
    elsif transform == 'ulist'; return convert_ulist node
    elsif transform == 'olist'; return convert_olist node
    elsif transform == 'dlist'; return convert_dlist node
    elsif transform == 'admonition'; return convert_admonition node
    elsif transform == 'colist'; return convert_colist node
    elsif transform == 'embedded'; return convert_embedded node
    elsif transform == 'example'; return convert_example node
    elsif transform == 'floating_title'; return convert_floating_title node
    elsif transform == 'image'; return convert_image node
    elsif transform == 'inline_break'; return convert_inline_break node
    elsif transform == 'inline_button'; return convert_inline_button node
    elsif transform == 'inline_callout'; return convert_inline_callout node
    elsif transform == 'inline_footnote'; return convert_inline_footnote node
    elsif transform == 'inline_image'; return convert_inline_image node
    elsif transform == 'inline_indexterm'; return convert_inline_indexterm node
    elsif transform == 'inline_kbd'; return convert_inline_kbd node
    elsif transform == 'inline_menu'; return convert_inline_menu node
    elsif transform == 'open'; return convert_open node
    elsif transform == 'page_break'; return convert_page_break node
    elsif transform == 'preamble'; return convert_preamble node
    elsif transform == 'quote'; return convert_quote node
    elsif transform == 'sidebar'; return convert_sidebar node
    elsif transform == 'stem'; return convert_stem node
    elsif transform == 'table'; return convert_table node
    elsif transform == 'thematic_break'; return convert_thematic_break node
    elsif transform == 'verse'; return convert_verse node
    elsif transform == 'video'; return convert_video node
    elsif transform == 'document'; return convert_document node
    elsif transform == 'toc'; return convert_toc node
    elsif transform == 'pass'; return convert_pass node
    elsif transform == 'audio'; return convert_audio node
    else; raise "Unknown transformation #{transform}"
    end
  end

  def convert_document node

    result = []
    result << %(= #{node.title}) unless node.title.nil?
    node.attributes.each do |k,v|
      result << %(:#{k}:#{v})
    end
    result << ''
    node.blocks.each { |n| result << n.content }
    result.join LF

  end

  def convert_embedded node
    ['', convert_document(node)].join LF
  end

  def convert_section node

    result=''
    unless node.title.nil?
      0..node.level { result << '=' }
      result << %( #{node.title}#{LF}#{LF})
    end

    # sections have no text, right?
    node.blocks.each { |b| result << b.content }

    result

  end

  def convert_block node
    out = ''
    out << %(#{node.style}: ) unless node.style.nil?
    out << %(#{node.content}#{LF}#{LF})
  end

  def convert_list node
    out = ''
    node.items.each do |li|
      out << li.marker << " " << li.text << LF
      out << li.content
    end

    out << LF

  end

  alias convert_admonition convert_block

  def convert_audio node
    'TODO'
  end

  def convert_colist node
    'TODO'
  end

  def convert_dlist node
    'TODO'
  end

  def convert_example node
    'TODO'
  end

  def convert_floating_title node
    'TODO'
  end

  def convert_listing node
    'TODO'
  end

  def convert_literal node
    %(`${#node.text}`)
  end

  def convert_stem node
    'TODO'
  end

  alias convert_olist convert_list

  def convert_open node
    'TODO'
  end

  def convert_page_break node
    'TODO'
  end

  alias convert_paragraph convert_block

  alias convert_pass content_only

  def convert_preamble node
    'TODO'
  end

  def convert_quote node
    'TODO'
  end

  def convert_thematic_break node
    'TODO'
  end

  def convert_sidebar node
    'TODO'
  end

  def convert_table node
    'TODO'
  end

  def convert_toc node
    ''
  end

  alias convert_ulist convert_list

  def convert_verse node
    'TODO'
  end

  def convert_video node
    'TODO'
  end

  def convert_inline_anchor node
    title = choose node.text, node.attr(ATTR_TITLE), node.attr("1")
    attrs = node.attributes.clone.keep_if { |k| ANCHOR_ATTRIBUTES.include? k }

    target = node.target

    if attrs.length == 1 && attrs[ATTR_ROLE] == ROLE_BARE && target == title
      # bare link
      return target
    end

    attrs["1"] = title

    if target == "#"
      target = File.basename(node.document.attr(ATTR_DOC_FILE))
    end

    out = %(#{node.type}:#{target})

    out << write_attributes(attrs, true)

  end

  def convert_inline_break node
    %( +#{LF})
  end

  def convert_inline_button node
    'TODO'
  end

  def convert_inline_callout node
    'TODO'
  end

  def convert_inline_footnote node
    'TODO'
  end

  def convert_inline_image node
    'TODO'
  end

  def convert_inline_indexterm node
    'TODO'
  end

  def convert_inline_kbd node
    'TODO'
  end

  def convert_inline_menu node
    'TODO'
  end

  def convert_inline_quoted node
    'TODO'
  end

  private

  def choose(*multiple)
    r = multiple.select { |p| !p.nil?}
    return nil unless r.length > 0
    r[0]
  end

  def write_attributes(attr, include_empty)

    out = ''

    list = []

    unless attr.nil?

      named = []

      attr.each do |key,val|
        key = key.to_s
        if key =~ RX_NUM
          list[key.to_i - 1] = val.nil? ? '' : val
        else
          named.push %(#{key}="#{val}")
        end
      end

      named.each do |n|
        i = list.index(nil)
        if i.nil?
          list.push(n)
        else
          list[i] = n
        end
      end
    end

    list.pop while !list.nil? && !list.empty? && list[-1].nil?

    if list.nil? || list.empty?
      include_empty ? "[]" : ""
    else
      first = true
      list.each do |item|
        if first
          first = false
          out << '['
        else
          out << ','
        end
        out << (item.nil? ? '' : item.to_s)
      end
      out << ']'
    end
  end


end