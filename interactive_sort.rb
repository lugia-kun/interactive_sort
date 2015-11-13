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
end.parse!

module InteractiveHeapSort
  @@prompt = "## 一番好きなのを選びなさい (%d回目)"
  @@readline_prompt = "> <!-- --> "

  class Quit < RuntimeError
    def to_s
      "Aborted"
    end
  end

  private
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

  def draw_dot(factor, root, last, depth = 0)
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
      puts "graph G {"
      puts "   n#{root} [label=\"#{self[root]}\"]"
    end
    (fst..lst).each do |i|
      puts "   n#{i} [label=\"#{self[i]}\"]"
    end
    (fst..lst).each do |i|
      puts "   n#{root} -- n#{i}"
    end
    (fst..lst).each do |i|
      draw_dot(factor, i, last, depth + 1)
    end
    if depth == 0
      puts "}"
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
  
    @q_cnt ||= 0
    @q_cnt += 1    
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
    messages << "quit"
    messages << "firmed"
    messages << "draw-tree"
    messages << "draw-dot"
    Readline.completion_proc = Proc.new do |a|
      messages.select { |m| m.match(a.to_s) }
    end
    puts
    loop do
      buf = Readline.readline(@@readline_prompt, true)
      raise Quit unless buf
      raise Quit if buf =~ /^\s*quit.*$/
      if buf =~ /^\s*firmed.*$/
        if l == length
          puts "## まだ何も確定していませんよ"
          next
        end
        puts
        puts "## 確定済みリスト"
        puts
        (length - 1).downto(l) do |i|
          puts " %d. %s" % [length - i, self[i]]
        end
        next
      end
      if buf =~ /^\s*draw-tree\s+(\d+)\.?\s+(\d).*$/
        n = $1.to_i - 1
        d = $2.to_i - 1
        ll = length
        if 0 <= d
          ll = 0.upto(d).inject(0) do |i, j|
            i + factor ** j
          end
        end
        if ll > length
          ll = length
        end
        if 0 <= n && n < ss.size
          draw_tree(factor, ss[n], ll)
        else
          draw_tree(factor, 0, ll)
        end
        next
      end
      if buf =~ /^\s*draw-tree\s+(\d+).*$/
        n = $1.to_i - 1
        if 0 <= n && n < ss.size
          draw_tree(factor, ss[n], l)
        else
          draw_tree(factor, 0, l)
        end
        next
      end
      if buf =~ /^\s*draw-tree.*$/
        draw_tree(factor, 0, l)
        next
      end
      if buf =~ /^\s*draw-dot.*$/
        draw_dot(factor, 0, l)
        next
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
  def heap_sort!(heap_factor = nil)
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

@ary.extend InteractiveHeapSort
begin
  @ary.heap_sort_state = $opt[:state]
  @ary.heap_sort!($opt[:max_sel])
rescue InteractiveHeapSort::Quit
  Readline.completion_proc = proc do |m|
    %w[yes no].select { |x| x.match(m) }
  end
  ret = Readline.readline("Save state? (yes/no)> ", false)
  if ret =~ /^\s*y/i
    Readline.completion_proc = Readline::FILENAME_COMPLETION_PROC
    fn = Readline.readline("Enter filename> ", false)
    exit 1 unless fn
    fn.sub!(/\s*$/, "")
    File.open(fn, "w") do |fp|
      fp.print $opt[:state].to_yaml
    end
  end
  exit 0
end
@ary.reverse!

as = (Math.log(@ary.length - 1) / Math.log(10)).to_i + 1
puts
puts "## 結果"
puts
@ary.each_with_index do |x, i|
  puts "%*d. %s" % [as, i + 1, x]
end

__END__
フシギダネ
フシギソウ
フシギバナ
ヒトカゲ
リザード
リザードン
ゼニガメ
カメール
カメックス
キャタピー
トランセル
バタフリー
ビードル
コクーン
スピアー
ポッポ
ピジョン
ピジョット
コラッタ
ラッタ
オニスズメ
オニドリル
アーボ
アーボック
ピカチュウ
ライチュウ
サンド
サンドパン
ニドラン♀
ニドリーナ
ニドクイン
ニドラン♂
ニドリーノ
ニドキング
ピッピ
ピクシー
ロコン
キュウコン
プリン
プクリン
ズバット
ゴルバット
ナゾノクサ
クサイハナ
ラフレシア
パラス
パラセクト
コンパン
モルフォン
ディグダ
ダグトリオ
ニャース
ペルシアン
コダック
ゴルダック
マンキー
オコリザル
ガーディ
ウインディ
ニョロモ
ニョロゾ
ニョロボン
ケーシィ
ユンゲラー
フーディン
ワンリキー
ゴーリキー
カイリキー
マダツボミ
ウツドン
ウツボット
メノクラゲ
ドククラゲ
イシツブテ
ゴローン
ゴローニャ
ポニータ
ギャロップ
ヤドン
ヤドラン
コイル
レアコイル
カモネギ
ドードー
ドードリオ
パウワウ
ジュゴン
ベトベター
ベトベトン
シェルダー
パルシェン
ゴース
ゴースト
ゲンガー
イワーク
スリープ
スリーパー
クラブ
キングラー
ビリリダマ
マルマイン
タマタマ
ナッシー
カラカラ
ガラガラ
サワムラー
エビワラー
ベロリンガ
ドガース
マタドガス
サイホーン
サイドン
ラッキー
モンジャラ
ガルーラ
タッツー
シードラ
トサキント
アズマオウ
ヒトデマン
スターミー
バリヤード
ストライク
ルージュラ
エレブー
ブーバー
カイロス
ケンタロス
コイキング
ギャラドス
ラプラス
メタモン
イーブイ
シャワーズ
サンダース
ブースター
ポリゴン
オムナイト
オムスター
カブト
カブトプス
プテラ
カビゴン
フリーザー
サンダー
ファイヤー
ミニリュウ
ハクリュー
カイリュー
ミュウツー
ミュウ
チコリータ
ベイリーフ
メガニウム
ヒノアラシ
マグマラシ
バクフーン
ワニノコ
アリゲイツ
オーダイル
オタチ
オオタチ
ホーホー
ヨルノズク
レディバ
レディアン
イトマル
アリアドス
クロバット
チョンチー
ランターン
ピチュー
ピィ
ププリン
トゲピー
トゲチック
ネイティ
ネイティオ
メリープ
モココ
デンリュウ
キレイハナ
マリル
マリルリ
ウソッキー
ニョロトノ
ハネッコ
ポポッコ
ワタッコ
エイパム
ヒマナッツ
キマワリ
ヤンヤンマ
ウパー
ヌオー
エーフィ
ブラッキー
ヤミカラス
ヤドキング
ムウマ
アンノーン
ソーナンス
キリンリキ
クヌギダマ
フォレトス
ノコッチ
グライガー
ハガネール
ブルー
グランブル
ハリーセン
ハッサム
ツボツボ
ヘラクロス
ニューラ
ヒメグマ
リングマ
マグマッグ
マグカルゴ
ウリムー
イノムー
サニーゴ
テッポウオ
オクタン
デリバード
マンタイン
エアームド
デルビル
ヘルガー
キングドラ
ゴマゾウ
ドンファン
ポリゴン２
オドシシ
ドーブル
バルキー
カポエラー
ムチュール
エレキッド
ブビィ
ミルタンク
ハピナス
ライコウ
エンテイ
スイクン
ヨーギラス
サナギラス
バンギラス
ルギア
ホウオウ
セレビィ
キモリ
ジュプトル
ジュカイン
アチャモ
ワカシャモ
バシャーモ
ミズゴロウ
ヌマクロー
ラグラージ
ポチエナ
グラエナ
ジグザグマ
マッスグマ
ケムッソ
カラサリス
アゲハント
マユルド
ドクケイル
ハスボー
ハスブレロ
ルンパッパ
タネボー
コノハナ
ダーテング
スバメ
オオスバメ
キャモメ
ペリッパー
ラルトス
キルリア
サーナイト
アメタマ
アメモース
キノココ
キノガッサ
ナマケロ
ヤルキモノ
ケッキング
ツチニン
テッカニン
ヌケニン
ゴニョニョ
ドゴーム
バクオング
マクノシタ
ハリテヤマ
ルリリ
ノズパス
エネコ
エネコロロ
ヤミラミ
クチート
ココドラ
コドラ
ボスゴドラ
アサナン
チャーレム
ラクライ
ライボルト
プラスル
マイナン
バルビート
イルミーゼ
ロゼリア
ゴクリン
マルノーム
キバニア
サメハダー
ホエルコ
ホエルオー
ドンメル
バクーダ
コータス
バネブー
ブーピッグ
パッチール
ナックラー
ビブラーバ
フライゴン
サボネア
ノクタス
チルット
チルタリス
ザングース
ハブネーク
ルナトーン
ソルロック
ドジョッチ
ナマズン
ヘイガニ
シザリガー
ヤジロン
ネンドール
リリーラ
ユレイドル
アノプス
アーマルド
ヒンバス
ミロカロス
ポワルン
カクレオン
カゲボウズ
ジュペッタ
ヨマワル
サマヨール
トロピウス
チリーン
アブソル
ソーナノ
ユキワラシ
オニゴーリ
タマザラシ
トドグラー
トドゼルガ
パールル
ハンテール
サクラビス
ジーランス
ラブカス
タツベイ
コモルー
ボーマンダ
ダンバル
メタング
メタグロス
レジロック
レジアイス
レジスチル
ラティアス
ラティオス
カイオーガ
グラードン
レックウザ
ジラーチ
デオキシス
ナエトル
ハヤシガメ
ドダイトス
ヒコザル
モウカザル
ゴウカザル
ポッチャマ
ポッタイシ
エンペルト
ムックル
ムクバード
ムクホーク
ビッパ
ビーダル
コロボーシ
コロトック
コリンク
ルクシオ
レントラー
スボミー
ロズレイド
ズガイドス
ラムパルド
タテトプス
トリテプス
ミノムッチ
ミノマダム
ガーメイル
ミツハニー
ビークイン
パチリス
ブイゼル
フローゼル
チェリンボ
チェリム
カラナクシ
トリトドン
エテボース
フワンテ
フワライド
ミミロル
ミミロップ
ムウマージ
ドンカラス
ニャルマー
ブニャット
リーシャン
スカンプー
スカタンク
ドーミラー
ドータクン
ウソハチ
マネネ
ピンプク
ペラップ
ミカルゲ
フカマル
ガバイト
ガブリアス
ゴンベ
リオル
ルカリオ
ヒポポタス
カバルドン
スコルピ
ドラピオン
グレッグル
ドクロッグ
マスキッパ
ケイコウオ
ネオラント
タマンタ
ユキカブリ
ユキノオー
マニューラ
ジバコイル
ベロベルト
ドサイドン
モジャンボ
エレキブル
ブーバーン
トゲキッス
メガヤンマ
リーフィア
グレイシア
グライオン
マンムー
ポリゴンＺ
エルレイド
ダイノーズ
ヨノワール
ユキメノコ
ロトム
ユクシー
エムリット
アグノム
ディアルガ
パルキア
ヒードラン
レジギガス
ギラティナ
クレセリア
フィオネ
マナフィ
ダークライ
シェイミ
アルセウス
ビクティニ
ツタージャ
ジャノビー
ジャローダ
ポカブ
チャオブー
エンブオー
ミジュマル
フタチマル
ダイケンキ
ミネズミ
ミルホッグ
ヨーテリー
ハーデリア
ムーランド
チョロネコ
レパルダス
ヤナップ
ヤナッキー
バオップ
バオッキー
ヒヤップ
ヒヤッキー
ムンナ
ムシャーナ
マメパト
ハトーボー
ケンホロウ
シママ
ゼブライカ
ダンゴロ
ガントル
ギガイアス
コロモリ
ココロモリ
モグリュー
ドリュウズ
タブンネ
ドッコラー
ドテッコツ
ローブシン
オタマロ
ガマガル
ガマゲロゲ
ナゲキ
ダゲキ
クルミル
クルマユ
ハハコモリ
フシデ
ホイーガ
ペンドラー
モンメン
エルフーン
チュリネ
ドレディア
バスラオ
メグロコ
ワルビル
ワルビアル
ダルマッカ
ヒヒダルマ
マラカッチ
イシズマイ
イワパレス
ズルッグ
ズルズキン
シンボラー
デスマス
デスカーン
プロトーガ
アバゴーラ
アーケン
アーケオス
ヤブクロン
ダストダス
ゾロア
ゾロアーク
チラーミィ
チラチーノ
ゴチム
ゴチミル
ゴチルゼル
ユニラン
ダブラン
ランクルス
コアルヒー
スワンナ
バニプッチ
バニリッチ
バイバニラ
シキジカ
メブキジカ
エモンガ
カブルモ
シュバルゴ
タマゲタケ
モロバレル
プルリル
ブルンゲル
ママンボウ
バチュル
デンチュラ
テッシード
ナットレイ
ギアル
ギギアル
ギギギアル
シビシラス
シビビール
シビルドン
リグレー
オーベム
ヒトモシ
ランプラー
シャンデラ
キバゴ
オノンド
オノノクス
クマシュン
ツンベアー
フリージオ
チョボマキ
アギルダー
マッギョ
コジョフー
コジョンド
クリムガン
ゴビット
ゴルーグ
コマタナ
キリキザン
バッフロン
ワシボン
ウォーグル
バルチャイ
バルジーナ
クイタラン
アイアント
モノズ
ジヘッド
サザンドラ
メラルバ
ウルガモス
コバルオン
テラキオン
ビリジオン
トルネロス
ボルトロス
レシラム
ゼクロム
ランドロス
キュレム
ケルディオ
メロエッタ
ゲノセクト
ハリマロン
ハリボーグ
ブリガロン
フォッコ
テールナー
マフォクシー
ケロマツ
ゲコガシラ
ゲッコウガ
ホルビー
ホルード
ヤヤコマ
ヒノヤコマ
ファイアロー
コフキムシ
コフーライ
ビビヨン
シシコ
カエンジシ
フラベベ
フラエッテ
フラージェス
メェークル
ゴーゴート
ヤンチャム
ゴロンダ
トリミアン
ニャスパー
ニャオニクス
ヒトツキ
ニダンギル
ギルガルド
シュシュプ
フレフワン
ペロッパフ
ペロリーム
マーイーカ
カラマネロ
カメテテ
ガメノデス
クズモー
ドラミドロ
ウデッポウ
ブロスター
エリキテル
エレザード
チゴラス
ガチゴラス
アマルス
アマルルガ
ニンフィア
ルチャブル
デデンネ
メレシー
ヌメラ
ヌメイル
ヌメルゴン
クレッフィ
ボクレー
オーロット
バケッチャ
パンプジン
カチコール
クレベース
オンバット
オンバーン
ゼルネアス
イベルタル
ジガルデ
ディアンシー
フーパ
