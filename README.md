# InteractiveSort

このアプリは、ポケモン、もしくはその他のリストデータを対話的にソートするものです。

## Installation

この誰得なアプリをインストールするのは不毛なので、このレポジトリをチェックアウトして、

    bundle install --path=vendor/bundle

を実行し、

    ruby exe/interactive-sort

で起動するのをお勧めします。

NOTE: 現時点では rubygems.org からダウンロードできるようにはなっていませんし、するつもりもありません。以下の記述は、rubygems.org からダウンロードできるようにした場合の話です。

Add this line to your application's Gemfile:

```ruby
gem 'interactive_sort'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install interactive_sort

## 使い方

### 起動

はじめから:

    $ interactive-sort start heapsort

  * `--list-file=LIST-FILE`: ポケモンじゃなくて、このリストのデータを読み込んでソートします。
    YAML または、1行に1項目ずつ書いたファイルを渡します。YAMLの場合はルートのデータが配列に
    なっていなければなりません。
  * `--prompt=PROMPT`: 質問の内容を指定します。下記の質問文の "一番" と "を選びなさい"
    の間に埋め込まれます。デフォルトでは、"好きなの" となります。
  * `--no-shuffle`: リストを開始前にシャッフルしないで始めます。
  * 付属のポケモンのデータを使うには、`--list-file` を指定しないで起動すればおkです。

つづきから:

    $ interactive-sort continue STATE_FILE

  * `STATE_FILE`: 途中の保存データを渡します。

### ポケモンデータの設定

設定中は、`quit` で中止できます。

まず、性別で姿が異なるポケモンを区別するか聞きます。

    ## 性別による姿の違いを質問しますか?
    
       ヒント: このリストには細かい違いしかないポケモンも含まれています
    
      1. 全て入れる
      2. 一部を除いて入れる
      3. 大きな違いがあるポケモンだけを入れる
      4. 少しだけ入れる
      5. 入れない
    
    > <!-- --> 

区別する場合、質問の項目は

1. フシギバナ♂
2. フシギバナ♀

のように♂と♀に分かれます。

なお、リストは、http://bulbapedia.bulbagarden.net/wiki/List_of_Pok%C3%A9mon_with_gender_differences を元に作成しています。ただし、このデータではニドラン♂とニドラン♀は別種扱いになっているため、この2匹を区別するかは選択できません。

1 と 5 以外を選択した場合は、編集に移ります。

    ## 個別に除外もしくは追加したいポケモンを選んでください
    
       ヒント: 終了するには exit と入力します。
    
    > <!-- --> 

区別する、しないを切り替えるポケモンを番号（図鑑の番号ではない）で選択します。番号は [Tab] キーを2回おして確認してください。

次に、メガシンカとゲンシカイキのポケモンを含めるか聞きます。

    ## メガシンカとゲンシカイキを質問しますか?
    
      1. 全て入れる
      2. 一部を除いて入れる
      3. メガシンカのみ入れる
      4. ゲンシカイキのみ入れる
      5. 少しだけ入れる
      6. 入れない
    
    > <!-- --> 

同様に 1 と 6 以外を選択した場合は、個別に編集できます。ただし、現時点では、メガシンカが2種類以上あるポケモンの一方だけを追加したりすることはできません。

最後に、フォルム違いのポケモンを含めるか聞きます。

    ## フォルム違いを質問しますか?
    
      1. 全て入れる
      2. 一部を除いて入れる
      3. 少しだけ入れる
      4. 入れない
    
    > <!-- -->

同様に 1 と 4 以外を選択した場合は、個別に編集できます。ただし、こちらも、現時点では、特定のフォルムだけを追加したり削除したりはできません。

  * フォルム名はわかりにくくならない程度に省略しています。
    - 例1: ミノマダム (くさき) -- 正確には「くさきのミノ」
    - 例2: トリトドン (ひがし) -- 正確には「ひがしのうみ」
  * アルセウスのフォルム違いは、持たせるプレートの名前になっています。
  * ゲノセクトのフォルム違いは、持たせるカセットの名前になっています。
  * バケッチャとパンプジンは、大きさをフォルム違いとして扱っています。

### ヒープソート

提示されたリストから、最も好き（嫌い）なものを選んでいきます。

    ## 一番好きなのを選びなさい
    
     1. クヌギダマ
     2. マダツボミ
     3. フレフワン
     4. バニプッチ
     5. タネボー
     6. ヒメグマ
     7. ウルガモス
     8. ツタージャ
    
    >

この場合であれば、1〜8 の番号を入力して Enter を押します。

これをひたすら答えていくと、好きな順番に並びます。

## コマンドリスト

### `confirmed`

確定済みのリストを表示します。

### `draw-tree --from=[root] --depth=[depth]`

現在のヒープ木を描画します。

`[root]` が 0 の場合は、ヒープ木の根元から、それ以外の場合は、現在の質問の選択肢の番号以下のヒープ木を表示します。

`[depth]` 表示する深さの限界を指定します。省略したり、0 を指定すると無制限に表示します。

### `draw-dot --from=[root] --depth=[depth]`

現在のヒープ木 (全体) を dot 言語で出力します。

出力先は今の所、端末のみです。また、レイアウトされていないので、画像にするには、Graphviz などのレイアウトのできるソフトが必要です。

### `quit`

終了します。終了する際に、途中経過を保存できます。

保存したファイルから再開する場合は、

    $ interactive-sort continue [保存したファイル]

で再開できます。

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lugia-kun/interactive_sort.

## 備考

ポケモンの並び替えでは、最低でも 808 回は質問されます。多いと 2000 回以上質問される場合もあります。
