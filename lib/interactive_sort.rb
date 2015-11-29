# coding: utf-8

require "interactive_sort/question"
require "interactive_sort/pokemon-data"
require "interactive_sort/heapsort"
require "interactive_sort/version"
require "thor"

module InteractiveSort
  class Start < Thor
    class_option :"shuffle", :type => :boolean, :default => true,
       :desc => "Shuffle before sort"
    class_option :"list-file", :type => :string,
       :desc => "List to be sorted"

    option :prompt, :type => :string,
           :desc => "Ask for..."
    desc "heapsort", "Do heapsort"
    def heapsort()
      list = []
      list_file = options[:"list-file"]
      if list_file
        list = list_loader(list_file)
      else
        puts "ポケモンのソートを行います。"
        list = PokemonList.interactive_build_list
      end
      if list.empty?
        fail "List is empty."
      end

      if options[:shuffle]
        list.shuffle!
      end

      prompt = options[:prompt]
      prompt ||= "好きなの"
      prompt = "## 一番#{prompt}を選びなさい"

      init = list.dup

      list.extend HeapSort
      list.heap_sort!(prompt)

      list.reverse!
      InteractiveSort::print_result(list)

    rescue Question::Quit
      InteractiveSort::save_heap_state(prompt, init, list)
      exit 0
    rescue RuntimeError => e
      $stderr.puts "#{File.basename($0)}: error: #{e.to_s}"
      exit 1
    end

    desc "bucketsort", "Do bucketsort"
    def bucketsort()
      raise NotImplementedError, "Sorry, bucket sort is not implemented yet."
    end

    no_commands do
      def list_loader(list)
        File.open(list_file, "r") do |fp|
          data = fp.readlines
          if data[0] =~ /^---/
            list = YAML.load(data.join("\n"))
            if !list.is_a?(Array)
              fail "YAML contents must be an array."
            end
          else
            list = data
          end
        end
      end
    end
  end
  
  class CLI < Thor
    desc "start SUBCOMMAND ...ARGS", "Start sort from begin"
    subcommand "start", Start

    desc "continue", "Continue from the saved state"
    def continue(state_file)
      data = YAML.load(File.read(state_file))

      mode = data["mode"]
      init = data["init"]

      case mode
      when "heapsort"
        begin
          list = init.dup
          list.extend HeapSort
          list.answers = data["answers"]
          prompt = data["prompt"]
          prompt ||= "## 一番好きなのを選んでください"

          list.heap_sort!(prompt)

          list.reverse!
          InteractiveSort::print_result(list)

        rescue Question::Quit
          InteractiveSort::save_heap_state(prompt, init, list)
          exit 0
        end
      else
        fail "Invalid mode #{mode.inspect} used."
      end
    rescue SystemCallError => e
      $stderr.puts "#{File.basename($0)}: error: #{e.to_s}"
      exit 1
    rescue RuntimeError => e
      $stderr.puts "#{File.basename($0)}: error: #{e.to_s}"
      exit 1
    end
  end

  def self.print_result(list)
    print "## 結果\n\n"

    if list.empty?
      "  0. {List has gone!}"
      return
    end

    na = (Math.log(list.size) / Math.log(10.0)).to_i + 1
    list.each_with_index do |x, i|
      puts "%*d. %s" % [na > 3 ? 3 : na, i + 1, x]
    end
  end

  def self.save_heap_state(prompt, init, list)
    if Question.yesno?("Save state?")
      data = {
        "mode" => "heapsort",
        "init" => init,
        "answers" => list.answers,
        "prompt" => prompt
      }.to_yaml

      while true
        begin
          f = Question.ask_file_for_write("Location?")
          break unless f || f =~ /^\s*$/
          File.open(f, "w") do |fp|
            fp.print data
          end
          break
        rescue SystemCallError => e
          $stderr.puts "#{File.basename($0)}: error: #{e.to_s}"
          retry
        end
      end
    end
  end
end

