function! s:new(str)
	let inst = deepcopy(s:TNT)
	let inst.str = a:str
	return inst
endfunction

function! s:rewriteList(delim, quote, bracket) dict
	let open_bracket = a:bracket
	let close_idx = match(self.OPENING_BRACKETS, a:bracket)

	if close_idx != -1
		let close_bracket = self.CLOSING_BRACKETS[close_idx]
	else
		throw "Could not find a closing match for the " . a:bracket . " opening."
	endif

	let res = ""

	" Advance past anything before the opening bracket. We specifically don't
	" tokenize this because it could be any garbage and we don't care.
	while match(self.OPENING_BRACKETS, self.str[self.idx]) == -1
		let self.idx += 1
	endwhile


	if self.nextToken() != 'OPENING_BRACKET'
		throw "Unexpected token " . self.str[self.idx] . ", expecting an OPENING_BRACKETS."
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
			throw "Unexpected token '" . self.tok . "', expecting a DELIM or a CLOSING_BRACKET."
		elseif tok == 'CLOSING_BRACKET'
			let delim = s:tern(a:delim != ' ', ' ' . a:delim . ' ', ' ')
			return open_bracket . join(items, delim) . close_bracket
		endif
	endwhile

endfunction

function! s:tern(condition, a, b)
	if a:condition
		return a:a
	else
		return a:b
	endif
endfunction

function! s:badTok(expect)
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

function! s:indent()
endfunction

function! s:advancePast(pats) dict
	return self.advanceTo(a:pats, 1)
endfunction

function! s:nextToken() dict
	let start_idx = self.idx
	let self.tok = ''

	" Consume any leading whitespace
	while self.str[self.idx] == ' '
		let self.idx += 1
	endwhile

	let types = ['DELIMS', 'QUOTES', 'OPENING_BRACKETS', 'CLOSING_BRACKETS']

	for type in types
		for tok in self[type]
			if self.str[self.idx:self.idx + len(tok) - 1] == tok
				let self.tok = self.str[self.idx:self.idx + len(tok) - 1]
				let self.idx += 1
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
	\ 'str': '',
	\ 'tok': '',
	\ 'eof': 0,
	\ 'new': function('s:new'),
	\ 'rewriteList': function('s:rewriteList'),
	\ 'nextToken': function('s:nextToken'),
	\ 'consumeItem': function('s:consumeItem'),
	\ 'consumeQuote': function('s:consumeQuote'),
	\ 'peek': function('s:peek'),
	\ 'DELIMS': [",", ":", "=>"],
	\ 'QUOTES': ["'", '"'],
	\ 'OPENING_BRACKETS': ['(', '[', '<'],
	\ 'CLOSING_BRACKETS': [')', ']', '>'],
\ }

echo "NEW LIST: " . s:TNT.new("abc(foo, 'bar', baz)").rewriteList(" ", ";", "(")
