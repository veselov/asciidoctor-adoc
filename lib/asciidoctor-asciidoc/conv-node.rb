
class AsciiDoctorAsciiDocNode

  TYPE_NODE = :node
  TYPE_TEXT = :text

  attr_reader :parent
  attr_reader :children
  attr_reader :node
  attr_reader :transform
  attr_reader :text
  attr_reader :type

  # specifies whether the node has a "distinct end",
  # meaning that there is no need to add an LF before
  # starting the new node.
  attr_reader :distinct_end

  attr_accessor :is_list

  def initialize(parent:, node: nil, transform: nil, text: nil)
    super()
    @parent = parent
    @node = node
    @transform = transform
    @text = text
    @distinct_end = false

    if text.nil?
      @children = []
      @type = TYPE_NODE
    else
      @children = nil
      @type = TYPE_TEXT
    end

  end
  def add_child(node)
    @children.push(node)
  end

  def prev_sibling

    return nil unless @parent

    children = parent.children
    prev = nil
    children.each do |child|
      return prev if child === self
      prev = child
    end

    raise "I am not a child of my parent!"

  end

  def next_child

    idx = @children.length
    [yield, idx == @children.length ? nil : @children[idx]]

  end

  def add_text_child(text)

    @children.push(AsciiDoctorAsciiDocNode.new(parent: self, text: text))

  end

  def is_text?
    @type == TYPE_TEXT
  end

end