#!usr/bin/env ruby

module Concatenative

	STACK = []

	module System

		def self.debug
			if Concatenative::DEBUG then
				print "STACK: "
				pp STACK
			end
		end

		def self.execute(array)
			STACK.clear
			array.each { |e| process e; debug }
			return *STACK
		end

			def self.prepend_execute(array, element)
			_push array.dup.prepend(element)
			_i
		end

		def self.process(item)
			if item.is_a?(Symbol)||item.is_a?(Concatenative::Message) then
				if item.is_a?(Symbol) && item.definition then
					item.definition.each {|e| process e}
				else
					call_function item
				end
			else
				_push item
			end
		end

		def self.call_function(item)
			name = "_#{item.to_s.downcase}".to_sym
			if (item.to_s.upcase == item.to_s) && !ARITIES[item] then
				respond_to?(name) ?	send(name) : raise(ConcatenativeError, "Unknown redex: #{item}")
			else
				_push send_message(item)
			end
		end

		def self.send_message(message)
			raise EmptyStackError, "Empty stack" if STACK.empty?
			case
			when message.is_a?(Concatenative::Message) then
				n = message.arity
				method = message.name
			when message.is_a?(Symbol) then
				n = ARITIES[message] || 0
				method = message
			end
			elements = []
			(n+1).times { elements << _pop }
			receiver = elements.pop
			args = []
			(elements.length).times { args << elements.pop }
			begin
				(args.length == 0)	? receiver.send(method) :	receiver.send(method, *args)
			rescue Exception => e
				raise RuntimeError, "Error when calling: #{receiver}##{method}(#{args.join(', ')}) [#{receiver.class}##{method}]"
			end
		end

		# Operators & Combinators

		def self._pop
			raise EmptyStackError, "Empty stack" if STACK.empty?
			STACK.pop
		end

		def self._push(element)
			STACK.push element
		end

		def self._put
			puts STACK.last 
		end

		def self._get
			_push gets
		end

		def self._dup
			raise EmptyStackError, "Empty stack" if STACK.empty?
			_push STACK.last
		end

		def self._swap
			a = _pop
			b = _pop
			_push a
			_push b
		end

		def self._cons
			array = _pop
			element = _pop
			raise ArgumentError, "CONS: first element is not an Array." unless array.is_a? Array
			_push array.prepend(element)
		end

		def self._cat
			array1 = _pop
			array2 = _pop
			raise ArgumentError, "CAT: first element is not an Array." unless array1.is_a? Array
			raise ArgumentError, "CAT: first element is not an Array." unless array2.is_a? Array
			_push array2.concat(array1)
		end

		def self._first
			array = _pop
			raise ArgumentError, "FIRST: first element is not an Array." unless array.is_a? Array
			raise ArgumentError, "FIRST: empty array." if array.length == 0
			_push array.first
		end

		def self._rest
			array = _pop
			raise ArgumentError, "REST: first element is not an Array." unless array.is_a? Array
			raise ArgumentError, "REST: empty array." if array.length == 0
			array.delete_at 0
			_push array
		end

		instance_eval do
			alias _zap _pop
			alias _concat _cat
		end

		def self._dip
			program = _pop
			raise ArgumentError, "DIP: first element is not an Array." unless program.is_a? Array
			arg = _pop
			_push program
			_i
			_push arg
		end

		def self._i
			program = _pop
			raise ArgumentError, "I: first element is not an Array." unless program.is_a? Array
			program.each { |e| process e }
		end

		def self._ifte
			_else = _pop
			_then = _pop
			_if = _pop
			arg = _pop
			raise ArgumentError, "IFTE: first element is not an Array." unless _if.is_a? Array
			raise ArgumentError, "IFTE: second element is not an Array." unless _then.is_a? Array
			raise ArgumentError, "IFTE: third element is not an Array." unless _else.is_a? Array
			prepend_execute _if, arg
			condition = _pop
			(condition) ? prepend_execute(_then, arg) : prepend_execute(_else, arg)
		end

		def self._unit
			_push [_pop]
		end

		def self._map
			program = _pop
			list = _pop
			raise ArgumentError, "MAP: first element is not an Array." unless program.is_a? Array
			raise ArgumentError, "MAP: second element is not an array." unless list.is_a? Array
			_push []
			list.map {|e| prepend_execute(program, e).first; _unit; _cat }
		end

		def self._step
			program = _pop
			list = _pop
			raise ArgumentError, "STEP: first element is not an Array." unless program.is_a? Array
			raise ArgumentError, "STEP: second element is not an array." unless list.is_a? Array
			list.map {|e| prepend_execute(program, e).first }
		end

		def self._linrec
			rec2 = _pop
			rec1 = _pop
			_then = _pop
			_if = _pop
			arg = _pop
			prepend_execute(_if, arg)
			condition = _pop
			if condition then
				prepend_execute(_then, arg)
			else
				prepend_execute(rec1, arg)
				STACK.concat [_if, _then, rec1, rec2]
				_linrec
				_push rec2
				_i
			end
		end

		def self._primrec
			rec2 = _pop
			_then = [:POP, _pop, :I]
			arg = _pop
			# Guessing IF
			case 
			when arg.respond_to?(:blank?) then
				_if = [:blank?]
			when arg.respond_to?(:empty?) then
				_if = [:empty]
			when arg.is_a?(Numeric) then
				_if = [0, :==]
			when arg.is_a?(String) then
				_if = ["", :==]
			else
				raise ArgumentError, "PRIMREC: Unable to create IF element for #{arg} (#{arg.class})"
			end
			# Guessing REC1
			case
			when arg.respond_to?(:length) && arg.respond_to?(:slice) then
				rec1 = [0, (arg.length-2), :slice|2]
			when arg.respond_to?(:-) then
				rec1 = [:DUP, 1, :-]
			else
				raise ArgumentError, "PRIMREC: Unable to create REC1 element for #{arg} (#{arg.class})"
			end
			STACK.concat [arg, _if, _then, rec1, rec2]
			_linrec
		end
		
	end
end
