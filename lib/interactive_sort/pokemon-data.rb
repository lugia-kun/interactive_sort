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
    class PokemonData < Struct.new(:name, :mega, :primordial, :gender, :forme)
      def to_s
        g = ""
        if self.gender
          if self.gender == :female
            g << "♀"
          elsif self.gender == :male
            g << "♂"
          else
            g << "?"
          end
        end
        m = []
        if self.mega
          t = "メガシンカ"
          if self.mega != true
            t << self.mega
          end
          m << t
        end
        if self.primordial
          t = "ゲンシカイキ"
          if self.primordial != true
            t << self.primordial
          end
          m << t
        end
        if self.forme
          m << self.forme.to_s
        end
        if m.empty?
          "%s%s" % [self.name.to_s, g]
        else
          "%s%s (%s)" % [self.name.to_s, g, m.join(", ")]
        end
      end
    end

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
        if d[:gender_diff].respond_to?(:include?)
          old_list.map! do |m|
            next m unless m.name == d[:name]

            if m.forme
              next m unless d[:gender_diff].include?(m.forme)
            end

            n = m.dup
            m.gender = :male
            n.gender = :female
            [m, n]
          end.flatten!

        elsif d[:gender_diff]
          old_list.map! do |m|
            next m unless m.name == d[:name]

            n = m.dup
            m.gender = :male
            n.gender = :female
            [m, n]
          end.flatten!

        elsif v
          $stderr.puts "#{File.basename($0)}: warning: Pokémon" +
                       " #{d[:name]} does not have gender difference."
        end
      end
    end

    def self.build_mega_list(old_list, opt)
      old_list ||= Array.new
      proc = Proc.new do |data, key, assign|
        if data[key].respond_to?(:map)
          old_list.map! do |m|
            next m unless m.name == data[:name]

            t = m.dup
            t.forme = nil
            t.gender = nil
            t.mega = nil
            t.primordial = nil

            [
              m,
              data[key].map do |type|
                tt = t.dup
                tm = tt.method(assign)
                tm.call(type)
                tt
              end
            ]
          end.flatten!
          true
        elsif data[key]
          old_list.map! do |m|
            next m unless m.name == data[:name]

            t = m.dup
            t.forme = nil
            t.gender = nil
            t.mega = nil
            t.primordial = nil

            tm = t.method(assign)
            tm.call(true)

            [m, t]
          end.flatten!
          true
        else
          false
        end
      end
      builder_base(opt) do |d, v|
        has_mega = proc.call(d, :mega, :"mega=")
        has_prim = proc.call(d, :primordial, :"primordial=")
        unless has_mega || has_prim
          $stderr.puts "#{File.basename($0)}: warning: Pokémon" +
                       " #{d[:name]} can not Mega Evolve or Primal Reverse."
        end
      end
    end

    def self.build_forme_list(old_list, opt)
      old_list ||= Array.new
      builder_base(opt) do |d, v|
        if d[:forme]
          forme_with_gender_diff = d[:forme] &
                                   if d[:gender_diff]
                                     d[:gender_diff]
                                   else
                                     []
                                   end
          rem = d[:forme] - forme_with_gender_diff

          old_list.map! do |m|
            next m unless m.name == d[:name]
            next m if m.mega
            next m if m.primordial

            o = m.dup
            o.gender = nil

            a = forme_with_gender_diff.map do |t|
              tt = m.dup
              tt.forme = t
              tt
            end
            b = rem.map do |t|
              tt = o.dup
              tt.forme = t
              tt
            end
            [a, b]
          end.flatten!
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
      list.map! do |t|
        PokemonData.new(t)
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

      mega_comp = lambda do |x, y|
        xcom = x.respond_to?(:<=>)
        ycom = y.respond_to?(:<=>)
        if xcom && ycom
          x <=> y
        elsif xcom
          -1
        elsif ycom
          1
        else
          0
        end
      end

      list.sort! do |x, y|
        next 0 if x == y

        ix = NAMES[x.name]
        iy = NAMES[y.name]
        next ix <=> iy if ix != iy

        if x.gender && y.gender
          if x.gender == y.gender
            next 0
          end
          case x.gender
          when :male # y.gender == :female assumed.
            next -1
          when :female
            next 1
          end
        end

        xm = x.mega || x.primordial
        ym = y.mega || y.primordial

        unless x.forme || y.forme
          next -1 if x.gender && ym
          next  1 if y.gender && xm

          next  1 if xm and !ym
          next -1 if ym and !xm
        end

        xm = xm && x.forme.nil?
        ym = ym && y.forme.nil?
        next  1 if xm and !ym
        next -1 if ym and !xm

        if x.mega && y.mega
          next mega_comp.call(x.mega, y.mega)
        end
        if x.primordial && y.primordial
          next mega_com.call(x.primordial, y.primordial)
        end

        if x.forme && y.forme
          d = POKEMON_DATA[ix]
          ixf = d[:forme].index(x.forme)
          iyf = d[:forme].index(y.forme)
          next ixf <=> iyf if ixf && iyf
          next  1 if ixf
          next -1 if iyf
          next  0
        end

        fail "Convparing #{x} and #{y}"
      end

      list.uniq
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
