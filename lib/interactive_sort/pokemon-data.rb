#!/bin/ruby
# coding: utf-8

if $0 == __FILE__
  require 'bundler'
  Bundler.setup
end

require 'yaml'
require 'interactive_sort/question'

module InteractiveSort
  module PokemonList
    class Error < RuntimeError
      def to_s
        @what
      end

      attr_accessor :what
    end

    class NoSuchPokemon < Error
      BASE = "No such pokémon"
      def initialize(x)
        if x.is_a?(Numeric)
          self.what = BASE + " numbered: #{x}"
        else
          self.what = BASE + ": #{x}"
        end
      end
    end

    odata = File.open(File.join(File.dirname(__FILE__), "pokemon-data.yml"),
                      "r") do |fp|
      fp.read
    end

    POKEMON_DATA = Hash[*YAML.load(odata).map { |x|
                          h = x.each_pair.map { |k, v|
                            [k.to_sym, v]
                          }.flatten(1)
                          Hash[*h]
                        }.each_with_index.map { |x, i|
                          [i + 1, x]
                        }.flatten(1)]

    NAMES = Hash[*POKEMON_DATA.map { |k, v| [v[:name], k] }.flatten(1)]

    def self.builder_base(opt, &block)
      if opt.respond_to?(:each)
        opt.each do |m|
          i = m.to_i
          k = POKEMON_DATA.key?(i)
          if k || NAMES.key?(m)
            if !k
              i = NAMES[m]
            end
            d = POKEMON_DATA[i]
            block.call(d, true)
          else
            fail NoSuchPokemon, m
          end
        end
      else
        POKEMON_DATA.each do |k, v|
          block.call(v, false)
        end
      end
      nil
    end

    def self.build_gender_diff_list(old_list, opt)
      old_list ||= Array.new
      builder_base(opt) do |d, v| 
        if d[:gender_diff]
          f = old_list.find_index(d[:name])
          old_list.delete(d[:name])
          old_list.insert(f, d[:name] + "♀")
          old_list.insert(f, d[:name] + "♂")
        elsif v
          $stderr.puts "#{File.basename($0)}: warning: Pokémon" +
                       " #{d[:name]} does not have gender difference."
        end
      end
    end

    def self.build_mega_list(old_list, opt)
      old_list ||= Array.new
      builder_base(opt) do |d, v|
        txt = []
        if d[:mega]
          if d[:mega].respond_to?(:each)
            d[:mega].each do |type|
              txt << "メガシンカ#{type}"
            end
          else
            txt << "メガシンカ"
          end
        end
        if d[:primordial]
          txt << "ゲンシカイキ"
        end
        if !txt.empty?
          fo = old_list.find_index(d[:name] + "♂")
          fe = old_list.find_index(d[:name] + "♀")
          fo ||= -1
          fe ||= -1
          fo = (fo > fe ? fo : fe)
          if fo > 0
            f = fo + 1
          else
            f = old_list.find_index(d[:name])
            f += 1 if f >= 0
          end
          txt.reverse_each do |t| 
            old_list.insert(f, d[:name] + " (#{t})")
          end
        elsif v
          $stderr.puts "#{File.basename($0)}: warning: Pokémon" +
                       " #{d[:name]} can not Mega Evolve or Primal Reverse."
        end
      end
    end

    def self.build_forme_list(old_list, opt)
      old_list ||= Array.new
      builder_base(opt) do |d, v|
        if d[:forme]
          if d[:gender_diff]
            fail NotImplementedError, "Currently, Pokemons which has gender differences does not have forme differences in the games. But not if we include anime variances. Please fix."
          end
          f = old_list.find_index(d[:name])
          old_list.delete(d[:name])
          d[:forme].reverse_each do |t|
            old_list.insert(f, d[:name] + " (#{t})")
          end
        elsif v
          $stderr.puts "#{File.basename($0)}: warning: Pokémon" +
                       " #{d[:name]} does not have forme variations."
        end
      end
    end

    def self.build_list(opt = {gender_diff: false,
                               mega: false,
                               forme: false,
                               excludes: []})
      gd = opt[:gender_diff]
      mg = opt[:mega]
      fm = opt[:forme]
      ex = opt[:excludes]
      
      gd ||= false
      mg ||= false
      fm ||= false
      ex ||= []

      list = NAMES.keys
      ex.each do |x|
        if x.is_a?(Integer) && POKEMON_DATA.key?(x)
          x = POKEMON_DATA[x][:name]
        end
        list.delete(x)
      end
      
      if gd
        build_gender_diff_list(list, gd)
      end

      if mg
        build_mega_list(list, mg)
      end

      if fm
        build_forme_list(list, fm)
      end
      list
    end

    class InteractiveCommands < Thor
      desc "quit", "Abort building the list"
      def quit
        raise Question::Quit
      end
    end

    class LoopQuestionEnd < RuntimeError
    end

    class ListEditCommands < Thor
      desc "list", "Print current list"
      def list
        @@list.each do |x|
          if @@fmt.respond_to?(:call)
            puts @@fmt.call(x)
          else
            puts @@fmt % x
          end
        end
      end

      desc "exit", "Exit the current list edit"
      def exit
        raise LoopQuestionEnd
      end

      desc "quit", "Abort building the list"
      def quit
        raise Question::Quit
      end

      def self.list=(x)
        @@list = x
      end

      def self.fmt=(x)
        @@fmt = x
      end
    end

    def self.interactive_build_list_intern(prompt, filter, yes_fmt, no_fmt, opt = {})
      hint = opt[:hint]
      custom_selections = opt[:custom_selections]
      all_pokemons = opt[:all_pokemons]
      all_pokemons ||= POKEMON_DATA.keys

      qlist_base = [
        "全て入れる", :all,
        "一部を除いて入れる", :all_exclude_some,
        "少しだけ入れる", :include_some,
        "入れない", :none
      ]
      if custom_selections.respond_to?(:reverse_each)
        custom_selections.reverse_each do |k, v|
          qlist_base.insert(4, v) if v
          qlist_base.insert(4, k)
        end
      end
      qlist = Hash[*qlist_base]

      list = []
      all_list = all_pokemons.map do |i|
        d = POKEMON_DATA[i]
        filter.call(d) if d
      end.compact

      p1 = "## #{prompt}を質問しますか?"
      if hint
        p1 << "\n\n   ヒント: #{hint}"
      end

      formatter = lambda do |format, pokemon|
        if format.respond_to?(:call)
          format.call(pokemon)
        elsif format.respond_to?(:%)
          format % pokemon
        else
          raise ArgumentError
        end
      end

      begin
        list.clear
        r = Question.ask(p1, qlist.keys, thor: InteractiveCommands)
        m = qlist[r]
        case m
        when :all, :all_exclude_some
          list = all_list.dup
        when :none, :include_some
          # nop
        else
          list = all_pokemons.map do |i|
            d = POKEMON_DATA[i]
            filter.call(d, m) if d
          end.compact
        end
        list.each do |pokemon|
          puts formatter.call(yes_fmt, pokemon)
        end
        if [:all, :none].all? { |x| x != m }
          begin
            begin
              ListEditCommands.list = list
              ListEditCommands.fmt = yes_fmt
              r = Question.ask(<<EOF.chomp, all_list, thor: ListEditCommands, hide: true)
## 個別に除外もしくは追加したいポケモンを選んでください

   ヒント: 終了するには exit と入力します。
EOF
              if list.find_index(r)
                next unless Question.yesno?("#{r} を除外しますか?")
                list.delete(r)
                puts formatter.call(no_fmt, r)
              else
                next unless Question.yesno?("#{r} を追加しますか?")
                list << r
                puts formatter.call(yes_fmt, r)
              end
              list.map! do |x|
                NAMES[x]
              end
              list.sort!
              list.map! do |x|
                POKEMON_DATA[x][:name]
              end
            end while true
          rescue LoopQuestionEnd
          end
          list.each do |pokemon|
            puts formatter.call(yes_fmt, pokemon)
          end
        end
        break if Question.yesno?("よろしいですか?")
      end while true
      list
    end

    def self.interactive_build_gender_diff_list
      interactive_build_list_intern(
        "性別による姿の違い",
        Proc.new { |data, key|
          d = nil
          if key == :include_major
            d = data[:name] if data[:gender_diff] == "major"
          else
            d = data[:name] if data[:gender_diff]
          end
          d
        },
        "\x1b[32m%s\x1b[0mの性別による姿の違いを質問\x1b[31mします\x1b[0m.",
        "\x1b[32m%s\x1b[0mの性別による姿の違いを質問\x1b[31mしません\x1b[0m.",
        :hint => "このリストには細かい違いしかないポケモンも含まれています",
        :custom_selections => {"大きな違いがあるポケモンだけを入れる" => :include_major}
      )
    end

    def self.interactive_build_mega_list
      yes_fmt = Proc.new do |x|
        base = "\x1b[32m%s\x1b[0mの%sを質問\x1b[31mします\x1b[0m."
        if POKEMON_DATA[NAMES[x]][:mega]
          s = "メガシンカ"
        else
          s = "ゲンシカイキ"
        end
        base % [x, s]
      end
      no_fmt = Proc.new do |x|
        base = "\x1b[32m%s\x1b[0mの%sを質問\x1b[31mしません\x1b[0m."
        if POKEMON_DATA[NAMES[x]][:mega]
          s = "メガシンカ"
        else
          s = "ゲンシカイキ"
        end
        base % [x, s]
      end
      interactive_build_list_intern(
        "メガシンカとゲンシカイキ",
        Proc.new { |data, key|
          d = nil
          case key
          when :mega_only
            d = data[:name] if data[:mega]
          when :primordial_only
            d = data[:name] if data[:primordial]
          else
            d = data[:name] if data[:mega] || data[:primordial]
          end
          d
        },
        yes_fmt, no_fmt,
        :custom_selections => {
          "メガシンカのみ入れる" => :mega_only,
          "ゲンシカイキのみ入れる" => :primordial_only
        }
      )
    end

    def self.interactive_build_forme_list
      interactive_build_list_intern(
        "フォルム違い",
        Proc.new { |data, key|
          data[:name] if data.key?(:forme)
        },
        "\x1b[32m%s\x1b[0mのフォルム違いを質問\x1b[31mします\x1b[0m.",
        "\x1b[32m%s\x1b[0mのフォルム違いを質問\x1b[31mしません\x1b[0m.",
      )
    end

    def self.interactive_build_list
      gen_list = interactive_build_gender_diff_list
      mega_list = interactive_build_mega_list
      forme_list = interactive_build_forme_list

      build_list(gender_diff: gen_list, mega: mega_list, forme: forme_list)
    rescue Question::Quit
      puts "中止します..."
      []
    end
  end
end

if $0 == __FILE__
#  l = InteractiveSort::PokemonList.
#      build_list(
#        gender_diff: true,
#        mega: true,
#        forme: true,
#      )
#  puts l.to_yaml
#  puts l.size

  l = InteractiveSort::PokemonList.
      interactive_build_list
  puts l.to_yaml
end
