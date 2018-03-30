function! s:new(start, end) dict
	let inst = deepcopy(s:TNT)
	let inst.start = a:start
	let inst.end = a:end

	let inst.str = join(getline(a:start, a:end), "\n")

	if !&expandtab
		let [str, start, end] = matchstrpos(inst.str, "\v^\t+")
	else
		let [str, start, end] = matchstrpos(inst.str, "\v^[ ]+")
	endif

	if start == -1
		let inst.indent = 0
	else
		let inst.indent = end/&ts
	endif

	return inst
endfunction

function! s:rewriteList(bracket, quote, delim, multiline) dict
	let res = self.fmtList(a:bracket, a:quote, a:delim, a:multiline)

	if self.end > self.start
		execute self.start . "," . (self.end - 1)."d"
	endif

	if !a:multiline
		call setline(self.start, res)
	elseif a:multiline
		call setline(self.start, res[0])
		call append(self.start, res[1:])
	endif

endfunction

function! s:fmtList(bracket, quote, delim, multiline) dict
	let open_bracket = a:bracket
	let close_idx = match(self.OPENING_BRACKETS, a:bracket)

	if close_idx != -1
		let close_bracket = self.CLOSING_BRACKETS[close_idx]
	else
		throw "Could not find a closing match for the " . a:bracket . " opening."
	endif

	let res = ""
	let prefix = ""

	" Advance past anything before the opening bracket. We specifically don't
	" tokenize this because it could be any garbage and we don't care.
	while match(self.OPENING_BRACKETS, self.str[self.idx]) == -1
		let prefix .= self.str[self.idx]
		let self.idx += 1
	endwhile

	if self.nextToken() != 'OPENING_BRACKET'
		throw "Unexpected token " . self.str[self.idx] . ", expecting an OPENING_BRACKET."
	end

	let items = []

	while !exists('item') || !item.eof
		let item = self.consumeItem()

		let item.str = s:tern(item.quoted, a:quote . item.str . a:quote, item.str)
		call add(items, item.str)

		" TODO: Sub out the previous escaped quote characters inside of the
		" item with the new quote character.

		let tok = self.nextToken()
		" Consume the following delimeter
		if tok != 'DELIM' && tok != 'CLOSING_BRACKET'
			echo "TOK: " . tok
			echo "REMAINING: " . self.str[self.idx:-1]
			throw "Unexpected token '" . self.tok . "', expecting a DELIM or a CLOSING_BRACKET."
		elseif tok == 'CLOSING_BRACKET'
			if !a:multiline
				let delim = s:tern(a:delim != ' ', ' ' . a:delim . ' ', ' ')
				return prefix . open_bracket . join(items, delim) . close_bracket
			else
				let results = [self.genIndent(self.indent) . prefix . open_bracket]

				for i in range(len(items))
					let item = items[i]
					if i != len(items) - 1
						call add(results, self.genIndent(self.indent + 1) . item . a:delim)
					else
						call add(results, self.genIndent(self.indent + 1) . item)
					endif
				endfor
				call add(results, self.genIndent(self.indent) . close_bracket)

				return results
			endif
		endif
	endwhile

endfunction

function! s:genIndent(num) dict
	let res = ""
	for i in range(a:num)
		let res .= "\t"
	endfor
	return res
endfunction

function! s:tern(condition, a, b)
	if a:condition
		return a:a
	else
		return a:b
	endif
endfunction

function! s:badTok(expect) dict
	return "Unexpected token '" . self.tok . "', expecting a ".a:expect
endfunction

function! s:consumeItem() dict
	let peek = self.peek()

	if peek == 'WORD'
		call self.nextToken()
		let item = self.tok
		let quoted = 0
	elseif peek == 'QUOTE'
		let item = self.consumeQuote()
		let quoted = 1
	else
		return {'str': '', 'eof': 1, 'quoted': 0}
	end

	return {'str': item, 'eof': 0, 'quoted': quoted}
endfunction

function! s:peek() dict
	let start_idx = self.idx
	let tok = self.tok

	let res = self.nextToken()

	let self.tok = tok
	let self.idx = start_idx
	return res
endfunction

function! s:consumeQuote() dict
	let escaping = 0

	if self.nextToken() != 'QUOTE'
		throw self.badTok("QUOTE")
	end

	let quot = self.tok
	let str = ""

	" Look for the matching closing quote
	while escaping || self.str[self.idx] != quot
		" Finished the escape sequence (probably)
		let str .= self.str[self.idx]
		let self.idx += 1
		if escaping
			escaping = 0
		endif
	endwhile

	" Move past the closing quote
	let self.idx += 1

	return str
endfunction

function! s:nextToken() dict
	let start_idx = self.idx
	let self.tok = ''

	" Consume any leading whitespace
	while match(self.str[self.idx], '\v\s+') != -1
		let self.idx += 1
	endwhile

	let types = ['DELIMS', 'QUOTES', 'OPENING_BRACKETS', 'CLOSING_BRACKETS']

	for type in types
		echo "TYPE: " . type
		for tok in self[type]
			let [str, start, end] = matchstrpos(self.str[self.idx:-1], '\v^' . tok)
			if start != -1
				let self.tok = self.str[start:end - 1]
				let self.idx += len(str) + 1
				echo "STR: " . str
				echo "TOK: " . self.tok
				echo "IDX: " . self.idx
				return type[0:-2]
			end
		endfor
	endfor

	let word_match = 0

	" If we got here we didn't match against any of the 'regular' tokens
	" above. At this point we check and see if we have a word match.
	while matchstrpos(self.str[self.idx], '\v[A-Za-z0-9]')[1] != -1
		let word_match = 1
		let self.tok .= self.str[self.idx]
		let self.idx += 1
	endwhile

	if word_match
		return 'WORD'
	end

	return 'EOF'
endfunction

let s:TNT = {
	\ 'idx': 0,
	\ 'indent': -1,
	\ 'start': -1,
	\ 'end': -1,
	\ 'str': '',
	\ 'tok': '',
	\ 'eof': 0,
	\ 'genIndent': function('s:genIndent'),
	\ 'new': function('s:new'),
	\ 'rewriteList': function('s:rewriteList'),
	\ 'nextToken': function('s:nextToken'),
	\ 'consumeItem': function('s:consumeItem'),
	\ 'consumeQuote': function('s:consumeQuote'),
	\ 'fmtList': function('s:fmtList'),
	\ 'peek': function('s:peek'),
	\ 'DELIMS': ['\,\n', '[a-zA-Z"0-9]{1}\zs\n\ze', '\,', '\:', '\=\>'],
	\ 'QUOTES': ["\'", '\"'],
	\ 'OPENING_BRACKETS': ['\[\n', '\(', '\[', '\<'],
	\ 'CLOSING_BRACKETS': ['\]', '\)', '\]', '\>'],
\ }

command! -nargs=* -range -bang TNT call s:TNT.new(<line1>, <line2>).rewriteList(<f-args>, <bang>0)
