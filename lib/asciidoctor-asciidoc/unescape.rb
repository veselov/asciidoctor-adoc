
require 'asciidoctor-asciidoc/linked-list'

class Unescape

  FEED_MORE = :more
  FEED_NO_MATCH = :no_match
  FEED_DONE = :done

  class Context

    attr_accessor :last_char
    attr_accessor :buffer_len
    attr_accessor :buffer
    attr_accessor :curve_quote_index
    attr_accessor :pos
    attr_accessor :str
    attr_accessor :out

    def initialize(str)
      super()
      @str = str
      @curve_quote_index = []
      @len = str.length
      @pos = 0
      @out = ''
      reset
    end

    def reset
      @buffer = ''
      @buffer_len = 0
    end

    def has_next_char?
      @pos < @len
    end

    def next_char
      @str[@pos]
    end

    def prev_char
      @str[@pos-2]
    end

    def advance
      @last_char = next_char
      @buffer << @last_char
      @pos+=1
      @buffer_len += 1
    end

    def back_track(pattern)
      @pos -= buffer_len
      return @str[@pos..@pos + pattern.len - 1] if pattern.len > 0
      ''
    end

    def forward(pattern)
      @pos += pattern.len
    end

    def remainder
      str[pos..-1]
    end

  end

  class Pattern

    attr_reader :len

    def initialize(context)
      super()
      @ctx = context
      reset
    end

    def reset
      @done = false
      @len = 0
      self
    end

    def is_done?(ended)
      @done
    end

  end

  class StringPattern < Pattern

    def initialize(context, pattern, replacement)
      super(context)
      @pattern = pattern
      @max_len = pattern.length
      @replacement = replacement
    end

    def feed

      return FEED_NO_MATCH if @ctx.last_char != @pattern[@len]
      @len += 1
      if @len == @max_len
        @done = true
        return FEED_DONE
      end
      FEED_MORE

    end

    def produce(piece)
      @replacement
    end

  end

  class CurveQuoteStart < StringPattern

    def initialize(context)
      super(context, "&#8216;", %('`))
    end

    def produce(piece)
      @ctx.curve_quote_index << { :pos=>@ctx.out.length, :start=>true}
      super
    end

  end

  class CurveQuoteEnd < StringPattern

    def initialize(context)
      super(context,  "&#8217;", %(`'))
    end

    def produce(piece)
      @ctx.curve_quote_index << { :pos=>@ctx.out.length, :start=>false}
      super
    end

  end

  class SpecialGobbler < Pattern

    # these are the character that we care about escaping
    CHAR_SET = %w[* _ ` # ~ ^].to_set
    VOID_SET = /[[:alpha:][:digit:]:;}_]/

    def initialize(context)
      super
    end

    def feed

      accept_char = CHAR_SET.include?(@ctx.last_char)
      unless accept_char
        return FEED_NO_MATCH unless @len > 0
        @done = true
        return FEED_DONE
      end

      # we don't need to escape if:
      # - the character is singular
      # - the character directly follows:
      # -- a colon, semicolon, or closing curly bracket
      # -- a letter, number, or underscore
      # -- there is a space from this mark to the next mark.
      # - but we need to make exceptions for first character being '*' because of lists

      gobble = -> () do
        @len+=1
        return FEED_MORE
      end

      # if we have accumulated something already continue doing so no matter what
      return gobble.call if @len > 0

      # list exception - gobble up chars if we are consuming from the
      # start of text
      return gobble.call if @ctx.buffer_len == @ctx.pos

      return gobble.call if @ctx.has_next_char? && @ctx.next_char == @ctx.last_char

      # here we are guaranteed that there is a character before ours
      return FEED_NO_MATCH if @ctx.prev_char.match?(VOID_SET)

      # if there are no more control characters, no need to escape
      next_char = @ctx.remainder.index(@ctx.last_char)
      return FEED_NO_MATCH if next_char.nil?
      next_ws = @ctx.remainder.index(/[[:space:]]/)
      return FEED_NO_MATCH if !next_ws.nil? && next_ws < next_char

      gobble.call

    end

    def is_done?(ended)
      (ended && @len > 0) || super
    end

    def produce(piece)
      %(pass:[#{piece}])
    end

  end

  def self.unescape(str)

    # Note - it's generally OK for us to leave the &#xxxx; sequences in the
    # Asciidoc, because they are re-rendered as is. We try our best to resolve
    # these reference, but if we are unsure on how to, we can leave them in.

    # $TODO I'm sure there is more to this than that.
    quote_release = Set[
      ',', ';', '"', '.', '?', '!', ' ', '\n'
    ]

    ctx = Context.new(str)

    all = LinkedList.new
    # https://docs.asciidoctor.org/asciidoc/latest/subs/special-characters/
    all.add(StringPattern.new(ctx, "&lt;", "<"))
    all.add(StringPattern.new(ctx, "&gt;", ">"))
    all.add(StringPattern.new(ctx, "&amp;", "&"))
    # https://docs.asciidoctor.org/asciidoc/latest/subs/quotes/
    all.add(StringPattern.new(ctx, "&#8220;", %("`)))
    all.add(StringPattern.new(ctx, "&#8221;", %(`")))
    all.add(CurveQuoteEnd.new(ctx))
    all.add(CurveQuoteStart.new(ctx))
    # https://docs.asciidoctor.org/asciidoc/latest/subs/replacements/
    all.add(StringPattern.new(ctx, "&#169;", "(C)"))
    all.add(StringPattern.new(ctx, "&#174;", "(R)"))
    all.add(StringPattern.new(ctx, "&#8482;", "(TM)"))
    all.add(StringPattern.new(ctx, "&#8212;", "--"))
    all.add(StringPattern.new(ctx, "&#8201;&#8212;&#8201;", " -- "))
    all.add(StringPattern.new(ctx, "&#8230;", "..."))
    all.add(StringPattern.new(ctx, "&#8594;", "->"))
    all.add(StringPattern.new(ctx, "&#8658;", "=>"))
    all.add(StringPattern.new(ctx, "&#8592;", "<-"))
    all.add(StringPattern.new(ctx, "&#8656;", "<="))

    all.add(SpecialGobbler.new(ctx))

    active = nil

    reset = -> do
      ctx.reset
      active = LinkedList.new(all, -> (p) do
        p.reset
      end)
    end

    reset.call

    while true do

      ended = !ctx.has_next_char?
      ctx.advance unless ended

      done = nil
      has_more = false

      active.each do |item|

        pattern = item.contents

        record_done = Proc.new do
          if done.nil?
            done = item
          else
            if done.len > item.len
              active.delete(item)
            else
              active.delete(done)
              done = item
            end
          end
        end

        if ended

          record_done.call if pattern.is_done?(true)

        else

          if pattern.is_done?(false)
            record_done.call
          else
            feed = pattern.feed
            if feed == FEED_NO_MATCH
              active.delete(item)
              next
            end
          end

          # it's either "more" or "done" now
          record_done.call if feed == FEED_DONE
          has_more = true if feed == FEED_MORE

        end

      end

      # if we found some more patterns to match
      # we need to continue
      next if has_more

      if done.nil?

        # there is nothing done, so we just flush the
        # buffer out
        ctx.out << ctx.buffer

      else

        pattern = done.contents
        piece = ctx.back_track(pattern)
        ctx.out << pattern.produce(piece)
        ctx.forward(pattern)

      end

      reset.call

      break unless ctx.has_next_char?

    end

    out2 = ''
    last_pos = 0

    # deal with apostrophes
    has_start = false
    (0..ctx.curve_quote_index.length-1).each do |idx|
      item = ctx.curve_quote_index[idx]

      item_pos = item[:pos]
      out2 << ctx.out[last_pos..item_pos-1] unless item_pos <= 0
      last_pos = item_pos

      if item[:start]
        out2 << ctx.out[last_pos..last_pos+1]
        has_start = true
      else
        # ok, then this is the end quote,
        # or it's in the middle of something
        # or a simple one
        # We need to replace it with the single apostrophe
        # if we are not ending the quote. We are not ending the quote
        # if there is an end to it later, but before any new quote starts.
        replace = !has_start
        unless replace
          replace = ctx.curve_quote_index-1 != idx && ctx.curve_quote_index[idx+1][:start]
        end

        if replace
          out2 << "'"
        else
          has_start = false
          out2 << ctx.out[last_pos..last_pos+1]
        end

      end

      last_pos += 2

    end

    return ctx.out if last_pos == 0
    out2 << ctx.out[last_pos..-1]

  end

end