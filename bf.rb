# Brainf**k interpreter in Ruby
# Read from standard input or filenames given as arguments
# If no arguments are given, launch a REPL
#
# REPL commands:
# r: reset tape and pointer
# d then bf.debug()
# q then exit

# Inspired by:
# http://www.muppetlabs.com/~breadbox/bf/
# https://elliot.land/write-your-own-brainfuck-compiler
# https://thevogonpoet.wordpress.com/2012/09/02/writing-a-brainfuck-interpretter-in-python/

require 'io/console'
require 'readline'

class AST
	attr_reader :tree

	def initialize()
		@tree = []
		@stack_depth = 0
		@branch_stack = []
		@branch_curr = @tree
	end

	def push(ch)
		@branch_curr.push(ch)
	end

	def begin_loop
		# Increment stack depth
		@stack_depth += 1
		@branch_stack.push(@branch_curr)

		# Add a new branch to the tree
		branch_new = []
		@branch_curr.push(branch_new)
		@branch_curr = branch_new
	end

	def end_loop
		# Raise error if stack is empty
		if (@stack_depth == 0)
			raise "syntax error, unexpected ']'"
		end

		# Decrement stack depth
		@stack_depth -= 1

		# Remove from the tree
		if @stack_depth == 0
			@branch_curr = @tree
		else
			@branch_curr = @branch_stack.pop
		end
	end

	def to_s
		return tree.to_s
	end

end

class Brainfuck
	def initialize()
		@max_int = 256

		@tape = Array.new(1, 0)
		@p = 0 # Data pointer
	end

	def reset()
		# Modify array in place
		@tape = @tape.map! {0}
		@p = 0
	end

	def run(code)
		ast = tokenize(code)
		execute(ast)
	end

	def tokenize(code)

		ast = AST.new
		code.each_char.with_index do |ch, i|
			case ch
			when '>', '<', '+', '-', '.', ','
				ast.push(ch)
			when '['
				ast.begin_loop
			when ']'
				ast.end_loop
			end
		end
		return ast.tree
	end

	def execute(branch)
		# Reset program counter
		pc = 0

		while pc < branch.length
			token = branch[pc]

			case token
			when String
				step(token)
			when Array
				# This is a while loop
				# If the byte at the data pointer is zero, skip to after the loop
				# At the end of the loop, if the byte at the data pointer is nonzero, then repeat
				if @tape[@p] == 0
					pc += 1
				else
					begin
						# Keep executing until current byte is nonzero
						execute(token)
					end while @tape[@p] != 0
				end
			end

			# Increment program counter
			pc += 1
		end
	end

	def step(ch)
		case ch
		# Increment data pointer
		when '>' then
			@p += 1
			if @p >= @tape.length then @tape.push(0) end
		# Decrement data pointer
		when '<' then
			@p -= 1
			raise "segmentation fault" if @p < 0
		# Increment byte at data pointer
		when '+' then @tape[@p] = (@tape[@p] + 1) % @max_int
		# Decrement byte at data pointer
		when '-' then @tape[@p] = (@tape[@p] - 1) % @max_int
		# putchar
		when '.' then print(@tape[@p].chr)
		# getchar
		when ',' then p STDIN.getch
		end
	end

	def debug()
		@tape.each.with_index do |ch, i|
			if i == @p then print "[*#{ch}*] "
			else print "[#{ch}] "
			end
		end
		puts
	end

end

def repl
	bf = Brainfuck.new
	# Reset buffer
	buf = ""
	while true
		begin
			ln = Readline.readline("> ", true)

			case ln
			when 'r' then bf.reset()
			when 'd' then bf.debug()
			when 'q' then exit
			else
				buf << ln
				if buf.count('[') <= buf.count(']')
					bf.run(buf)
					buf = ""
				end
			end

		rescue Interrupt => e
			# Catch Ctrl-C SIGINT
			buf = "" # Reset buffer
			puts # Newline
		end
	end
end

def read_from_stdin
	bf = Brainfuck.new
	buf = ""
	while ln = ARGF.gets
		buf << ln
	end
	bf.run(buf)
end

# main
if ARGV.empty? then repl
else read_from_stdin end
