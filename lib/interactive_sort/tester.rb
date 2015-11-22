#!/bin/ruby

require 'optparse'
require 'tempfile'

$script = "interactive_sort.rb"
$num_check = 720
$base = 10

OptionParser.new do |x|
  x.on("-N", "--number-of-items=NUM", Integer, "Number of items") do |n|
    $num_check = n
  end

  x.on("-b", "--base-number=NUM", Integer, "Base number for selections") do |n|
    $base = n
  end
end.parse!

a = (1..$num_check).to_a
input_txt = a.join("\n")

t = Tempfile.new("input.")
t.print input_txt
t.flush

inc = 1
bas = 3
incb = $base

N = 10
puts "N = %d\tN*log(N) = %.1f\tN*log2(N) = %1.f" % [$num_check, $num_check * Math.log($num_check), $num_check * Math.log($num_check) / Math.log(2.0)]
puts "%s\t%s\t%s\t%s\t%s\t%s\t%s" % %w[M+1 Min Max Ave Min*M Max*M Ave*M]
loop do
  min = 0
  mmin = 0
  IO.popen("ruby #{$script} --answer=1 --max-selections=#{bas} #{t.path}", "r") do |pp|

    m = pp.readlines
    m[0].match(/(\d+) questions performed./)
    min = $1.to_i
    m[1].match(/(\d+) comperations/)
    mmin = $1.to_i
  end
  fail "Execution faled." if $?.exitstatus != 0
  
  max = 0
  mmax = 0
  IO.popen("ruby #{$script} --answer=2 --max-selections=#{bas} #{t.path}", "r") do |pp|
    m = pp.readlines
    m[0].match(/(\d+) questions performed./)
    max = $1.to_i
    m[1].match(/(\d+) comperations/)
    mmax = $1.to_i
  end
  fail "Execution faled." if $?.exitstatus != 0

  ave = 0
  mave = 0
  ll = 1.upto(N).inject([]) do |l, m| 
    IO.popen("ruby #{$script} --answer --max-selections=#{bas} #{t.path}", "r") do |pp|
      a = pp.readlines
      a[0].match(/(\d+) questions performed./)
      va = $1.to_i
      a[1].match(/(\d+) comperations/)
      mv = $1.to_i
      l << [va, mv]
      ave += va
      mave += mv
    end
    fail "Execution faled." if $?.exitstatus != 0
    l
  end
  ave /= N.to_f
  mave /= N.to_f
  var, mvar = ll.inject([0.0, 0.0]) do |x, y|
    x[0] += (y[0] - ave) ** 2.0
    x[1] += (y[1] - mave) ** 2.0
    x
  end
  var = Math.sqrt(var / N)
  mvar = Math.sqrt(mvar / N)
  
  puts "%d\t%d\t%d\t%.1f\t%d\t%d\t%.1f\t%.4f\t%.4f" %
       [bas, min, max, ave,  mmin, mmax, mave, var, mvar]

  if bas == $num_check
    break
  end

  if bas + inc > incb
    inc  *= $base
    incb *= $base
  end
  bas += inc
  if bas > $num_check
    bas = $num_check
  end
end
