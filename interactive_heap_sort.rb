# coding: utf-8

module InteractiveHeapSort

  def draw_tree(factor, root, last, a = [])
    raise ArgumentError if root < 0
    raise ArgumentError if factor < 2
    raise ArgumentError if last < 0
    return if root >= last
    return if root >= length
    last = length if last > length
    fst = root * factor + 1
    lst = fst + factor - 1
    return if fst >= last
    lst = last - 2 if lst >= last - 1
    t = " ├"
    e = " └"
    puts self[root] if a.empty?
    (fst...lst).each do |i|
      puts "#{a.join}#{t} #{self[i]}"
      draw_tree(factor, i, last, a + [" │"])
    end
    puts "#{a.join}#{e} #{self[lst]}"
    draw_tree(factor, lst, last, a + ["  "])
  end

  def draw_dot(stream, factor, root, last, depth = 0)
    raise ArgumentError if root < 0
    raise ArgumentError if factor < 2
    raise ArgumentError if last < 0
    return if root >= last
    return if root >= length
    last = length if last > length
    fst = root * factor + 1
    lst = fst + factor - 1
    return if fst >= last
    lst = last - 2 if lst >= last - 1

    if depth == 0
      stream.puts "digraph G {"
      stream.puts "   rankdir = \"LR\";"
      stream.puts "   n#{root} [label=\"#{self[root]}\"];"
    end
    (fst..lst).each do |i|
      stream.puts "   n#{i} [label=\"#{self[i]}\"];"
    end
    (fst..lst).each do |i|
      stream.puts "   n#{root} -> n#{i};"
    end
    (fst..lst).each do |i|
      draw_dot(stream, factor, i, last, depth + 1)
    end
    if depth == 0
      stream.puts "}"
      puts "Done!"
    end
  end

  # m: heap factor
  # children: n * m + 1 to (n + 1) * m
  # parent:   (n - 1) / m

  def swap(i, j)
    self[i], self[j] = self[j], self[i]
  end

  def heap_leaf(m)
    s = length
    pp = (s - 1) / m
    loop do
      a = question(m, pp)
      if a && a != pp
        swap(a, pp)
        heap_up(m, a)
      end
      break if pp == 0
      pp -= 1
    end
  end

  def heap_up(m, pp, l = length)
    loop do
      a = question(m, pp, l)
      break unless a
      break if a == pp
      swap(a, pp)
      pp = a
    end
  end

  def heap_down(m)
    (length - 1).downto(1) do |i|
      swap(0, i)
      heap_up(m, 0, i)
    end
  end

  public
  def heap_sort!(heap_factor = nil, opt = {})
    return if empty?

    if opt.key?(:answer)
      @@answer = opt[:answer]
    end

    heap_factor ||= (Math.log(length) / Math.log(2)).to_i - 1

    if @heap_sort_state && @heap_sort_state.is_a?(Hash)
      @heap_sort_state["init"] = self.dup
    end
    raise TypeError, "Factor must be an integer" unless
      heap_factor.is_a?(Integer)

    heap_factor = 2 if heap_factor < 2

    @q_cnt = nil
    heap_leaf(heap_factor)
    heap_down(heap_factor)
  end

  def heap_sort_state=(stat)
    @heap_sort_state = stat
  end

  def heap_sort_state
    @heap_sort_state
  end

  attr_reader :q_cnt, :s_cnt
end
