3
3
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
		throw "Unexpected token " . self.str[self.idx] . ", expecting an open bracket (or similar)."
	end

	let item = self.consumeItem()
	let items = []

	while !item.eof
		let item = self.consumeItem()
		call add(items, a:quote . item . a:quote)
		" TODO: Sub out the previous escaped quote characters inside of the
		" item with the new quote character.

		" Consume the following delimeter
		if self.nextToken() != 'DELIM'
			throw "Unexpected token '" . self.str[self.idx] . "', expecting a delimeter."
		endif
	endwhile

	echo "ITEMS: " . join(items, " " . a:delim . " ")

endfunction

function! s:consumeItem() dict
	let peek = self.peek()

	if peek == 'WORD'
		call self.nextToken()
		let item = self.tok
	elseif peek == 'QUOTE'
		let item = self.consumeQuote()
	else
		return {'str': '', 'eof': 1}
	end

	return {'str': item, 'eof': 0}
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
	return 'flabber'
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

echo s:TNT.new("abc(foo, bar)").rewriteList(",", "'", "[")
