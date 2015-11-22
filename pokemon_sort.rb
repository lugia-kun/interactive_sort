#!/bin/ruby
# coding: utf-8

require 'readline'
require 'yaml'
require 'optparse'

$opt = Hash.new
$opt[:shuffle] = true

OptionParser.new do |x|
  x.on("--state-file=FILE", String, "State file") do |f|
    $opt[:state] = YAML.load(File.open(f, "r").read)
  end

  x.on("--max-selections=NUMBER", Integer, "Maximum number of choices to ask you") do |m|
    $opt[:max_sel] = m - 1
  end

  x.on("--[no-]shuffle", "(Don\'t) shuffle the list before sorting") do |x|
    $opt[:shuffle] = x
  end

  x.on("--answer[=NUM]", Integer,
       "Always answer specified value (for debug use)",
       "If number is not specified, answers random number") do |x|
    x ||= :random
    $opt[:answer] = x
  end
end.parse!

module InteractiveHeapSort
  @@prompt = "## 一番好きなのを選びなさい (%d回目)"
  @@readline_prompt = "> <!-- --> "
  @@answer = nil

  class Quit < RuntimeError
    def to_s
      "Aborted"
    end
  end

  def yesno(prompt)
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

  private
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

if $opt.key?(:state)
  @ary = $opt[:state]["init"]
  if $opt[:state]["max_sel"]
    $opt[:max_sel] = $opt[:state]["max_sel"]
  end
else
  file = DATA
  if not ARGV.empty?
    fn = ARGV[0]
    if fn != "-"
      file = File.open(ARGV[0], "r")
    else
      file = $stdin
    end
  end
  @ary = file.read.split(/\s+/).uniq

  @ary.shuffle! if $opt[:shuffle]
  $opt[:state] = Hash.new
  if $opt[:max_sel]
    $opt[:state]["max_sel"] = $opt[:max_sel]
  end
end
raise RuntimeError, "Input is empty" if @ary.empty?

@ary.extend InteractiveHeapSort
begin
  @ary.heap_sort_state = $opt[:state]
  @ary.heap_sort!($opt[:max_sel], $opt)
rescue InteractiveHeapSort::Quit
  yn = proc do |m|
    %w[yes no].select { |x| x.match(m) }
  end
  Readline.completion_proc = yn
  ret = Readline.readline("Save state? (yes/no)> ", false)
  if ret =~ /^\s*y/i
    loop do
      Readline.completion_proc = Readline::FILENAME_COMPLETION_PROC
      fn = Readline.readline("Enter filename> ", false)
      exit 1 unless fn
      fn.sub!(/\s*$/, "")
      if File.exists?(fn)
        next unless @ary.yesno("Overwrite \"#{fn}\"?")
      end
      File.open(fn, "w") do |fp|
        fp.print $opt[:state].to_yaml
      end
      break
    end
  end
  exit 0
end
@ary.reverse!

if $opt.key?(:answer)
  puts "#{@ary.q_cnt} questions performed."
  puts "#{@ary.s_cnt} comperations will be performed if this sort is done programatically."
else
  as = (Math.log(@ary.length - 1) / Math.log(10)).to_i + 1
  puts
  puts "## 結果"
  puts
  @ary.each_with_index do |x, i|
    puts "%*d. %s" % [as, i + 1, x]
  end
end

__END__
---
- name: フシギダネ
- name: フシギソウ
- name: フシギバナ
  mega: yes
  gender_diff: yes
- name: ヒトカゲ
- name: リザード
- name: リザードン
  mega: [X, Y]
- name: ゼニガメ
- name: カメール
- name: カメックス
  mega: yes
- name: キャタピー
- name: トランセル
- name: バタフリー
  gender_diff: yes
- name: ビードル
- name: コクーン
- name: スピアー
  mega: yes
- name: ポッポ
- name: ピジョン
- name: ピジョット
  mega: yes
- name: コラッタ
  gender_diff: yes
- name: ラッタ
  gender_diff: yes
- name: オニスズメ
- name: オニドリル
- name: アーボ
- name: アーボック
- name: ピカチュウ
  gender_diff: yes
- name: ライチュウ
  gender_diff: yes
- name: サンド
- name: サンドパン
- name: ニドラン♀
- name: ニドリーナ
- name: ニドクイン
- name: ニドラン♂
- name: ニドリーノ
- name: ニドキング
- name: ピッピ
- name: ピクシー
- name: ロコン
- name: キュウコン
- name: プリン
- name: プクリン
- name: ズバット
  gender_diff: yes
- name: ゴルバット
  gender_diff: yes
- name: ナゾノクサ
- name: クサイハナ
  gender_diff: yes
- name: ラフレシア
  gender_diff: yes
- name: パラス
- name: パラセクト
- name: コンパン
- name: モルフォン
- name: ディグダ
- name: ダグトリオ
- name: ニャース
- name: ペルシアン
- name: コダック
- name: ゴルダック
- name: マンキー
- name: オコリザル
- name: ガーディ
- name: ウインディ
- name: ニョロモ
- name: ニョロゾ
- name: ニョロボン
- name: ケーシィ
- name: ユンゲラー
  gender_diff: yes
- name: フーディン
  gender_diff: yes
  mega: yes
- name: ワンリキー
- name: ゴーリキー
- name: カイリキー
- name: マダツボミ
- name: ウツドン
- name: ウツボット
- name: メノクラゲ
- name: ドククラゲ
- name: イシツブテ
- name: ゴローン
- name: ゴローニャ
- name: ポニータ
- name: ギャロップ
- name: ヤドン
- name: ヤドラン
  mega: yes
- name: コイル
- name: レアコイル
- name: カモネギ
- name: ドードー
  gender_diff: yes
- name: ドードリオ
  gender_diff: yes
- name: パウワウ
- name: ジュゴン
- name: ベトベター
- name: ベトベトン
- name: シェルダー
- name: パルシェン
- name: ゴース
- name: ゴースト
- name: ゲンガー
  mega: yes
- name: イワーク
- name: スリープ
- name: スリーパー
  gender_diff: yes
- name: クラブ
- name: キングラー
- name: ビリリダマ
- name: マルマイン
- name: タマタマ
- name: ナッシー
- name: カラカラ
- name: ガラガラ
- name: サワムラー
- name: エビワラー
- name: ベロリンガ
- name: ドガース
- name: マタドガス
- name: サイホーン
  gender_diff: yes
- name: サイドン
  gender_diff: yes
- name: ラッキー
- name: モンジャラ
- name: ガルーラ
  mega: yes
- name: タッツー
- name: シードラ
- name: トサキント
  gender_diff: yes
- name: アズマオウ
  gender_diff: yes
- name: ヒトデマン
- name: スターミー
- name: バリヤード
- name: ストライク
- name: ルージュラ
- name: エレブー
- name: ブーバー
- name: カイロス
  mega: yes
- name: ケンタロス
- name: コイキング
  gender_diff: yes
- name: ギャラドス
  mega: yes
  gender_diff: yes
- name: ラプラス
- name: メタモン
- name: イーブイ
- name: シャワーズ
- name: サンダース
- name: ブースター
- name: ポリゴン
- name: オムナイト
- name: オムスター
- name: カブト
- name: カブトプス
- name: プテラ
  mega: yes
- name: カビゴン
- name: フリーザー
- name: サンダー
- name: ファイヤー
- name: ミニリュウ
- name: ハクリュー
- name: カイリュー
- name: ミュウツー
  mega: [X, Y]
- name: ミュウ
- name: チコリータ
- name: ベイリーフ
- name: メガニウム
  gender_diff: yes
- name: ヒノアラシ
- name: マグマラシ
- name: バクフーン
- name: ワニノコ
- name: アリゲイツ
- name: オーダイル
- name: オタチ
- name: オオタチ
- name: ホーホー
- name: ヨルノズク
- name: レディバ
  gender_diff: yes
- name: レディアン
  gender_diff: yes
- name: イトマル
- name: アリアドス
- name: クロバット
- name: チョンチー
- name: ランターン
- name: ピチュー
- name: ピィ
- name: ププリン
- name: トゲピー
- name: トゲチック
- name: ネイティ
- name: ネイティオ
  gender_diff: yes
- name: メリープ
- name: モココ
- name: デンリュウ
  mega: yes
- name: キレイハナ
- name: マリル
- name: マリルリ
- name: ウソッキー
  gender_diff: yes
- name: ニョロトノ
  gender_diff: yes
- name: ハネッコ
- name: ポポッコ
- name: ワタッコ
- name: エイパム
  gender_diff: yes
- name: ヒマナッツ
- name: キマワリ
- name: ヤンヤンマ
- name: ウパー
  gender_diff: yes
- name: ヌオー
  gender_diff: yes
- name: エーフィ
- name: ブラッキー
- name: ヤミカラス
  gender_diff: yes
- name: ヤドキング
- name: ムウマ
- name: アンノーン
  forme: [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, !, ?]
- name: ソーナンス
  gender_diff: yes
- name: キリンリキ
  gender_diff: yes
- name: クヌギダマ
- name: フォレトス
- name: ノコッチ
- name: グライガー
  gender_diff: yes
- name: ハガネール
  gender_diff: yes
  mega: yes
- name: ブルー
- name: グランブル
- name: ハリーセン
- name: ハッサム
  gender_diff: yes
  mega: yes
- name: ツボツボ
- name: ヘラクロス
  gender_diff: yes
  mega: yes
- name: ニューラ
  gender_diff: yes
- name: ヒメグマ
- name: リングマ
  gender_diff: yes
- name: マグマッグ
- name: マグカルゴ
- name: ウリムー
- name: イノムー
  gender_diff: yes
- name: サニーゴ
- name: テッポウオ
- name: オクタン
  gender_diff: yes
- name: デリバード
- name: マンタイン
- name: エアームド
- name: デルビル
- name: ヘルガー
  gender_diff: yes
  mega: yes
- name: キングドラ
- name: ゴマゾウ
- name: ドンファン
  gender_diff: yes
- name: ポリゴン２
- name: オドシシ
- name: ドーブル
- name: バルキー
- name: カポエラー
- name: ムチュール
- name: エレキッド
- name: ブビィ
- name: ミルタンク
- name: ハピナス
- name: ライコウ
- name: エンテイ
- name: スイクン
- name: ヨーギラス
- name: サナギラス
- name: バンギラス
  mega: yes
- name: ルギア
- name: ホウオウ
- name: セレビィ
- name: キモリ
- name: ジュプトル
- name: ジュカイン
  mega: yes
- name: アチャモ
  gender_diff: yes
- name: ワカシャモ
  gender_diff: yes
- name: バシャーモ
  gender_diff: yes
  mega: yes
- name: ミズゴロウ
- name: ヌマクロー
- name: ラグラージ
  mega: yes
- name: ポチエナ
- name: グラエナ
- name: ジグザグマ
- name: マッスグマ
- name: ケムッソ
- name: カラサリス
- name: アゲハント
  gender_diff: yes
- name: マユルド
- name: ドクケイル
  gender_diff: yes
- name: ハスボー
- name: ハスブレロ
- name: ルンパッパ
  gender_diff: yes
- name: タネボー
- name: コノハナ
  gender_diff: yes
- name: ダーテング
  gender_diff: yes
- name: スバメ
- name: オオスバメ
- name: キャモメ
- name: ペリッパー
- name: ラルトス
- name: キルリア
- name: サーナイト
  mega: yes
- name: アメタマ
- name: アメモース
- name: キノココ
- name: キノガッサ
- name: ナマケロ
- name: ヤルキモノ
- name: ケッキング
- name: ツチニン
- name: テッカニン
- name: ヌケニン
- name: ゴニョニョ
- name: ドゴーム
- name: バクオング
- name: マクノシタ
- name: ハリテヤマ
- name: ルリリ
- name: ノズパス
- name: エネコ
- name: エネコロロ
- name: ヤミラミ
  mega: yes
- name: クチート
  mega: yes
- name: ココドラ
- name: コドラ
- name: ボスゴドラ
  mega: yes
- name: アサナン
  gender_diff: yes
- name: チャーレム
  gender_diff: yes
  mega: yes
- name: ラクライ
- name: ライボルト
  mega: yes
- name: プラスル
- name: マイナン
- name: バルビート
- name: イルミーゼ
- name: ロゼリア
  gender_diff: yes
- name: ゴクリン
  gender_diff: yes
- name: マルノーム
  gender_diff: yes
- name: キバニア
- name: サメハダー
  mega: yes
- name: ホエルコ
- name: ホエルオー
- name: ドンメル
  gender_diff: yes
- name: バクーダ
  gender_diff: yes
  mega: yes
- name: コータス
- name: バネブー
- name: ブーピッグ
- name: パッチール
- name: ナックラー
- name: ビブラーバ
- name: フライゴン
- name: サボネア
- name: ノクタス
  gender_diff: yes
- name: チルット
- name: チルタリス
  mega: yes
- name: ザングース
- name: ハブネーク
- name: ルナトーン
- name: ソルロック
- name: ドジョッチ
- name: ナマズン
- name: ヘイガニ
- name: シザリガー
- name: ヤジロン
- name: ネンドール
- name: リリーラ
- name: ユレイドル
- name: アノプス
- name: アーマルド
- name: ヒンバス
- name: ミロカロス
  gender_diff: yes
- name: ポワルン
- name: カクレオン
- name: カゲボウズ
- name: ジュペッタ
  mega: yes
- name: ヨマワル
- name: サマヨール
- name: トロピウス
- name: チリーン
- name: アブソル
  mega: yes
- name: ソーナノ
- name: ユキワラシ
- name: オニゴーリ
  mega: yes
- name: タマザラシ
- name: トドグラー
- name: トドゼルガ
- name: パールル
- name: ハンテール
- name: サクラビス
- name: ジーランス
  gender_diff: yes
- name: ラブカス
- name: タツベイ
- name: コモルー
- name: ボーマンダ
  mega: yes
- name: ダンバル
- name: メタング
- name: メタグロス
  mega: yes
- name: レジロック
- name: レジアイス
- name: レジスチル
- name: ラティアス
  mega: yes
- name: ラティオス
  mega: yes
- name: カイオーガ
  primordial: yes    
- name: グラードン
  primordial: yes
- name: レックウザ
  mega: yes
- name: ジラーチ
- name: デオキシス
  forme: [ノーマル, アタック, ディフェンス, スピード]
- name: ナエトル
- name: ハヤシガメ
- name: ドダイトス
- name: ヒコザル
- name: モウカザル
- name: ゴウカザル
- name: ポッチャマ
- name: ポッタイシ
- name: エンペルト
- name: ムックル
  gender_diff: yes
- name: ムクバード
  gender_diff: yes
- name: ムクホーク
  gender_diff: yes
- name: ビッパ
  gender_diff: yes
- name: ビーダル
  gender_diff: yes
- name: コロボーシ
  gender_diff: yes
- name: コロトック
  gender_diff: yes
- name: コリンク
  gender_diff: yes
- name: ルクシオ
  gender_diff: yes
- name: レントラー
  gender_diff: yes
- name: スボミー
- name: ロズレイド
  gender_diff: yes
- name: ズガイドス
- name: ラムパルド
- name: タテトプス
- name: トリテプス
- name: ミノムッチ
  forme: [くさき, すなち, ゴミ]
- name: ミノマダム
  forme: [くさき, すなち, ゴミ]
- name: ガーメイル
- name: ミツハニー
  gender_diff: yes
- name: ビークイン
- name: パチリス
  gender_diff: yes
- name: ブイゼル
  gender_diff: yes
- name: フローゼル
  gender_diff: yes
- name: チェリンボ
- name: チェリム
- name: カラナクシ
  forme: [にし, ひがし]
- name: トリトドン
  forme: [にし, ひがし]
- name: エテボース
  gender_diff: yes
- name: フワンテ
- name: フワライド
- name: ミミロル
- name: ミミロップ
  mega: yes
- name: ムウマージ
- name: ドンカラス
- name: ニャルマー
- name: ブニャット
- name: リーシャン
- name: スカンプー
- name: スカタンク
- name: ドーミラー
- name: ドータクン
- name: ウソハチ
- name: マネネ
- name: ピンプク
- name: ペラップ
- name: ミカルゲ
- name: フカマル
  gender_diff: yes
- name: ガバイト
  gender_diff: yes
- name: ガブリアス
  gender_diff: yes
  mega: yes
- name: ゴンベ
- name: リオル
- name: ルカリオ
  mega: yes
- name: ヒポポタス
  gender_diff: yes
- name: カバルドン
  gender_diff: yes
- name: スコルピ
- name: ドラピオン
- name: グレッグル
  gender_diff: yes
- name: ドクロッグ
  gender_diff: yes
- name: マスキッパ
- name: ケイコウオ
  gender_diff: yes
- name: ネオラント
  gender_diff: yes
- name: タマンタ
- name: ユキカブリ
  gender_diff: yes
- name: ユキノオー
  gender_diff: yes
  mega: yes
- name: マニューラ
  gender_diff: yes
- name: ジバコイル
- name: ベロベルト
- name: ドサイドン
  gender_diff: yes
- name: モジャンボ
  gender_diff: yes
- name: エレキブル
- name: ブーバーン
- name: トゲキッス
- name: メガヤンマ
- name: リーフィア
- name: グレイシア
- name: グライオン
- name: マンムー
  gender_diff: yes
- name: ポリゴンＺ
- name: エルレイド
  mega: yes
- name: ダイノーズ
- name: ヨノワール
- name: ユキメノコ
- name: ロトム
- name: ユクシー
- name: エムリット
- name: アグノム
- name: ディアルガ
- name: パルキア
- name: ヒードラン
- name: レジギガス
- name: ギラティナ
- name: クレセリア
- name: フィオネ
- name: マナフィ
- name: ダークライ
- name: シェイミ
  forme: [ランド, スカイ]
- name: アルセウス
- name: ビクティニ
- name: ツタージャ
- name: ジャノビー
- name: ジャローダ
- name: ポカブ
- name: チャオブー
- name: エンブオー
- name: ミジュマル
- name: フタチマル
- name: ダイケンキ
- name: ミネズミ
- name: ミルホッグ
- name: ヨーテリー
- name: ハーデリア
- name: ムーランド
- name: チョロネコ
- name: レパルダス
- name: ヤナップ
- name: ヤナッキー
- name: バオップ
- name: バオッキー
- name: ヒヤップ
- name: ヒヤッキー
- name: ムンナ
- name: ムシャーナ
- name: マメパト
- name: ハトーボー
- name: ケンホロウ
  gender_diff: yes
- name: シママ
- name: ゼブライカ
- name: ダンゴロ
- name: ガントル
- name: ギガイアス
- name: コロモリ
- name: ココロモリ
- name: モグリュー
- name: ドリュウズ
- name: タブンネ
  mega: yes
- name: ドッコラー
- name: ドテッコツ
- name: ローブシン
- name: オタマロ
- name: ガマガル
- name: ガマゲロゲ
- name: ナゲキ
- name: ダゲキ
- name: クルミル
- name: クルマユ
- name: ハハコモリ
- name: フシデ
- name: ホイーガ
- name: ペンドラー
- name: モンメン
- name: エルフーン
- name: チュリネ
- name: ドレディア
- name: バスラオ
  forme: [あおすじ, あかすじ]
- name: メグロコ
- name: ワルビル
- name: ワルビアル
- name: ダルマッカ
- name: ヒヒダルマ
- name: マラカッチ
- name: イシズマイ
- name: イワパレス
- name: ズルッグ
- name: ズルズキン
- name: シンボラー
- name: デスマス
- name: デスカーン
- name: プロトーガ
- name: アバゴーラ
- name: アーケン
- name: アーケオス
- name: ヤブクロン
- name: ダストダス
- name: ゾロア
- name: ゾロアーク
- name: チラーミィ
- name: チラチーノ
- name: ゴチム
- name: ゴチミル
- name: ゴチルゼル
- name: ユニラン
- name: ダブラン
- name: ランクルス
- name: コアルヒー
- name: スワンナ
- name: バニプッチ
- name: バニリッチ
- name: バイバニラ
- name: シキジカ
- name: メブキジカ
- name: エモンガ
- name: カブルモ
- name: シュバルゴ
- name: タマゲタケ
- name: モロバレル
- name: プルリル
  gender_diff: yes
- name: ブルンゲル
  gender_diff: yes
- name: ママンボウ
- name: バチュル
- name: デンチュラ
- name: テッシード
- name: ナットレイ
- name: ギアル
- name: ギギアル
- name: ギギギアル
- name: シビシラス
- name: シビビール
- name: シビルドン
- name: リグレー
- name: オーベム
- name: ヒトモシ
- name: ランプラー
- name: シャンデラ
- name: キバゴ
- name: オノンド
- name: オノノクス
- name: クマシュン
- name: ツンベアー
- name: フリージオ
- name: チョボマキ
- name: アギルダー
- name: マッギョ
- name: コジョフー
- name: コジョンド
- name: クリムガン
- name: ゴビット
- name: ゴルーグ
- name: コマタナ
- name: キリキザン
- name: バッフロン
- name: ワシボン
- name: ウォーグル
- name: バルチャイ
- name: バルジーナ
- name: クイタラン
- name: アイアント
- name: モノズ
- name: ジヘッド
- name: サザンドラ
- name: メラルバ
- name: ウルガモス
- name: コバルオン
- name: テラキオン
- name: ビリジオン
- name: トルネロス
  forme: [けしん, れいじゅう]
- name: ボルトロス
  forme: [けしん, れいじゅう]
- name: レシラム
- name: ゼクロム
- name: ランドロス
  forme: [けしん, れいじゅう]
- name: キュレム
  forme: [ノーマル, ブラック, ホワイト]
- name: ケルディオ
  forme: [ノーマル, かくご]
- name: メロエッタ
  forme: [ボイス, ステップ]
- name: ゲノセクト
- name: ハリマロン
- name: ハリボーグ
- name: ブリガロン
- name: フォッコ
- name: テールナー
- name: マフォクシー
- name: ケロマツ
- name: ゲコガシラ
- name: ゲッコウガ
- name: ホルビー
- name: ホルード
- name: ヤヤコマ
- name: ヒノヤコマ
- name: ファイアロー
- name: コフキムシ
- name: コフーライ
- name: ビビヨン
- name: シシコ
- name: カエンジシ
  gender_diff: yes
- name: フラベベ
- name: フラエッテ
- name: フラージェス
- name: メェークル
- name: ゴーゴート
- name: ヤンチャム
- name: ゴロンダ
- name: トリミアン
- name: ニャスパー
- name: ニャオニクス
  gender_diff: yes
- name: ヒトツキ
- name: ニダンギル
- name: ギルガルド
- name: シュシュプ
- name: フレフワン
- name: ペロッパフ
- name: ペロリーム
- name: マーイーカ
- name: カラマネロ
- name: カメテテ
- name: ガメノデス
- name: クズモー
- name: ドラミドロ
- name: ウデッポウ
- name: ブロスター
- name: エリキテル
- name: エレザード
- name: チゴラス
- name: ガチゴラス
- name: アマルス
- name: アマルルガ
- name: ニンフィア
- name: ルチャブル
- name: デデンネ
- name: メレシー
- name: ヌメラ
- name: ヌメイル
- name: ヌメルゴン
- name: クレッフィ
- name: ボクレー
- name: オーロット
- name: バケッチャ
- name: パンプジン
- name: カチコール
- name: クレベース
- name: オンバット
- name: オンバーン
- name: ゼルネアス
- name: イベルタル
- name: ジガルデ
  forme: [セル, コア, 20%, 50%, 100%]
- name: ディアンシー
  mega: yes
- name: フーパ
  forme: [いましめられし, ときはなたれし]
