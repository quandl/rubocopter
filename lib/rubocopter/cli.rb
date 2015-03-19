require 'optparse'
require 'shellwords'
require 'rubocop'

RuboCopter::Options = Struct.new(:hash)

class RuboCopter::CLI

  attr_reader :options

  def run(args = ARGV)
    parse_options(args)
    check_for_offences
  end

  private

  def ruby_file?(name)
    File.extname(name).casecmp('.rb') == 0
  end

  def git_diff
    puts "Checking files changes since #{@options.hash}"
    git_command = Shellwords.join(%w(git diff --name-only) + [@options.hash])
    git_output = `#{git_command}`
    fail "git error: #{git_command}" unless $CHILD_STATUS.to_i
    git_output.split("\n")
  end

  def changed_ruby_file_names
    rubyfiles = []
    git_diff.each do |file|
      rubyfiles.push(file) if ruby_file?(file) && File.file?(file)
    end
    rubyfiles
  end

  def check_for_offences
    if `which git` == ''
      puts 'git not detected. Running normal rubocop.'
      system(Shellwords.join(['rubocop', '-R'] + '--out rubocop_result.txt'.split))
    else
      `git rev-parse`
      if $?.exitstatus == 0
        files = changed_ruby_file_names
        if files.length == 0
          puts 'No changes detected, no reason to run rubocop'
          exit(0)
        else
          system(Shellwords.join(['rubocop', '-R'] + files + '--out rubocop_result.txt'.split))
        end
      else
        puts 'git directory not detected. Running normal rubocop.'
        system(Shellwords.join(['rubocop', '-R'] + '--out rubocop_result.txt'.split))
      end
    end

    if File.exists?('rubocop_result.txt')
      text = File.open('rubocop_result.txt').read
      puts text
      offense = /(\d+) offense/.match(text.split("\n")[-1])
      if offense
        num_of_offense = offense[1].to_i
        exit(-1) if num_of_offense > 0
      end
    else
      puts 'Something went wrong. Rubocop was not run.'
      exit(-1)
    end
  end

  def parse_options(args)
    @options = RuboCopter::Options.new('master')

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: rubocopter [options]"

      opts.on('-c HASH', '--commit HASH', 'git hash to compare against') do |hash|
        @options.hash = hash
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(args)
  end

end
