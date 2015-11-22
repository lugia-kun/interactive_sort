# coding: utf-8

require 'readline'

module Question
  @@prompt = "## 一番好きなのを選びなさい (%d回目)"
  @@readline_prompt = "> <!-- --> "
  @@answer = nil

  class Quit < RuntimeError
    def to_s
      "Aborted"
    end
  end

  def self.yesno(prompt)
    Readline.completion_proc = proc do |m|
      %w[yes no].select { |x| x.match(m) }
    end
    loop do
      ret = Readline.readline("#{prompt} (yes/no)> ", false)
      break false if ret =~ /^\s*no.*$/
      break true if ret =~ /^\s*yes.*$/
      puts "Please answer 'yes' or 'no'."
    end
  end

  def parse_command(string, name, arguments, &block)
    spa = string.split(/\s+/)
    spa.delete("")
    return false if spa[0] != name
    spa.delete_at 0
    h = Hash.new
    opt = OptionParser.new do |x|
      arguments.each do |n|
        sym = n.sub(/^-*/, "").to_sym
        x.on("#{n}[=VAR]") do |v|
          h[sym] = v
        end
      end
    end
    begin
      opt.parse!(spa)
    rescue OptionParser::ParseError => e
      puts "Error: " + e.to_s
      return true
    end
    block.call(spa, h)
  end

  def question(selections, commands)
    
  end

  def question(factor, parent, l = length)
    raise ArgumentError unless (0..l).cover?(parent)

    fst = parent * factor + 1
    lst = fst + factor
    return nil if fst >= l
    lst = l if lst > l

    children = (fst...lst).to_a
    ss = [parent] + children

    @s_cnt ||= 0
    @s_cnt += children.size
    @q_cnt ||= 0
    @q_cnt += 1    

    if @@answer
      r = -1
      if @@answer == :random
        r = ss.sample
      else
        raise ArgumentError if @@answer < 1
        raise ArgumentError if @@answer > ss.length
        r = ss[@@answer - 1]
      end
      return r
    end    

    if @heap_sort_state &&
       @heap_sort_state.key?("answers") &&
       @q_cnt <= @heap_sort_state["answers"].size
      a = @heap_sort_state["answers"][@q_cnt - 1]
      return a if ss.find_index(a)
      ret = @heap_sort_state["answers"].slice!(@q_cnt..-1)
      if ret && !ret.empty?
        $stderr.puts "NOTE: Saved answers after Q.#{@q_cnt} were removed."
      end
    end
    cnt = 0
    messages = ss.map do |i|
      next nil unless i < length
      cnt += 1
      "%d. %s" % [cnt, self[i]]
    end
    messages.compact!
    puts
    puts @@prompt % @q_cnt
    puts
    messages.each do |m|
      puts " %s" % m
    end
    puts

    messages << "quit"
    messages << "firmed"
    messages << "draw-tree"
    messages << "draw-dot"
    Readline.completion_proc = Proc.new do |a|
      messages.select { |m| m.match(a.to_s) }
    end
    loop do
      buf = Readline.readline(@@readline_prompt, true)
      raise Quit unless buf
      raise Quit if parse_command(buf, "quit", []) { 1 }
      next if parse_command(buf, "firmed", []) do
        if l == length
          puts "## まだ何も確定していませんよ"
        else
          puts
          puts "## 確定済みリスト"
          puts
          (length - 1).downto(l) do |i|
            puts " %d. %s" % [length - i, self[i]]
          end
        end
        true
      end
      next if parse_command(buf, "dump-array", []) do
        self.each_with_index do |x, i|
          puts "%d. %s" % [i, x]
        end
        true
      end
      next if parse_command(buf, "draw-tree", ["-d", "-f"]) do |m, h|
        n = -1
        p h
        if h.key?(:f)
          n = h[:f].to_i - 1
        end
        d = -1
        if h.key?(:d)
          d = h[:d].to_i - 1
        end
        ll = l
        if 0 <= d
          ll = 0.upto(d).inject(0) do |i, j|
            i + factor ** j
          end
        end
        if ll > l
          ll = l
        end
        if 0 <= n && n < ss.size
          draw_tree(factor, ss[n], ll)
        else
          draw_tree(factor, 0, ll)
        end
        true
      end
      next if parse_command(buf, "draw-dot", ["-d", "-f"]) do |fa, h|
        begin
          out = $stdout
          if ! fa.empty?
            if File.exists?(fa[0])
              break true unless yesno("Overwrite \"#{fa[0]}\"?")
            end
            out = File.open(fa[0], "w")
          end
          n = -1
          if h.key?(:f)
            n = h[:f].to_i - 1
          end
          d = -1
          if h.key?(:d)
            d = h[:d].to_i - 1
          end
          ll = l
          if 0 <= d
            ll = 0.upto(d).inject(0) do |i, j|
              i + factor ** j
            end
          end
          if ll > l
            ll = l
          end
          if 0 <= n && n < ss.size
            draw_dot(out, factor, ss[n], ll)
          else
            draw_dot(out, factor, 0, ll)
          end          
        rescue SystemCallError => e
          puts "Error: #{e.to_s}"
        end
        true
      end
      buf.sub!(/^\s*(\d*)\D.*$/, "\\1")
      nbuf = buf.to_i - 1
      if nbuf >= 0 && nbuf < ss.size
        ans = ss[nbuf]
        if @heap_sort_state
          @heap_sort_state["answers"] ||= Array.new
          @heap_sort_state["answers"] << ans
        end
        break ans
      end
    end
  end
end
