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
