#!/usr/bin/awk -f

# Author: Vladimir Dinev
# vld.dinev@gmail.com
# 2021-06-05

function SCRIPT_NAME() {return "rdpg.awk"}
function SCRIPT_VERSION() {return "1.11"}

# <prefix_tree>
# -- prefix tree --
# Turns e.g.
# a -> b c | d e
# or, in rdpg syntax
#
# rule a
# defn b c
# defn d e
# end
#
# to
#
# tree["a"] = "b|d"
# tree["a.b"] = "c"
# tree["a.b.c"] = _end_of_path_
# tree["a.d"] = "e"
# tree["a.d.e"] = _end_of_path_
#
# etc. Function names with an "_" as their first character are 'private',
# meaning the user does not need to use them, or even know the exist.
# Variable names with an "_" as their first character means the variable is
# private to the current function, i.e. local.

function PFT_ROOT_SEP() {return "."}
function PFT_VAL_SEP() {return "|"}
function _PFT_END() {return "_end:"}
function _pft_end_str(str) {return (_PFT_END() str)}

function pft_mark_end(tree, ind) {
	tree[_pft_end_str(ind)] = 1
}
function pft_is_end_of_path(tree, ind) {
	return (_pft_end_str(ind) in tree)
}
function _pft_split(str, out_arr, sub_sep) {
	return split(str, out_arr, sub_sep)
}
function pft_split_root(root, out_arr) {
	return _pft_split(root, out_arr, PFT_ROOT_SEP())
}
function pft_split_val(val, out_arr) {
	return _pft_split(val, out_arr, PFT_VAL_SEP())
}
function pft_init(tree) {
	tree[""] = ""
	delete tree
}
function pft_has(tree, ind) {
	return (ind in tree)
}
function pft_get(tree, ind) {
	return (pft_has(tree, ind)) ? tree[ind] : ""
}
function _pft_cat(a, b, sub_sep) {
	if (!a) return b
	if (!b) return a
	return (a sub_sep b)
}
function pft_cat_root(a, b) {
	return _pft_cat(a, b, PFT_ROOT_SEP())
}
function pft_cat_val(a, b) {
	return _pft_cat(a, b, PFT_VAL_SEP())
}
function pft_arr_has(arr, len, what,    _i) {
	for (_i = 1; _i <= len; ++_i) {
		if (arr[_i] == what)
			return 1
	}
	return 0
}
function pft_add(tree, ind, val,    _tmp, _arr, _len, _add) {
	_add = val
	if (pft_has(tree, ind)) {
		_tmp = pft_get(tree, ind)
		_len = pft_split_val(_tmp, _arr)
		_add = pft_arr_has(_arr, _len, val) ? _tmp : pft_cat_val(_tmp, val)
	}
	tree[ind] = _add
}
# </prefix_tree>

# <misc>
function NULLABLE() {return "?"}
function get_last_ch(str) {return substr(str, length(str))}
function remove_last_ch(str) {return substr(str, 1, length(str)-1)}
function remove_first_field(str) {
	sub("[^[:space:]]+[[:space:]]*", "", str)
	return str
}

function save_raw_definition(rule, defn, _str) {
	_str = _B_plain_defn[rule]
	_str = sprintf("%s%s\n", _str, defn)
	_B_plain_defn[rule] = _str
}
function get_raw_defninition(rule) {return _B_plain_defn[rule]}

function null_set_place(rule) {_B_null_set[rule] = 1}
function null_set_has(rule) {return _B_null_set[rule]}
function is_rule_nullable(rule) {return null_set_has(rule)}
function rule_set_place(rule) {_B_rule_set[rule] = 1}
function rule_set_has(rule) {return _B_rule_set[rule]}
function rule_line_map_save(rule) {_B_rule_line[rule] = FNR}
function rule_line_map_get(rule) {return _B_rule_line[rule]}
function is_a_rule(str){return rule_line_map_get(str)}
function get_current_rule() {return get_rule(get_rule_count())}
function is_terminal(str) {
	return match(str, "^[[:upper:]][[:upper:][:digit:]_]*$")
}

function is_non_terminal(symb) {
	return match(symb, "^[[:lower:]][[:lower:][:digit:]_]*\\??$")
}
function rule_process_name(rule,    _rule) {
	_rule = rule
	
	if ((get_last_ch(_rule) == NULLABLE())) {
		_rule = remove_last_ch(_rule)
		null_set_place(_rule)
	}
	return _rule
}

function add_defn_to_rule(tree, rule, defn,    _root, _val, _i, _arr, _len) {
	_root = rule

	_len = split(defn, _arr)
	for (_i = 1; _i <= _len; ++_i) {
		_val = _arr[_i]		
		
		pft_add(tree, _root, _val)
		_root = pft_cat_root(_root, _val)
	}
	pft_mark_end(tree, _root)
}
function get_full_path(rule, defn,    _full_path) {
	_full_path = sprintf("%s %s", rule, defn)
	gsub("[[:space:]]+", PFT_ROOT_SEP(), _full_path)
	return _full_path
}
function get_current_defn() {return get_defn(get_defn_count())}

function goal_add(path, val) {_B_goals[path] = val}
function goal_get(path) {return _B_goals[path]}

function fail_add(path, val) {_B_fails[path] = val}
function fail_get(path) {return _B_fails[path]}

function syntax_check_rule(rule) {
	if (!is_non_terminal(rule))
		error_input(sprintf("bad rule syntax '%s'", rule))
}

function syntax_check_defn(str,    _i, _len, _arr, _tmp) {
	_len = split(str, _arr)
	for (_i = 1; _i <= _len; ++_i) {
		_tmp = _arr[_i]
		
		if (!is_non_terminal(_tmp) && !is_terminal(_tmp)) {
			error(sprintf("bad syntax: '%s' not a terminal or a non-terminal",
				_tmp))
		}
	}
	
	return str
}
# </misc>

# <left_recursion_check>
function left_rec_seen_reset() {_B_left_rec_set[""]; delete _B_left_rec_set}
function left_rec_was_seen(symb) {return _B_left_rec_set[symb] }
function left_rec_mark(symb) {_B_left_rec_set[symb] = 1}
function check_left_rec_rule(tree, rule,
    _next, _prev, _val, _arr, _len, _i, _trace) {
	
	if (!_next) {
		# first time; reset symbols, start from rule
		left_rec_seen_reset()
		_next = rule
	}
	
	if (!pft_has(tree, _next)) {
		# guard against non-existent rule
		return ""
	}
	
	if (left_rec_was_seen(_next)) {
		# _next has already been considered and did not result in an error
		return ""
	} else {
		# _next has not been considered, needs a check
		left_rec_mark(_next)
	}
	
	if (!_prev) {
		# first time; begin the trace path with the top rule
		_prev = _next
	} else {
		# not first time; add _next to the trace path
		_prev = sprintf("%s -> %s", _prev, _next)
	}
	
	_val = pft_get(tree, _next)
	_len = pft_split_val(_val, _arr)
	
	if (pft_arr_has(_arr, _len, rule)) {
		# if the top rule exists in any of its own leftmost derivations, or
		# in any of the leftmost derivations of its leftmost derivations
		# return the trace
		return sprintf("%s -> %s", _prev, _val)
	}
	
	for (_i = 1; _i <= _len; ++_i) {
		if (_trace = check_left_rec_rule(tree, rule, _arr[_i], _prev)) {
			# if a non-empty trace has occurred, we have leftmost recursion
			return _trace
		}
	}
}
function print_left_rec(rule, trace) {
	print_puts_err(sprintf("left recursion in file '%s' from line %d: %s",
		FILENAME, rule_line_map_get(rule), trace))
}
function check_left_recursion(tree,    _rule, _i, _end, _trace, _err) {
	_err = 0
	_end = get_rule_count()
	
	for (_i = 1; _i <= _end; ++_i) {
		_rule = get_rule(_i)
		
		if (_trace = check_left_rec_rule(tree, _rule)) {
			_err = 1
			print_left_rec(_rule, _trace)	
		}
	}
	
	if (_err)
		error("left recursion detected")
}
# </left_recursion_check>

# <check_reachability>
function check_reachability_rule(tree, rule, _root,    _val, _path, _err) {
	
	if (!_root)
		_root = rule
	
	if (!_err)
		_err = 0
	
	if (!pft_has(tree, _root))
		return
	
	_val = pft_get(tree, _root)
	_path = pft_cat_root(_root, _val)
	
	if (_val && pft_is_end_of_path(tree, _root)) {
		print_puts_err(\
			sprintf(\
			"file '%s', line %d, rule '%s': cannot reach definition path:",
			FILENAME, rule_line_map_get(rule), rule))
		print_puts_err(sprintf("'%s'", _path))
		print_puts_err(sprintf("'%s' already defines an end of path", _root))
		
		print_puts_err("tree dump:")
		print_tree_preorder(tree, rule)
		
		_err = 1
	}
	
	return _err + check_reachability_rule(tree, rule, _path)
}

function check_reachability(tree,    _rule, _i, _end, _err) {
	_err = 0
	_end = get_rule_count()
	
	for (_i = 1; _i <= _end; ++_i) {
		_rule = get_rule(_i)
		_err = check_reachability_rule(tree, _rule)
	}
	
	if (_err)
		error("unreachable paths detected")
}
# </check_reachability>

# <check_undefined_rules>
function check_undefined_rule(tree, rule,    _root, _i, _val, _arr_val,
_len_val, _symb, _err) {
	
	if (!_err)
		_err = 0
	
	if (!_root)
		_root = rule

	if (!pft_has(tree, _root))
		return 0
	
	_val = pft_get(tree, _root)
	_len_val = pft_split_val(_val, _arr_val)
	
	for (_i = 1; _i <= _len_val; ++_i) {
		_symb = _arr_val[_i]
		
		if (!is_terminal(_symb) && !is_a_rule(_symb)) {
			print_puts_err(\
			sprintf(\
			"file '%s', line %d, rule '%s' calls a non-defined rule '%s'",
			FILENAME,  rule_line_map_get(rule), rule, _symb))
			
			_err = 1
		}
		
		_err += check_undefined_rule(tree, rule, pft_cat_root(_root, _symb))
	}
	
	return _err
}

function check_undefined_rules(tree,    _rule, _i, _end, _err) {
	_err = 0
	_end = get_rule_count()
	
	for (_i = 1; _i <= _end; ++_i) {
		_rule = get_rule(_i)
		_err += check_undefined_rule(tree, _rule)
	}
	
	if (_err)
		error("undefined rules detected")
}
# </check_undefined_rules>

# <user_api>
# <user_events>
function on_rule(    _rule) {
	data_or_err()
	
	_rule = remove_first_field($0)
	syntax_check_rule(_rule)
	_rule = rule_process_name(_rule)
	
	save_raw_definition(_rule, $0)
	
	if (rule_set_has(_rule))
		error_input(sprintf("rule '%s' redefined", _rule))
	else
		rule_set_place(_rule)
		
	rule_line_map_save(_rule)
	save_rule(_rule)
}

function on_defn(    _rule, _defn, _full_path) {
	data_or_err()
	
	_rule = get_current_rule()
	save_raw_definition(_rule, $0)
	
	_defn = remove_first_field($0)
	_defn = syntax_check_defn(_defn)
	_full_path = get_full_path(_rule, _defn)
	
	save_defn(_full_path)
	add_defn_to_rule(G_tree, _rule, _defn)
}

function on_goal() {
	data_or_err()
	#save_on_match($2)
	
	goal_add(get_current_defn(), remove_first_field($0))
}

function on_fail() {
	data_or_err()
	#save_on_nomatch($2)

	fail_add(get_current_rule(), remove_first_field($0))
}

function on_end() {
	#data_or_err()
	#save_end($2)
	
	reset_defn()
	reset_goal()
	reset_fail()
}

function init() {
	if (Help)
		print_help()
	if (Version)
		print_version()
	if (Example)
		print_example()
	if (ARGC != 2)
		print_use_try()
	Strict = (Strict) ? Strict : ""
	
	# G_tree has to be a global variable
	pft_init(G_tree)
}

function on_BEGIN() {
	init()
}

function perform_input_checks(tree) {
	if (Strict)
		check_undefined_rules(tree)
	check_reachability(tree)
	check_left_recursion(tree)
}

function print_tree() {
	_end = get_rule_count()
	for (_i = 1; _i <= _end; ++_i)
		print_tree_preorder(G_tree, get_rule(_i))
}

function on_END(    _i, _end) {
	perform_input_checks(G_tree)
	generate_ir(G_tree)
}


function print_tree_preorder(tree, root,    _lvl, _i, _j, _val,
_arr_val, _len_val, _arr_root, _len_root) {
	
	if (pft_is_end_of_path(tree, root))
			print_puts_err(sprintf("tree[\"%s\"] = _end_of_path_", root))
	
	if (pft_has(tree, root)) {
		_val = pft_get(tree, root)
		_len_root = pft_split_root(root, _arr_root)
		_len_val = pft_split_val(_val, _arr_val)
		
		print_puts_err(sprintf("tree[\"%s\"] = \"%s\"", root, _val))
		
		for (_i = 1; _i <= _len_val; ++_i)
			print_tree_preorder(tree, pft_cat_root(root, _arr_val[_i]))
	}
}

function emit_func(str) {print_ind_line(sprintf("%s %s", IR_FUNC(), str))}
function emit_func_end() {print_ind_line(IR_FUNC_END())}
function emit_call(str) {print_ind_line(sprintf("%s %s", IR_CALL(), str))}
function emit_if(str) {
	print_ind_line(sprintf("%s %s %s", IR_IF(), IR_CALL(), str))
}
function emit_else_if(str) {
	print_ind_line(sprintf("%s %s %s", IR_ELSE_IF(), IR_CALL(), str))
}
function emit_else(str) {print_ind_line(IR_ELSE())}
function emit_return(str) {print_ind_line(sprintf("%s %s", IR_RETURN(), str))}

function expose_return(str,    _arr, _tmp, _ret) {
	# expose the return only if it has valid IR syntax, so it can be considered
	# in the optimization stage
	
	_ret = str
	
	split(str, _arr)
	_tmp = _arr[1]
	if (IR_GOAL() == _tmp || IR_FAIL() == _tmp) {
		_tmp = _arr[2]
		if (IR_RETURN() == _tmp) {
			_tmp = _arr[3]
			if (IR_TRUE() == _tmp || IR_FALSE() == _tmp || IR_CALL() == _tmp)
				_ret = remove_first_field(str)
		}
	}

	return _ret
}
function emit_goal(str) {
	print_ind_line(sprintf("%s",
		expose_return(sprintf("%s %s", IR_GOAL(), str))))
}
function emit_fail(str) {
	print_ind_line(sprintf("%s",
		expose_return(sprintf("%s %s", IR_FAIL(), str))))
}

function emit_comment(str) {print_puts(sprintf("%s %s", IR_COMMENT(), str))}
function emit_block_open(fname) {
	print_ind_line(sprintf("%s %s_%d", IR_BLOCK_OPEN(), fname, ++_B_n))
	print_inc_indent()
}
function emit_block_close(fname) {
	print_dec_indent()
	print_ind_line(sprintf("%s %s_%d", IR_BLOCK_CLOSE(), fname, _B_n--))
}

function get_list_of_terminals(arr, len,    _symb, _i, _count, _str) {
	_count = 0
	_str = ""
	for (_i = 1; _i <= len; ++_i) {
		_symb = arr[_i]
		if (is_terminal(_symb)) {
			++_count
			_str = sprintf("%s%s ", _str, _symb)
		}
	}
	return (_count) ? sprintf("%d %s", _count, _str) : ""
}
function did_only_nullables_fail(arr, len,    _i) {
	for (_i = 1; _i <= len; ++_i) {	
		if (!is_rule_nullable(arr[_i]))
			return 0
	}
	return 1
}

function tok_match_call(val) {return sprintf("%s %s", IR_TOK_MATCH(), val)}

function generate_ir_rule(tree, rule,    _current, _path, _i, _val, _arr_val,
_len_val, _is_term, _has, _is_last, _symb) {
	
	if (!_current) # first time
		_current = rule
	
	if (!pft_has(tree, _current))
		return
	
	_val = pft_get(tree, _current)
	_len_val = pft_split_val(_val, _arr_val)
	
	for (_i = 1; _i <= _len_val; ++_i) {
		_val = _arr_val[_i]
		_is_term = is_terminal(_val)
		
		# if the current symbol is a terminal, make a tok_match call
		# else make an ordinary function call
		_symb = (_is_term) ? tok_match_call(_val) : _val
		
		if (_i == 1)
			emit_if(_symb)        # if
		else 
			emit_else_if(_symb)   # else if
			
		emit_block_open(rule)         # {
		
		_path = pft_cat_root(_current, _val) # current path and value is 
		                                     # exactly where we are
		
		_is_last = pft_is_end_of_path(tree, _path) # are we at the last call of
		                                           # a definition?
		
		if (_is_last) {                # if last call of definition
			_has = goal_get(_path)     # and a goal was defined
			if (_has)
				emit_goal(_has)        # execute the definition goal
		
			if (_is_term)
				emit_call(IR_TOK_NEXT()) # consume the token after tok_match

			emit_return(IR_TRUE())       # definition match successful
		
		} else {
			if (_is_term)                # not last call of definition
				emit_call(IR_TOK_NEXT()) # consume the token after tok_match
			
			generate_ir_rule(tree, rule, _path)  # the same thing again until
			                                     # the end of the definition
			                                     # is reached
		}
		
		emit_block_close(rule)    # }
	}

	emit_else()                   # else
	emit_block_open(rule)         # {
	
	if (!is_rule_nullable(rule)) {    # if the rule has no epsilon production
	                                  # it can produces errors; otherwise not
	                                  
		_has = get_list_of_terminals(_arr_val, _len_val)
		if (_has)
			emit_call(sprintf("%s %s", IR_TOK_ERR(), _has))
	}
	
	_has = fail_get(_current)         # execute rule failure procedure
	if (_has)
		emit_fail(_has)
	                                  # if all calls up the same level of the if
	                                  # chain had epsilon productions, return
	                                  # true, since returning false could
	                                  # trigger an error further up the chain;
	                                  # epsilon productions trigger no errors on
	                                  # failure by definition
	
	emit_return(did_only_nullables_fail(_arr_val, _len_val) ?
		IR_TRUE() : IR_FALSE())
	emit_block_close(rule)        # }
}

function definition_comment(rule, _str) {

	_str = get_raw_defninition(rule)
	sub("\n$", "", _str)
	gsub("\n", "\ncomment ", _str)
	return _str
}
function generate_ir(tree,    _rule, _i, _end) {

	emit_comment(sprintf("generated by %s %s",
		SCRIPT_NAME(), SCRIPT_VERSION()))

	_end = get_rule_count()
	for (_i = 1; _i <= _end; ++_i) {
		_rule = get_rule(_i)
			
		emit_func(_rule)                         # function _rule()
		emit_block_open(_rule)                   # {
		emit_comment(definition_comment(_rule))  # rule definition comment
		
		if (1 == _i)                             # start the tokenizer if first
			emit_call(IR_TOK_NEXT())             # call in the parsing process
		
		generate_ir_rule(tree, _rule)            # generate the function content
		
		emit_block_close(_rule)                  # }
		emit_func_end() # mark end of func, so it becomes a paragraph
	}
}

# <user_messages>
function RDPG_IR() {return "rdpg_ir.awk"}
function use_str() {
	return sprintf("Use: awk -f %s -f %s <input-file>",
		RDPG_IR(), SCRIPT_NAME())
}

function print_use_try() {
	print_puts_err(use_str())
	print_puts_err(sprintf("Try '%s -vHelp=1' for more info", SCRIPT_NAME()))
	exit_failure()
}

function print_version() {
	print_puts(sprintf("%s %s", SCRIPT_NAME(), SCRIPT_VERSION()))
	exit_success()
}

function STRICT() {return "-vStrict=1"}
function EXAMPLE() {return "-vExample=1"}
function print_help() {
print sprintf("--- %s %s ---", SCRIPT_NAME(), SCRIPT_VERSION())
print "LL(1) recursive descent parser generator"
print ""
print use_str()
print ""
print "Options:"
print sprintf("%s  - any reference to a non-defined CFG rule is an error", STRICT())
print sprintf("%s - print infix calculator example", EXAMPLE())
print "-vHelp=1    - print this screen"
print "-vVersion=1 - print version"
print ""
print sprintf("%s itself is a line oriented state machine parser which parses",
	SCRIPT_NAME())
print "by the rules described below. Note: these rules are different in meaning"
print "than the rules in the context of context free grammars. Unlike CFG rules,"
print "these only describe the sequence in which they must themselves appear in"
print "the input file."
print ""
print "Rules:"
print "'->' means 'must be followed by'"
print "'|'  means 'or'"
print "Each line of the input file must begin with a rule."
print "The rules must appear in the below order of definition."
print "Empty lines and lines which start with '#' are ignored."
print ""
print "rule -> defn"
print "defn -> defn | goal | fail | end"
print "goal -> defn | fail | end"
print "fail -> end"
print "end -> rule"
print ""
print "Here's how the above is used to describe a context free grammar:"
print "Note: the below is only a demonstration. The grammar doesn't really make sense."
print sprintf("For a grammar which does, please run with the %s flag.", EXAMPLE())
print ""
print "expression := term expr_rest"
print "term := NUMBER"
print "expr_rest := plus_minus_term expr_rest"
print "plus_minus_term := PLUS term | MINUS term | eps"
print ""
print sprintf("in %s syntax becomes:", SCRIPT_NAME())
print ""
print "rule expression"
print "defn term expr_rest"
print "end"
print "rule term"
print "defn NUMBER"
print "end"
print "rule expr_rest"
print "defn plus_minus_term expr_rest"
print "end"
print "rule plus_minus_term?"
print "defn PLUS term"
print "defn MINUS term"
print "end"
print ""
print "Note that an epsilon transition is marked by a '?' after the rule name."
print "This makes it easier for the line parser to parse. A goal can be"
print "associated with each definition. A goal is an action, usually a function"
print "call, which is executed after a successful match of the definition:"
print ""
print "rule plus_minus_term?"
print "defn PLUS term"
print "goal add()"
print "defn MINUS term"
print "goal sub()"
print "end"
print ""
print "Similarly, a single fail action can be associated with a rule:"
print ""
print "rule plus_minus_term?"
print "defn PLUS term"
print "goal add()"
print "defn MINUS term"
print "goal sub()"
print "fail exit(EXIT_FAILURE)"
print "end"
print ""
print "This fail action gets executed if none of the defn were matched."
print sprintf("%s detects left recursion and is language agnostic. It compiles", 
	SCRIPT_NAME())
print "it's input to an intermediate representation, the definition of which can"
print sprintf("be found in %s. This intermediate representation output can then",
	RDPG_IR())
print "be piped into the optimizer - rdpg-opt.awk, which, depending on the"
print "optimization level, can replace naive code like 'if (foo()) {return true}"
print "else {return false}' with something more succinct like 'return foo()'. It"
print "can also get rid of redundant elses, unreachable code (defined as any code"
print "between the first return statement in the current block and the end of the"
print "same block), optimize tail recursion, and inline functions. If optimization"
print "is used, the output of the optimizer is again ir code. Ultimately, the ir"
print "is fed into some back end, like rdpg-to-c.awk, which translates it to the"
print "target language. This translation is more or less trivial, as is writing"
print "a custom back end for a desired target language. Note that in order to have"
print "a language agnostic grammar, the goal and fail actions should be written in"
print "ir as well. E.g."
print ""
print "rule plus_minus_term?"
print "defn PLUS term"
print "goal call add"
print "defn MINUS term"
print "goal call sub"
print "fail call exit EXIT_FAILURE"
print "end"
print ""
print "Similarly:"
print ""
print "rule statement"
print "defn expression SEMI"
print "fail return sync_on(SEMI)"
print "end"
print ""
print "Becomes:"
print ""
print "rule statement"
print "defn expression SEMI"
print "fail return call sync_on SEMI"
print "end"
print ""
print "Note that in the rdpg language, any lower case symbol is a non-terminal,"
print "which gets translated to a function call. Any upper case symbol is a token,"
print "which gets translated to a token matching functions. " SCRIPT_NAME() " assumes the"
print "existence of three token related functions - one for consuming a token, one for"
print "matching the current token to an expected token, and one for reporting mismatch"
print "errors. A mismatch error is generally supposed to have the form of 'expected X,"
print "got Y instead'. The assumed names of the three functions can be found in the"
print "IR_TOK_* constants."
print ""
print "It's worth mentioning that if a rule is nullable, i.e. if it ends with a"
print "'?', this in practice means that:"
print "a) token mismatches do not generate errors inside that rule"
print "b) the caller rule always returns true whether or not the nullable rule failed,"
print "given that the nullable rule is the only call, i.e. it's not a part of an if"
print "chain of calls. This is because making a rule nullable makes it optional, i.e."
print "it's ok not to match."
exit_success()
}

function print_example() {
print "# start symbol"
print "rule parse"
print "defn statements"
print "end"
print ""
print "rule statements"
print "defn statement eoi"
print "defn statement statements"
print "end"
print ""
print "rule eoi?"
print "defn EOI"
print "end"
print ""
print "# if parsing an expression failed, eat tokens until you see ';'"
print "rule statement"
print "defn expression_sync"
print "fail return call sync SEMI"
print "end"
print ""
print "# intermediate rule, so expression can fail at a single point"
print "rule expression_sync"
print "defn expression SEMI"
print "end"
print ""
print "rule expression"
print "defn term expr_rest"
print "end"
print ""
print "rule expr_rest"
print "defn plus_minus_term expr_rest"
print "end"
print ""
print "# it's ok to not have addition or subtraction in an expression"
print "rule plus_minus_term?"
print "defn PLUS term"
print "goal call add"
print "defn MINUS term"
print "goal call subt"
print "end"
print ""
print "rule term"
print "defn factor term_tail"
print "end"
print ""
print "rule term_tail"
print "defn div_mul_factor term_tail"
print "end"
print ""
print "# it's ok to not have multiplication or division in an expression"
print "rule div_mul_factor?"
print "defn MUL factor"
print "goal call mult"
print "defn DIV factor"
print "goal call divd"
print "end"
print ""
print "rule factor"
print "defn base expon"
print "end"
print ""
print "# right associative"
print "rule expon?"
print "defn EXP factor"
print "goal call power"
print "end"
print ""
print "rule base"
print "defn single NUMBER"
print "goal call push_val"
print "defn NUMBER"
print "goal call push_val"
print "defn LPAR expression RPAR"
print "end"
print ""
print "# optional negation"
print "rule single?"
print "defn MINUS"
print "goal call neg"
print "defn PLUS"
print "end"
	exit_success()
}
# </user_messages>
# </user_events>

# <user_print>
function print_ind_line(str, tabs) {print_tabs(tabs); print_puts(str)}
function print_ind_str(str, tabs) {print_tabs(tabs); print_stdout(str)}
function print_inc_indent() {print_set_indent(print_get_indent()+1)}
function print_dec_indent() {print_set_indent(print_get_indent()-1)}
function print_tabs(tabs,	 i, end) {
	end = tabs + print_get_indent()
	for (i = 1; i <= end; ++i)
		print_stdout("\t")
}
function print_new_lines(num,    i) {
	for (i = 1; i <= num; ++i)
		print_stdout("\n")
}

function print_set_indent(tabs) {__indent_count__ = tabs}
function print_get_indent(tabs) {return __indent_count__}
function print_puts(str) {__print_puts(str)}
function print_puts_err(str) {__print_puts_err(str)}
function print_stdout(str) {__print_stdout(str)}
function print_stderr(str) {__print_stderr(str)}
function print_set_stdout(str) {__print_set_stdout(str)}
function print_set_stderr(str) {__print_set_stderr(str)}
function print_get_stdout() {return __print_get_stdout()}
function print_get_stderr() {return __print_get_stderr()}
# </user_print>

# <user_error>
function error(msg) {__error(msg)}
function error_input(msg) {__error_input(msg)}
# </user_error>

# <user_exit>
function exit_success() {__exit_success()}
function exit_failure() {__exit_failure()}
# </user_exit>

# <user_utils>
function data_or_err() {
	if (NF < 2)
		error_input(sprintf("no data after '%s'", $1))
}

function reset_all() {
	reset_rule()
	reset_defn()
	reset_goal()
	reset_fail()
	reset_end()
}

function get_last_rule() {return __state_get()}

function save_rule(rule) {__rule_arr__[++__rule_num__] = rule}
function get_rule_count() {return __rule_num__}
function get_rule(num) {return __rule_arr__[num]}
function reset_rule() {delete __rule_arr__; __rule_num__ = 0}

function save_defn(defn) {__defn_arr__[++__defn_num__] = defn}
function get_defn_count() {return __defn_num__}
function get_defn(num) {return __defn_arr__[num]}
function reset_defn() {delete __defn_arr__; __defn_num__ = 0}

function save_goal(goal) {__goal_arr__[++__goal_num__] = goal}
function get_goal_count() {return __goal_num__}
function get_goal(num) {return __goal_arr__[num]}
function reset_goal() {delete __goal_arr__; __goal_num__ = 0}

function save_fail(fail) {__fail_arr__[++__fail_num__] = fail}
function get_fail_count() {return __fail_num__}
function get_fail(num) {return __fail_arr__[num]}
function reset_fail() {delete __fail_arr__; __fail_num__ = 0}

function save_end(end) {__end_arr__[++__end_num__] = end}
function get_end_count() {return __end_num__}
function get_end(num) {return __end_arr__[num]}
function reset_end() {delete __end_arr__; __end_num__ = 0}
# </user_utils>
# </user_api>
#==============================================================================#
#                        machine generated parser below                        #
#==============================================================================#
# <gen_parser>
# <gp_print>
function __print_set_stdout(f) {__gp_fout__ = ((f) ? f : "/dev/stdout")}
function __print_get_stdout() {return __gp_fout__}
function __print_stdout(str) {__print(str, __print_get_stdout())}
function __print_puts(str) {__print_stdout(sprintf("%s\n", str))}
function __print_set_stderr(f) {__gp_ferr__ = ((f) ? f : "/dev/stderr")}
function __print_get_stderr() {return __gp_ferr__}
function __print_stderr(str) {__print(str, __print_get_stderr())}
function __print_puts_err(str) {__print_stderr(sprintf("%s\n", str))}
function __print(str, file) {printf("%s", str) > file}
# </gp_print>
# <gp_exit>
function __exit_skip_end_set() {__exit_skip_end__ = 1}
function __exit_skip_end_clear() {__exit_skip_end__ = 0}
function __exit_skip_end_get() {return __exit_skip_end__}
function __exit_success() {__exit_skip_end_set(); exit(0)}
function __exit_failure() {__exit_skip_end_set(); exit(1)}
# </gp_exit>
# <gp_error>
function __error(msg) {
	__print_puts_err(sprintf("%s: error: %s", SCRIPT_NAME(), msg))
	__exit_failure()
}
function __error_input(msg) {
	__error(sprintf("file '%s', line %d: %s", FILENAME, FNR, msg))
}
function GP_ERROR_EXPECT() {return "'%s' expected, but got '%s' instead"}
function __error_parse(expect, got) {
	__error_input(sprintf(GP_ERROR_EXPECT(), expect, got))
}
# </gp_error>
# <gp_state_machine>
function __state_set(state) {__state__ = state}
function __state_get() {return __state__}
function __state_match(state) {return (__state_get() == state)}
function __state_transition(_next) {
	if (__state_match("")) {
		if (__R_RULE() == _next) __state_set(_next)
		else __error_parse(__R_RULE(), _next)
	}
	else if (__state_match(__R_RULE())) {
		if (__R_DEFN() == _next) __state_set(_next)
		else __error_parse(__R_DEFN(), _next)
	}
	else if (__state_match(__R_DEFN())) {
		if (__R_DEFN() == _next) __state_set(_next)
		else if (__R_GOAL() == _next) __state_set(_next)
		else if (__R_FAIL() == _next) __state_set(_next)
		else if (__R_END() == _next) __state_set(_next)
		else __error_parse(__R_DEFN()"|"__R_GOAL()"|"__R_FAIL()"|"__R_END(), _next)
	}
	else if (__state_match(__R_GOAL())) {
		if (__R_DEFN() == _next) __state_set(_next)
		else if (__R_FAIL() == _next) __state_set(_next)
		else if (__R_END() == _next) __state_set(_next)
		else __error_parse(__R_DEFN()"|"__R_FAIL()"|"__R_END(), _next)
	}
	else if (__state_match(__R_FAIL())) {
		if (__R_END() == _next) __state_set(_next)
		else __error_parse(__R_END(), _next)
	}
	else if (__state_match(__R_END())) {
		if (__R_RULE() == _next) __state_set(_next)
		else __error_parse(__R_RULE(), _next)
	}
}
# </gp_state_machine>
# <gp_awk_rules>
function __R_RULE() {return "rule"}
function __R_DEFN() {return "defn"}
function __R_GOAL() {return "goal"}
function __R_FAIL() {return "fail"}
function __R_END() {return "end"}

$1 == __R_RULE() {__state_transition($1); on_rule(); next}
$1 == __R_DEFN() {__state_transition($1); on_defn(); next}
$1 == __R_GOAL() {__state_transition($1); on_goal(); next}
$1 == __R_FAIL() {__state_transition($1); on_fail(); next}
$1 == __R_END() {__state_transition($1); on_end(); next}
$0 ~ /^[[:space:]]*$/ {next} # ignore empty lines
$0 ~ /^[[:space:]]*#/ {next} # ignore comments
{__error_input(sprintf("'%s' unknown", $1))} # all else is error

function __init() {
	__print_set_stdout()
	__print_set_stderr()
	__exit_skip_end_clear()
}
BEGIN {
	__init()
	on_BEGIN()
}

END {
	if (!__exit_skip_end_get()) {
		if (__state_get() != __R_END())
			__error_parse(__R_END(), __state_get())
		else
			on_END()
	}
}
# </gp_awk_rules>
# </gen_parser>

# <user_input>
# Command line:
# -vScriptName=rdpg.awk
# -vScriptVersion=1.0
# Rules:
# rule -> defn
# defn -> defn | goal | fail | end
# goal -> defn | fail | end
# fail -> end
# end -> rule
# </user_input>
# generated by scriptscript.awk 2.211
