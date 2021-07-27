
class AsciiDoctorAsciiDocNode

  attr_reader :parent
  attr_reader :children
  attr_reader :node
  attr_reader :transform

  attr_accessor :is_list

  def initialize(parent, node, transform)
    super()
    @parent = parent
    @node = node
    @transform = transform
    @children = []
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

end