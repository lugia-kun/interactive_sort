# coding: utf-8

if $0 == __FILE__
  require 'bundler'
  Bundler.setup
end

require 'readline'
require 'thor'

module InteractiveSort
  module Question
    @@readline_prompt = "> <!-- --> "

    class Quit < RuntimeError
      def to_s
        "Aborted"
      end
    end

    def self.ask_file_for_read(prompt)
      Readline.completion_proc = Readline::FILENAME_COMPLETION_PROC
      loop do
        ret = Readline.readline("#{prompt}> ", false)
        next if ret =~ /^\s*$/
        ret.sub!(/^\s*(.*?)\s*$/, "\\1")
        if ret =~ /^"(.*)"$/
          ret = $1
        end
        if !File.exist?(ret)
          $stderr.puts "#{File.basename($0)}: error: #{ret}: No such file or directory"
          next
        end
        break ret
      end
    end

    def self.ask_file_for_write(prompt, ask_overwrite = true)
      loop do
        Readline.completion_proc = Readline::FILENAME_COMPLETION_PROC
        ret = Readline.readline("#{prompt}> ", false)
        next if ret =~ /^\s*$/
        ret.sub!(/^\s*(.*?)\s*$/, "\\1")
        if ret =~ /^"(.*)"$/
          ret = $1
        end
        if File.exist?(ret)
          break ret if yesno?("Overwrite \"#{ret}\"?")
          next
        end
        break ret
      end
    end

    def self.yesno?(prompt)
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

    def self.ask(prompt, selections, hsh = {thor: nil, output: $stdout})
      thor_class = hsh[:thor]
      output = hsh[:output]
      output ||= $stdout
      @select = hsh[:select]
      hide = hsh[:hide]
      hide ||= false

      ss = selections.size
      is_thor_class = thor_class.respond_to?(:commands) &&
                      thor_class.commands.respond_to?(:each_pair) &&
                      thor_class.respond_to?(:start)

      if !is_thor_class
        if ss == 0
          fail "No selections and/or Thor class specified."
        end
        thor_class = Class.new(Thor)
      else
        thor_class = Class.new(thor_class)
      end

      select_proc = Proc.new do |x|
        nx = x[0]
        range = (1..selections.size)
        begin
          raise ArgumentError unless nx
          n = nx.to_i
          raise ArgumentError unless range.include?(n)
          @select = selections[n - 1]
        rescue ArgumentError
          puts "Invalid number selected. Must be #{range}"
          raise
        end
      end

      thor_class.class_eval do
        # override basename.
        def self.basename
          ""
        end
      end

      if ss > 0 &&
         !thor_class.commands.key?("select") &&
         !thor_class.instance_methods.any? { |x| x == :select }
        thor_class.class_eval do
          @@select_proc = select_proc

          desc "select NUMBER...", "Select the option. Number should be #{1..selections.size}"
          def select(*number)
            begin
              @@select_proc.call(number)
            rescue ArgumentError
              help("select")
            end
          end
        end
      end

      if ss > 0
        n = (Math.log(selections.size) / Math.log(10.0)).to_i + 1
      else
        n = 0
      end
      output.print "\n%s\n\n" % prompt
      messages = selections.each_with_index.map do |x, i|
        "%*d. %s" % [n > 3 ? n : 3, i + 1, x]
      end
      if ss > 0
        messages.map! do |m|
          output.print "%s\n" % m unless hide
          m.sub(/^\s*/, "")
        end
        output.print "\n" unless hide
      end

      # TODO: complete subcommands and flags
      if thor_class.superclass != Thor
        thor_class.superclass.commands.each_pair do |k, v|
          messages << v.usage.slice(/^\s*(\S+)/)
        end
      end
      thor_class.commands.each_pair do |k, v|
        messages << v.usage.slice(/^\s*(\S+)/)
      end
      messages << 'help'
      Readline.completion_proc = Proc.new do |a|
        messages.select { |m| m.match(a.to_s) }
      end
      loop do
        if selections.any? { |x| x == @select }
          begin
            break @select
          ensure
            @select = nil
          end
        end
        ret = Readline.readline(@@readline_prompt, true)
        raise EOFError unless ret
        # TODO: process escapes and quotes.
        argv = ret.split(/ +/)
        argv.delete("")
        argv.compact!
        begin
          if argv[0] =~ /^\s*\d+/
            select_proc.call(argv)
            next
          end
        rescue ArgumentError
          next
        end
        thor_class.start(argv)
      end
    end
  end
end

if $0 == __FILE__ then
  include InteractiveSort

  class TestClass < Thor
    desc "quit", "Quit the program."
    def quit
      puts "Exitting..."
      exit 0
    end
  end

  a = []
  a.extend Question
  p Question.ask("## Choose prefer", ["a", "b", "c"], thor: TestClass)
  p Question.ask("## Choose prefer", ["a", "b", "c"], thor: TestClass)

  class SpecialCommands < Thor
    @@list = []

    desc "add STRING", "Add to list"
    def add(string)
      @@list << string
    end

    desc "remove STRING", "Remove from list"
    def remove(string)
      @@list.delete(string)
    end

    desc "list", "List contents"
    def list()
      @@list.each do |l|
        puts " * #{l}"
      end
    end

    desc "quit", "Quit the program"
    def quit
      puts "Exitting"
      exit 0
    end
  end
  p Question.ask("## Choose prefer", [], thor: SpecialCommands)
end
