function! s:longestMatch(pats) dict
	for pat in a:pats
		let [match_str, match_start, match_end] = matchstrpos(self.str, pat)

		if !exists('longest_match') || (match_end - match_start) > (longest_match.end - longest_match.start)
			let longest_match = {
				\ 'str': match_str,
				\ 'start': match_start,
				\ 'end': match_end 
			\ }
		endif
	endfor

	if exists('longest_match')
		return longest_match
	end
endfunction

function! s:advanceTo(pats, ...) dict
	let start_idx = self.idx

	if len(a:000) != 0
		let move_past = a:000[0]
	else
		let move_past = 0
	end

	let longest_match = self.longestMatch(a:pats)

	if string(longest_match) != ''
		if move_past
			let self.idx = longest_match.end
		else
			let self.idx = longest_match.start
		end

		return self.str[start_idx:longest_match.start - 1]
	else
		" No match was found. Don't touch the index and return an empty result.
		return ''
	endif
endfunction
