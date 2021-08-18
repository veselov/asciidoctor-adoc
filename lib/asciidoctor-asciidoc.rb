# coding: utf-8

require 'asciidoctor/converter'
require 'asciidoctor-asciidoc/conv-node'
require 'asciidoctor-asciidoc/unescape'

class AsciiDoctorAsciiDocConverter < Asciidoctor::Converter::Base

  MY_BACKEND = "asciidoc"
  MY_FILETYPE = "asciidoc"
  MY_EXTENSION = ".adoc"

  ATTR_ID = "id"
  ATTR_ROLE = "role"
  ATTR_TITLE = "title"
  ATTR_STYLE = "style"
  ATTR_WINDOW = "window"
  ATTR_LANGUAGE = "language"
  ATTR_OPTS = "opts"
  ATTR_DOC_FILE = "docfile"
  ATTR_DOC_TITLE = "doctitle"
  ATTR_DOC_TYPE = "doctype"
  ATTR_ICONS_DIR = "iconsdir"
  ATTR_IMAGES_DIR = "imagesdir"
  ATTR_NAME = "name"
  ATTR_TEXT_LABEL = "textlabel"
  ATTR_COL_COUNT = "colcount"
  ATTR_ROW_COUNT = "rowcount"
  ATTR_TABLE_PC_WIDTH = "tablepcwidth"
  ATTR_SEPARATOR = "separator"
  ATTR_VALIGN = "valign"
  ATTR_HALIGN = "halign"

  TBL_STYLE_HEADER = "h"

  STYLE_ARABIC = "arabic"

  HALIGN_LEFT = "left"
  HALIGN_RIGHT = "right"
  HALIGN_CENTER = "center"

  TYPE_ASCIIDOC = :asciidoc
  TYPE_NONE = :none
  TYPE_EMPHASIS = :emphasis
  TYPE_HEADER = :header
  TYPE_LITERAL = :literal
  TYPE_MONOSPACE = :monospaced
  TYPE_STRONG = :strong
  TYPE_SINGLE = :single
  TYPE_DOUBLE = :double

  VALIGN_TOP = "top"
  VALIGN_BOTTOM = "bottom"
  VALIGN_CENTER = "middle"

  CFG_NO_LF = :no_new_line
  CFG_COLLAPSE = :collapse
  CFG_CONTENT = :content
  CFG_DELIMITER = :delimiter
  CFG_DEFAULT_ATTR = :default_attr
  CFG_STYLE = :style

  OPT_INCLUDE_EMPTY = :include_empty
  OPT_FOR_BLOCK = :for_block

  PARAGRAPH_CONFIG = {
    CFG_COLLAPSE => { ATTR_STYLE => 1, ATTR_TITLE => 0},
    CFG_CONTENT => -> (node) { node.content },
    CFG_DELIMITER => "===="
  }

  LISTING_CONFIG = PARAGRAPH_CONFIG.merge(
    {
      CFG_COLLAPSE => PARAGRAPH_CONFIG[CFG_COLLAPSE].merge({ATTR_LANGUAGE=>2}),
      CFG_DELIMITER => "----"
    })

  ADMONITION_CONFIG = PARAGRAPH_CONFIG.merge(
    {
       CFG_COLLAPSE => PARAGRAPH_CONFIG[CFG_COLLAPSE].merge({
             ATTR_STYLE=>0,
             ATTR_NAME=>0,
             ATTR_TEXT_LABEL=>0 # name and text label are not documented, so
             # I assume it's OK to throw them out...
           }),
       CFG_CONTENT => -> (node) { %(#{node.attr(ATTR_STYLE)}: #{node.content}) }
    })

  TABLE_CONFIG = PARAGRAPH_CONFIG.merge(
    {
      CFG_COLLAPSE => PARAGRAPH_CONFIG[CFG_COLLAPSE].merge(
        {
          ATTR_STYLE=>0,
          ATTR_COL_COUNT=>0,
          ATTR_ROW_COUNT=>0,
          ATTR_TABLE_PC_WIDTH=>0,
        }),
    })

  ROLE_BARE = "bare"

  RX_NUM = /^[1-9][0-9]*$/

  EmDashCharRefRx = /&#8212;(?:&#8203;)?/

  LF = Asciidoctor::LF

  ANCHOR_ATTRIBUTES = [ATTR_ID, ATTR_ROLE, ATTR_WINDOW, ATTR_OPTS].to_set

  # https://docs.asciidoctor.org/asciidoc/latest/attributes/document-attributes-reference/
  INTRINSIC_DOC_ATTRIBUTES = %w(
    backend basebackend docdate docdatetime docdir docfile
    docfilesuffix docname doctime docyear embedded filetype
    htmlsyntax localdate localdatetime localtime localyear
    outdir outfile outfilesuffix safe-mode-level safe-mode-name
    safe-mode-unsafe safe-mode-safe safe-mode-server safe-mode-secure user-home
    asciidoctor asciidoctor-version authorcount
  ).to_set
  # last line in INTRINSIC_DOC_ATTRIBUTES contains undocumented attributes

  DEFAULT_DOC_ATTRIBUTES = {
    "attribute-missing" => "skip",
    "attribute-undefined" => "drop-line",
    "appendix-caption" => "Appendix",
    "appendix-refsig" => "Appendix",
    "caution-caption" => "Caution",
    "chapter-refsig" => "Chapter",
    "example-caption" => "Example",
    "figure-caption" => "Figure",
    "important-caption" => "Important",
    "last-update-label" => "Last updated",
    "note-caption" => "Note",
    "part-refsig" => "Part",
    "section-refsig" => "Section",
    "table-caption" => "Table",
    "tip-caption" => "Tip",
    "toc-title" => "Table of Contents",
    "untitled-label" => "Untitled",
    "version-label" => "Version",
    "warning-caption" => "Warning",
    "doctype" => "article",
    "prewrap" => "",
    "sectids" => "",
    "toc-placement" => "auto", # undocumented
    "notitle" => "", # incorrectly documented
    "max-include-depth" => 64,
    "max-attribute-value-size" => 4096,
    "linkcss" => "", # incorrectly documented
    "stylesdir" => "."
  }

  register_for MY_BACKEND.to_sym

  def initialize(backend, opts = {})
    @backend = backend
    init_backend_traits basebackend: MY_BACKEND, filetype: MY_FILETYPE, outfilesuffix: MY_EXTENSION
    @config = []
    @current_node = nil
  end

  def convert(node, transform = node.node_name, opts = nil)
    new_node = AsciiDoctorAsciiDocNode.new(parent: @current_node, node: node, transform: transform)
    old_node = @current_node
    @current_node.add_child(new_node) if @current_node
    @current_node = new_node
    begin
      return super
    ensure
      @current_node = old_node if old_node
    end
  end

  def convert_document(node)

    push_config({})

    doctype = node.doctype

    dynamic_exclusions = %W(
      backend-#{MY_BACKEND}-doctype-#{doctype}
      doctype-#{doctype}
      backend-#{MY_BACKEND}
      filetype-#{MY_FILETYPE}
      basebackend-#{MY_BACKEND}-doctype-#{doctype}
      basebackend-#{MY_BACKEND}
    ).to_set

    title = unescape(node.title)

    result = []
    result << %(= #{title}) unless title.nil?
    node.attributes.each do |k,v|
      skip = -> {
        INTRINSIC_DOC_ATTRIBUTES.include?(k) ||
          dynamic_exclusions.include?(k) ||
          DEFAULT_DOC_ATTRIBUTES[k] == v ||
          (k == ATTR_DOC_TITLE && v == title) ||
          (k == ATTR_ICONS_DIR && v == default_icons_dir(node))
      }
      result << %(:#{k}: #{v}) unless skip.call
    end
    result << ''

    result << node.content
    result.join LF

  end

  alias convert_embedded convert_document

  def convert_section(node)

    result=''
    unless node.title.nil?
      (0..node.level).each { result << '=' }
      result << %( #{node.title}#{LF}#{LF})
    end

    result << node.content

  end

  def convert_block node
    out = my_paragraph_header(node, PARAGRAPH_CONFIG)
    out << %(#{node.style}: ) unless node.style.nil?
    out << %(#{unescape node.content}#{LF}#{LF})
  end

  def convert_list(node)

    @current_node.is_list = true

    push_config({CFG_NO_LF=>true})

    cfg = PARAGRAPH_CONFIG

    numeric = true
    contents=''
    node.items.each do |li|

      # this is likely unnecessary...
      (sub, first_child) = @current_node.next_child { my_mixed_content(li) }
      contents << li.marker << " " unless first_child&.is_list
      contents << sub

      numeric = false if li.marker != "."
    end

    # if the list is numeric, we need to re-declare default attributes
    if numeric
      # TODO: this is probably more complicated than this - the "default"
      # style probably depends on the nesting...
      cfg = cfg.merge({
                        CFG_DEFAULT_ATTR=>{
                          ATTR_STYLE => STYLE_ARABIC
                        }
                      })
    end

    out = my_paragraph_header(node, cfg)
    if out == ''
      fore = @current_node.prev_sibling
      if fore && (fore.is_list)
        out << %(//-#{LF})
      end
    end
    out << contents

    pop_config

    out

  end

  def convert_admonition(node)
    my_convert_paragraph(node, ADMONITION_CONFIG)
  end

  def convert_audio node
    'TODO audio'
  end

  def convert_colist node
    'TODO colist'
  end

  def convert_dlist node

    out = my_paragraph_header(node, PARAGRAPH_CONFIG)

    push_config({CFG_NO_LF=>true})

    node.items.each do |li|
      out << unescape(li[0][0].text) << '::' << LF
      out << my_mixed_content(li[1])
    end

    pop_config

    out
  end

  def convert_example node
    'TODO example'
  end

  def convert_floating_title node
    'TODO floating_title'
  end

  def convert_listing node
    my_convert_paragraph(node, LISTING_CONFIG)
  end

  def convert_literal(node)
    %(`$#{node.text}`)
  end

  def convert_stem node
    'TODO stem'
  end

  alias convert_olist convert_list

  def convert_open node
    'TODO open'
  end

  def convert_page_break node
    'TODO page_break'
  end

  def convert_paragraph node

    my_convert_paragraph(node, PARAGRAPH_CONFIG)

  end

  def convert_pass node
    "TODO pass"
  end

  # preamble is just a regular paragraph, the only
  # thing special about it is its location
  alias convert_preamble convert_paragraph

  def convert_quote node
    'TODO quote'
  end

  def convert_thematic_break node
    %(''')
  end

  def convert_sidebar node
    'TODO sidebar'
  end

  def convert_table(node)

    # TODO: We can get rid of "format" attribute by changing
    # the separator, but why bother?
    out = my_paragraph_header(node, TABLE_CONFIG)
    out << %(|===#{LF})

    node.rows.head.each { |row| out << my_table_row(node, row, TBL_STYLE_HEADER) }
    node.rows.body.each { |row| out << my_table_row(node, row) }
    # TODO: footer rows are of style "header", right?
    node.rows.foot.each { |row| out << my_table_row(node, row, TBL_STYLE_HEADER) }

    out << %(|===#{LF})

  end

  def convert_toc node
    ''
  end

  alias convert_ulist convert_list

  def convert_verse node
    'TODO verse'
  end

  def convert_video node
    'TODO video'
  end

  def convert_inline_anchor node
    title = choose node.text, node.attr(ATTR_TITLE), node.attr(1)
    attrs = node.attributes.clone.keep_if { |k| ANCHOR_ATTRIBUTES.include? k }

    target = node.target

    if attrs.length == 1 && attrs[ATTR_ROLE] == ROLE_BARE && target == title
      # bare link
      return target
    end

    attrs[1] = title || ''

    if target == "#"
      target = File.basename(node.document.attr(ATTR_DOC_FILE))
    end

    out = %(#{node.type}:#{target})
    out << write_attributes(attrs, {:include_empty=>true})

  end

  def convert_inline_break node
    %(#{node.text} +)
  end

  def convert_inline_button node
    'TODO inline_button'
  end

  def convert_inline_callout node
    'TODO inline_callout'
  end

  def convert_inline_footnote node
    'TODO inline_footnote'
  end

  def convert_inline_image node
    'TODO inline_image'
  end

  def convert_inline_indexterm node
    'TODO inline_indexterm'
  end

  def convert_inline_kbd node
    'TODO inline_kbd'
  end

  def convert_inline_menu node
    'TODO inline_menu'
  end

  def convert_inline_quoted node

    text = unescape(node.text)

    # if implicit style matches the style here, just return the text.
    # this is used for table cells.
    if get_config(CFG_STYLE) == node.type
      return text
    end

    case node.type
    when TYPE_EMPHASIS # called "highlight" in docs
      %(##{text}#)
    when TYPE_STRONG # called "bold" in docs
      %(**#{text}**)
    when TYPE_MONOSPACE
      %(``#{text}``)
    when TYPE_LITERAL
      %(`+#{text}+`)
    when TYPE_SINGLE
      %('`#{text}`')
    when TYPE_DOUBLE
      %("`#{text}`")
    when TYPE_NONE
      text
    else
      raise "Unknown inline type #{node.type}"
    end
  end

  private

  def write_title(title)
    return %(.#{title}#{LF}) if title
    ''
  end

  def default_icons_dir node
    images_dir = node.attributes[ATTR_IMAGES_DIR]
    return './images/icons' if images_dir.nil? || "" == images_dir
    "#{images_dir}/icons"
  end

  def choose(*multiple)
    r = multiple.select { |p| !p.nil?}
    return nil unless r.length > 0
    r[0]
  end

  # collapse_map is a hash that maps positional attributes
  # to named attributes. AsciiDoctor duplicates named attributes
  # from positional ones, leaving both in place, but only when
  # positional attributes are recognized. We need to remove
  # named attributes (key) if the positional attribute (value) is
  # present. Special value 0 indicates that the attribute should be ignored at all.
  def write_attributes(attrs, opts={}, config = {})

    out = ''

    list = []

    collapse = config[CFG_COLLAPSE]
    collapse = {} unless collapse

    defaults = config[CFG_DEFAULT_ATTR]
    defaults = {} unless defaults

    unless attrs.nil?

      attrs = attrs.clone

      # deal with ID and roles, those are quite special.
      attr1 = attrs[1]
      attr1 = '' if attr1.nil?
      id = attrs[ATTR_ID]
      unless id.nil?
        attr1 << %(##{id})
        attrs.delete(ATTR_ID)
      end
      roles = attrs[ATTR_ROLE]
      unless roles.nil?
        roles.split.each do |role|
          attr1 << %(.#{role})
        end
        attrs.delete(ATTR_ROLE)
      end

      # deal with options
      attrs.clone.each do |attr, val|
        attrs.delete(attr) if val.nil?
        next if attr.is_a?(Numeric)
        if attr.end_with?("-option") && val == ""
          attr1 << %(%#{attr[0..-8]})
          attrs.delete(attr)
        end
      end

      attrs[1] = attr1 unless attr1 == ''

      # if this returns true, the attribute should be thrown out.
      collapsed = -> (key) {
        return false unless collapse.key?(key)
        pos = collapse[key]
        return true if pos == 0
        attrs.key?(pos)
      }

      # if this returns true, the attr/value pair should be thrown out
      default = -> (key, val) {
        if key.is_a?(Numeric)

          return false if key == 1 && val == attr1

          # we have to first find the real attr key
          collapse.each do |c_key, c_value|
            if c_value == key
              key = c_key
              break
            end
          end

          if key.is_a?(Numeric)
            raise %(Positional key #{key} with value #{val} does not translate into named attribute!)
          end

        end

        return defaults.key?(key) && defaults[key] == val

      }

      named = []

      attrs.each do |key,val|
        next if key.is_a?(Symbol)
        next if default.call(key,val)
        if key.is_a?(Numeric)
          list[key - 1] = val.nil? ? '' : val
        else
          named.push %(#{key}="#{val}") unless collapsed.call(key)
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
      opts[OPT_INCLUDE_EMPTY] ? "[]" : ""
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
      out << LF if opts[OPT_FOR_BLOCK]
    end

    out

  end

  def my_paragraph_header(node, config)

    title = write_title(node.title)
    attrs = write_attributes(node.attributes, {OPT_FOR_BLOCK=>true}, config)

    # it's possible to not add LFs in certain cases, but for readability
    # it's just simpler to add an LF any time there is a sibling.
    need_lf = !@current_node.prev_sibling.nil?

    # is that true? This means no starting LF if there are no siblings...
    need_lf = false if need_lf.nil?

    need_lf = need_lf ? LF : ''

    %(#{need_lf}#{title}#{attrs})
  end

  def my_convert_paragraph(node, config)

    if node.blocks.nil? || node.blocks.empty?
      content = unescape(config[CFG_CONTENT].call(node))
    else
      push_config({CFG_NO_LF=>true})
      content = %(#{config[CFG_DELIMITER]}#{LF}#{node.content}#{config[CFG_DELIMITER]}#{LF})
      pop_config
    end

    %(#{my_paragraph_header(node, config)}#{content})
  end

  def my_table_row(node, row, style="")

    # there isn't really a good way to reconstruct how the cells
    # were arranged. Because we force-set the header/footer style,
    # we'll just use a cell/line output

    # TODO: Support CSV/DSV/TSV formats

    separator = node.attributes[ATTR_SEPARATOR]
    separator = '|' if separator.nil?

    out = ''

    col_out = []

    (0..row.length-1).each do |i|

      col_def = node.columns[i]
      cell = row[i]
      # check for span
      col_span = cell.colspan ? cell.colspan : 1
      row_span = cell.rowspan ? cell.rowspan : 1

      out_cell = {
        :out => '',
        :spans => false,
        :duplicates => 1
      }

      col_out.push(out_cell)

      out_cell[:out] << col_span.to_s if col_span > 1
      out_cell[:out] << '.' << row_span.to_s if row_span > 1
      unless out == ''
        out_cell[:out] << '+'
        out_cell[:spans] = true
      end

      # horizontal alignment
      def_attr = col_def.attributes
      cell_attr = cell.attributes

      if def_attr[ATTR_HALIGN] != (attr_val = cell_attr[ATTR_HALIGN])
        case attr_val
        when HALIGN_LEFT then out_cell[:out] << '<'
        when HALIGN_RIGHT then out_cell[:out] << '>'
        when HALIGN_CENTER then out_cell[:out] << '^'
        else raise "Unknown horizontal alignment #{attr_val}"
        end
      end

      if def_attr[ATTR_VALIGN] != (attr_val = cell_attr[ATTR_VALIGN])
        case attr_val
        when VALIGN_TOP then out_cell[:out] << '.<'
        when VALIGN_BOTTOM then out_cell[:out] << '.>'
        when VALIGN_CENTER then out_cell[:out] << '.^'
        else raise "Unknown vertical alignment #{attr_val}"
        end
      end

      get_style = -> (s) { s.nil? ? :none : s }

      declared_style = nil
      if get_style.call(col_def.style) != (attr_val = get_style.call(cell.style))

        case attr_val
        when TYPE_ASCIIDOC then out_cell[:out] << 'a'
        when TYPE_NONE then out_cell[:out] << 'd'
        when TYPE_EMPHASIS then out_cell[:out] << 'e'
        when TYPE_HEADER then out_cell[:out] << 'h'
        when TYPE_LITERAL then out_cell[:out] << 'l'
        when TYPE_MONOSPACE then out_cell[:out] << 'm'
        when TYPE_STRONG then out_cell[:out] << 's'
        else raise "Unknown style #{attr_val}"
        end

        declared_style = attr_val

      elsif style != ''

        out_cell[:out] << style

      end

      push_config({CFG_STYLE=>declared_style}) unless declared_style.nil?
      content = cell.content
      # we can get a string, or an array for table cells.
      # I believe the array is the list of paragraphs, if there is ever more
      # than one element.
      out_cell[:out] << separator
      if content.is_a?(Array)
        out_cell[:out] << content.join(%(#{LF}#{LF}))
      else
        out_cell[:out] << content
      end
      pop_config unless declared_style.nil?

      # we have no idea how the cells were formatted in the original
      # document, but it's safe to add an EOL after each cell
      # will prevent overly long lines at least.
      out_cell[:out] << LF

    end

    out = ''

    print_cell = -> (cell) do
      return if cell.nil?
      out << cell[:duplicates].to_s << '*' if cell[:duplicates] > 1
      out << cell[:out]
    end

    prev = nil
    col_out.each do |cell|

      begin

        next if prev.nil? || prev[:spans] || cell[:spans]

        if prev[:out] == cell[:out]
          # ugh, the cell has probably been multiplied
          cell = nil
          prev[:duplicates] += 1
        end

      ensure
        unless cell.nil?
          print_cell.call(prev)
          prev = cell
        end
      end

    end

    print_cell.call(prev)

    out

  end

  def my_mixed_content(node)

    out = ''
    if node.text
      text = unescape(node.text)
      out << unescape(node.text) << LF
      @current_node.add_text_child(text)
    end

    out << node.content

  end

  def push_config(obj)

    if @config.length == 0
      @config = [obj]
      return
    end

    @config.push(@config.last.merge(obj))

  end

  def get_config(sym)
    @config.last[sym]
  end

  def pop_config
    @config.pop
  end

  # taken from manify in
  # https://github.com/asciidoctor/asciidoctor/blob/master/lib/asciidoctor/converter/manpage.rb
  # Undo conversions done by AsciiDoctor according to:
  # https://docs.asciidoctor.org/asciidoc/latest/subs/special-characters/#table-special
  # https://docs.asciidoctor.org/asciidoc/latest/subs/replacements
  def unescape(str)
    return nil if str.nil?
    Unescape.unescape(str)
  end

end
