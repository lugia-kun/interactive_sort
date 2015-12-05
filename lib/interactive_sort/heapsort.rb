# coding: utf-8

if $0 == __FILE__
  require 'bundler'
  Bundler.setup
end


require 'thor'
require 'interactive_sort/question'

module InteractiveSort
  module HeapSort
    def draw_tree(stream, root, last, a = [])
      raise ArgumentError if root < 0
      raise ArgumentError if @heap_factor < 2
      raise ArgumentError if last < 0
      return if root >= last
      return if root >= length
      last = length if last > length
      fst = root * @heap_factor + 1
      lst = fst + @heap_factor - 1
      return if fst >= last
      lst = last - 1 if lst >= last - 1
      t = " ├"
      e = " └"
      stream.puts " #{self[root]}" if a.empty?
      aj = a.join
      (fst...lst).each do |i|
        stream.puts "#{aj}#{t} #{self[i]}"
        draw_tree(stream, i, last, a + [" │"])
      end
      stream.puts "#{aj}#{e} #{self[lst]}"
      draw_tree(stream, lst, last, a + ["  "])
    end

    def draw_dot(stream, root, last, depth = 0)
      raise ArgumentError if root < 0
      raise ArgumentError if @heap_factor < 2
      raise ArgumentError if last < 0
      return if root >= last
      return if root >= length
      last = length if last > length
      fst = root * @heap_factor + 1
      lst = fst + @heap_factor - 1
      return if fst >= last
      lst = last - 1 if lst >= last - 1

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
        draw_dot(stream, i, last, depth + 1)
      end
      if depth == 0
        stream.puts "}"
        puts "Done!"
      end
    end

    class Commands < Thor
      option :from, :desc => "Starting place", :type => :numeric
      option :"from-selection", :desc => "Starting place select by current question options", :type => :numeric
      option :depth, :desc => "Tree depth to write", :type => :numeric
      option :output, :desc => "Output filename", :type => :string
      desc "draw-tree", "Draws current heap tree"
      def draw_tree()
        fac = @@list.heap_factor
        sel = options[:"from-selection"]

        if (1..@@current.size).include?(sel)
          root = @@current[sel - 1]
          root ||= 0
        else
          root = options[:from]
          root ||= 0
        end

        depth = options[:depth]
        depth ||= @@list.heap_last

        last = 1.upto(depth).inject(0) do |i, x|
          r = i + fac ** x
          break @@list.heap_last if r > @@list.heap_last
          r
        end

        fn = options[:output]
        if fn
          if File.exists?(fn)
            return unless Question.yesno?("Overwrite?")
          end
          stream = File.open(options[:output], "w")
        else
          stream = $stdout
        end

        @@list.draw_tree(stream, root, last)

      rescue ArgumentError
        $stderr.puts "No data available."

      rescue RuntimeError
      rescue SystemCallError => e
        $stderr.puts e.to_s
      end

      option :from, :desc => "Starting place", :type => :numeric
      option :"from-selection", :desc => "Starting place select by current question options", :type => :numeric
      option :depth, :desc => "Tree depth to write", :type => :numeric
      option :output, :desc => "Output filename", :type => :string
      desc "draw-dot", "Write DOT language to draw current heap tree"
      def draw_dot()
        fac = @@list.heap_factor

        sel = options[:"from-selection"]
        if (1..@@current.size).include?(sel)
          root = @@current[sel - 1]
          root ||= 0
        else
          root = options[:from]
          root ||= 0
        end

        depth = options[:depth]
        depth ||= @@list.heap_last
        last = 1.upto(depth).inject(0) do |i, x|
          r = i + fac ** x
          break @@list.heap_last if r > @@list.heap_last
          r
        end

        fn = options[:output]
        if fn
          if File.exists?(fn)
            return unless Question.yesno?("Overwrite?")
          end
          stream = File.open(options[:output], "w")
        else
          stream = $stdout
        end

        @@list.draw_dot(stream, root, last)

      rescue ArgumentError
        $stderr.puts "No data available."

      rescue RuntimeError
      rescue SystemCallError => e
        $stderr.puts e.to_s
      end

      desc "confirmed", "Print the list of confirmed items."
      def confirmed
        hl = @@list.heap_last
        ll = @@list.length
        if hl == ll || ll == 0
          print "\n## Nothing confirmed.\n\n"
        else
          print "\n## Confirmed list\n\n"
          is = (Math.log(ll) / Math.log(10)).to_i + 1
          (ll - 1).downto(hl).each_with_index do |i, n|
            print "%*d. %s\n" % [is, n + 1, @@list[i]]
          end
        end
        puts
      end

      desc "quit", "Quit the program"
      def quit
        raise Question::Quit
      end

      @@current = nil
      @@list = nil

      def self.list
        @@list
      end

      def self.list=(l)
        @@list = l
      end

      def self.current
        @@current
      end

      def self.current=(c)
        @@current = c
      end
    end

    # m: heap factor
    # children: n * m + 1 to (n + 1) * m
    # parent:   (n - 1) / m
    def question(parent, last = length)
      fst = parent * @heap_factor + 1
      lst = fst + @heap_factor
      return nil if fst >= last
      lst = last if lst >= last

      children = (fst...lst).to_a
      ss = [parent] + children

      @s_cnt ||= 0
      @s_cnt += children.size
      @q_cnt ||= 0
      @q_cnt += 1

      if @answer
        r = -1
        if @answer == :random
          r = ss.sample
        else
          raise ArgumentError if @answer < 1
          raise ArgumentError if @answer > ss.length
          r = ss[@answer - 1]
        end
        return r
      end
      
      if @answers && @q_cnt <= @answers.size
        a = @answers[@q_cnt - 1]
        return a if ss.find_index(a)
        ret = @answers.slice!(@q_cnt..-1)
        if ret && !ret.empty?
          $stderr.puts "NOTE: Saved answers after Q.#{@q_cnt} were removed."
        end
      end

      ms = ss.map do |x|
        self[x]
      end

      Commands.list = self
      Commands.current = ss

      r = Question.ask(@sort_prompt + " (#{@q_cnt}回目)", ms, thor: Commands)

      i = ms.find_index(r)
      fail "Invalid answer #{r}" unless i

      @answers ||= []
      @answers << ss[i]
      ss[i]
    end
    
    def swap(i, j)
      self[i], self[j] = self[j], self[i]
    end

    def heap_leaf()
      s = length
      pp = (s - 1) / @heap_factor
      loop do
        a = question(pp)
        if a && a != pp
          swap(a, pp)
          heap_up(a)
        end
        break if pp == 0
        pp -= 1
      end
    end

    def heap_up(pp, l = @heap_last)
      loop do
        a = question(pp, l)
        break unless a
        break if a == pp
        swap(a, pp)
        pp = a
      end
    end

    def heap_down()
      (length - 1).downto(1) do |i|
        swap(0, i)
        @heap_last = i
        heap_up(0, i)
      end
    end

    def heap_sort!(sort_prompt)
      return if empty?

      @sort_prompt = sort_prompt
      @heap_factor ||= (Math.log(length) / Math.log(2)).to_i - 1

      raise TypeError, "Factor must be an integer" unless
        @heap_factor.is_a?(Integer)

      @heap_factor = 2 if heap_factor < 2
      @heap_last = length

      @s_cnt = nil
      @q_cnt = nil
      heap_leaf
      heap_down
    end

    attr_reader :q_cnt, :s_cnt, :heap_last
    attr_accessor :heap_factor, :answer, :answers
  end
end

if $0 == __FILE__
  list = ("a".."z").to_a + ["z"]
  #list = list.permutation(2).to_a
  #list.map! do |x|
  #  x.join
  #end
  list.extend InteractiveSort::HeapSort
  list.heap_sort!("## Select which prefer.")
  p list
end
