class LinkedList

  attr_reader :head
  attr_reader :tail

  def initialize(copy_from = nil, copy_fun = nil)
    super()
    @head = nil
    @tail = nil

    if copy_from
      copy_from.each do |item|
        contents = item.contents
        contents = copy_fun.call(contents) if copy_fun
        add(contents)
      end
    end

  end

  def add_after(el, contents)
    add_between(el, el.next, contents)
  end

  def add_before(el, contents)
    add_between(el.prev, el, contents)
  end

  # adds at the end
  def add(contents)
    add_between(@tail, nil, contents)
  end

  # adds at the beginning
  def insert(contents)
    add_between(nil, @head, contents)
  end

  def each
    return unless block_given?
    item = @head
    until item.nil?
      # cache next value in case the item's deleted
      next_el = item.next
      yield item
      item = next_el
    end
  end

  def delete(item)
    if item.list
      if @head === item
        @head = item.next
      else
        item.prev.next = item.next
      end
      if @tail === item
        @tail = item.prev
      else
        item.next.prev = item.prev
      end
      item.list = nil
      item.next = nil
      item.prev = nil
    end
    item.contents
  end

  private

  def add_between(e_prev, e_next, contents)

    if contents.is_a?(LinkedListItem)
      item = contents
      raise "Attempting to add a list item that is already attached to a list" if item.list
      item.list = self
      item.next = e_next
      item.prev = e_prev
    else
      item = LinkedListItem.new(contents, self, e_next, e_prev)
    end

    if e_prev.nil?
      @head = item
    else
      e_prev.next = item
    end

    if e_next.nil?
      @tail = item
    else
      e_next.prev = item
    end

  end

end

class LinkedListItem

  attr_accessor :next
  attr_accessor :prev
  attr_accessor :list
  attr_accessor :contents

  def initialize(contents, list, next_item, prev_item)
    super()
    @list = list
    @next = next_item
    @prev = prev_item
    @contents = contents
  end

  def add_after(contents)
    @list.add_after(self, contents)
  end

  def add_before(contents)
    @list.add_before(self, contents)
  end

  def delete
    list.delete(self)
  end

end