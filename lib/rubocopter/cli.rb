require 'optparse'
require 'shellwords'
require 'rubocop'
require 'pathname'
require_relative 'version'

RuboCopter::Options = Struct.new(:hash, :debug)

class RuboCopter::CLI
  attr_reader :options

  def run(args = ARGV)
    remaining_args = parse_options(args)
    check_for_offences(remaining_args)
    show_results

    $CHILD_STATUS.exitstatus
  end

  private

  def ruby_file?(name)
    File.extname(name).casecmp('.rb') == 0 || File.extname(name).casecmp('.rake') == 0
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

  def check_for_offences(remaining_args = [])
    rubocop_options = ['rubocop', '-R']
    unless remaining_args.include?('--out')
      rubocop_options += '--out rubocop_result.txt'.split
    end
    rubocop_options += remaining_args

    # Check for git.
    if `which git` == ''
      puts 'git not detected. Running normal rubocop.'
      system(Shellwords.join(rubocop_options))
      return
    end

    # Check for changes
    `git rev-parse`
    if $CHILD_STATUS.exitstatus == 0
      files = changed_ruby_file_names
      if files.length == 0
        puts 'No changes detected, no reason to run rubocop'
        exit(0)
      else
        system(Shellwords.join(rubocop_options + files))
      end
      return
    end

    # No git directory
    puts 'git directory not detected. Running normal rubocop.'
    system(Shellwords.join(rubocop_options))
  end

  def show_results
    if File.exist?('rubocop_result.txt')
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
    @options = RuboCopter::Options.new('master', false)

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Rubocopter v:#{RuboCopter::VERSION}\nRubocop v:#{RuboCop::Version::STRING}\nUsage: rubocopter [options]\n    *Any unknown options will be passed to rubocop directly."

      opts.on('--commit HASH', 'git hash to compare against') do |hash|
        @options.hash = hash
      end

      opts.on('--install-git-hooks HOOK', 'write git hooks to rubocopter. options : all, commit, push') do |hook|
        install_git_hooks(hook)
      end

      opts.on('--remove-git-hooks HOOK', 'remove git hooks. options : all, commit, push') do |hook|
        remove_git_hooks(hook)
      end

      opts.on('--debug', 'Prints runtime') do
        @options.debug = true
      end

      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end

    remaining_args = []
    begin
      opt_parser.parse(args)
    rescue OptionParser::InvalidOption => e
      remaining_args = e.args.map do |arg|
        arg_index = args.index(arg)
        if args[arg_index + 1].nil? || args[arg_index + 1].start_with?('-')
          args[arg_index]
        else
          [args[arg_index], args[arg_index + 1]]
        end
      end.flatten
    end

    remaining_args
  end

  def install_git_hooks(hook)
    working_dir_git_hooks = Pathname.new(Dir.pwd).join('.git', 'hooks').to_s
    current_path = Pathname.new(File.dirname(__FILE__))
    if hook == 'commit'
      system(Shellwords.join(['cp', current_path.join('../../git_hooks', 'pre-commit').to_s, working_dir_git_hooks]))
    elsif hook == 'push'
      system(Shellwords.join(['cp', current_path.join('../../git_hooks', 'pre-push').to_s, working_dir_git_hooks]))
    elsif hook == 'all'
      system(Shellwords.join(['cp', current_path.join('../../git_hooks', 'pre-commit').to_s, working_dir_git_hooks]))
      system(Shellwords.join(['cp', current_path.join('../../git_hooks', 'pre-push').to_s, working_dir_git_hooks]))
    end
    exit(0)
  end

  def remove_git_hooks(hook)
    working_dir_git_hooks = Pathname.new(Dir.pwd).join('.git', 'hooks')
    if hook == 'commit'
      system(Shellwords.join(['rm', working_dir_git_hooks.join('pre-commit').to_s]))
    elsif hook == 'push'
      system(Shellwords.join(['rm', working_dir_git_hooks.join('pre-push').to_s]))
    elsif hook == 'all'
      system(Shellwords.join(['rm', working_dir_git_hooks.join('pre-commit').to_s]))
      system(Shellwords.join(['rm', working_dir_git_hooks.join('pre-push').to_s]))
    end
    exit(0)
  end
end
