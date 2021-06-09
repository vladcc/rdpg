#!/usr/bin/awk -f

# Author: Vladimir Dinev
# vld.dinev@gmail.com
# 2021-06-10

# <script>
function SCRIPT_NAME() {return "rdpg-to-awk.awk"}
function SCRIPT_VERSION() {return "1.02"}
# </script>

# <input>
function save_line(str) {_B_input[++_B_n] = str}
function get_line(n) {return _B_input[n]}
function get_line_count() {return _B_n}
function copy_input(arr_out,    _i, _end) {
	delete arr_out
	
	_end = get_line_count()
	for (_i = 1; _i <= _end; ++_i)
		arr_out[_i] = get_line(_i)
	
	return _end
}
# </input>

# <awk_rules>
function init() {
	if (Help)
		print_help()
	if (Version)
		print_version()
		
	npref_set(TokCallPrefix)
}
BEGIN {
	init()
}
{save_line($0)}
END {
	if (!skip_end_get())
		emit_awk()
}
# </awk_rules>

#<misc>
function remove_first_field(str) {
	sub("[^[:space:]]+[[:space:]]*", "", str)
	return str
}
function get_field(str, n,    _arr) {
	split(str, _arr)
	return _arr[n]
}

function error(str) {
	print sprintf("%s: error: %s", SCRIPT_NAME(), str) > "/dev/stderr"
	exit(1)
}

function is(a, b) {return (a == b)}
function npref_set(str) {_B_npref = str}
function npref_get() {return _B_npref}
#</misc>

# <output>
function add_tab() {++_B_tabs}
function sub_tab() {--_B_tabs}
function get_tab() {return _B_tabs}
function out_tabs(str,    _i, _end) {
	_end = get_tab()
	for (_i = 1; _i <= _end; ++_i)
		printf("\t")
	printf("%s", str)
}

function out_str(str) {out_tabs(str)}
function out_line(str){out_tabs(str); print ""}

function new_line() {print ""}
function _ARR() {return "_arr"}
function get_fstr(fname) {
	return sprintf("function %s(    %s) {", fname, _ARR())
}
function emit_func(fname) {
	out_line(get_fstr(fname))
}
function emit_loop_start() {out_line("while (1) {")}
function emit_block_open() {out_line("{"); add_tab()}
function emit_block_close() {sub_tab(); out_line("}")}
function emit_else() {out_str("} else {")}
function emit_return() {out_str("return ")}
function emit_goal(str) {out_str(str)}
function emit_fail(str) {out_str(str)}
function emit_call(str,    _i, _len, _arr, _fname, _how_many, _is_tok_err) {
	_len = split(str, _arr)
	_fname = _arr[2]
	_is_tok_err =  0

	if (is(_fname, IR_TOK_ERR()) ||
		is(_fname, IR_TOK_NEXT()) ||
		is(_fname, IR_TOK_MATCH())) {

		_is_tok_err = is(_fname, IR_TOK_ERR())

		_fname = (npref_get() _fname)
	}
	
	if (_is_tok_err) {
		_how_many = _arr[3]
		for (_i = 1; _i <= _how_many; ++_i) {
			print sprintf("%s[%d] = %s()", _ARR(), _i, _arr[3+_i])
			out_tabs()
		}
		printf("%s(%s, %d)", _fname, _ARR(), _how_many)
	} else {
		printf("%s(", _fname)
		for (_i = 3; _i <= _len; ++_i) {
			printf("%s()", _arr[_i])
			if (_i < _len)
				printf(", ")
		}
		printf(")")
	}
}
function emit_if(str) {
	printf("if (")
	emit_call(remove_first_field(str))
	printf(") {")
	new_line()
}
function emit_else_if(str) {
	out_str("} else ")
	emit_if(str)
}
function emit_comment(str) {
	sub("^comment", "#", str)
	sub_tab()
	out_line(str)
	add_tab()
}
function emit_continue() {out_str(IR_CONTINUE())}
function emit_pass_through(str) {print str} # debug

function ADD_TAB() {return "foo"}
function emit_defn(arr_code, len,    _i, _arr_line, _instr, _line, _tmp) {
	
	for (_i = 1; _i <= len; ++_i) {
		_line = arr_code[_i]
		
		if (is(ADD_TAB(), _line)) {
			add_tab()
			continue
		} 
		
		split(_line, _arr_line)
		
		_instr = _arr_line[1]
		if (is(_instr, IR_FUNC())) {
			arr_code[_i+1] = ADD_TAB()
			emit_func(_arr_line[2])
		} else if (is(_instr, IR_LOOP_START())) {
			arr_code[_i+1] = ADD_TAB()
			emit_loop_start()
		} else if (is(_instr, IR_LOOP_END())) {
			continue
		} else if (is(_instr, IR_BLOCK_OPEN())) {
			emit_block_open()
		} else if (is(_instr, IR_BLOCK_CLOSE())) {
			if (!is(IR_ELSE(), get_field(arr_code[_i+1], 1)) &&
				!is(IR_ELSE_IF(), get_field(arr_code[_i+1], 1)))
				emit_block_close()
			else
				sub_tab()
		} else if (is(_instr, IR_CALL())) {
			out_tabs()
			emit_call(_line)
			new_line()
		} else if (is(_instr, IR_IF())) {
			arr_code[_i+1] = ADD_TAB()
			out_tabs()
			emit_if(_line)
		} else if (is(_instr, IR_ELSE_IF())) {
			arr_code[_i+1] = ADD_TAB()
			emit_else_if(_line)
		} else if (is(_instr, IR_ELSE())) {
			arr_code[_i+1] = ADD_TAB()
			emit_else()
			new_line()
		} else if (is(_instr, IR_RETURN())) {
			emit_return()
			if (is(_arr_line[2], IR_CALL())) {
				sub(IR_RETURN(), "", _line)
				emit_call(_line)
			} else if (is(_arr_line[2], IR_TRUE()) ||
				is(_arr_line[2], IR_FALSE())) {
				printf("%s", is(IR_TRUE(), _arr_line[2]) ? 1 : 0)
			}
			new_line()
		} else if (is(_instr, IR_CONTINUE())) {
			emit_continue()
			new_line()
		} else if (is(_instr, IR_GOAL())) {
		
			if (is(_arr_line[2], IR_CALL())) {
				sub(IR_GOAL(), "", _line)
				out_tabs()
				emit_call(_line)
			} else {
				emit_goal(_arr_line[2])
			}
			new_line()
			
		} else if (is(_instr, IR_FAIL())) {

			if (is(_arr_line[2], IR_CALL())) {
				sub(IR_FAIL(), "", _line)
				out_tabs()
				emit_call(_line)
			} else {
				emit_fail(_arr_line[2])
			}
			new_line()
		} else if (is(_instr, IR_COMMENT())) {
			emit_comment(_line)
		} else if (is(_instr, IR_PASS_THROUGH())) {
			emit_pass_through(_line)
		} else if (is(_instr, IR_FUNC_END())) {
			continue
		} else {
			error(sprintf("unknown instruction '%s'", _instr))
		}
	}
}

function emit_awk(    _arr_code, _len) {
	
	_len = copy_input(_arr_code)
	
	emit_comment(sprintf("%s <definitions>", IR_COMMENT()))
	emit_comment(sprintf("%s translated by %s %s",
		IR_COMMENT(), SCRIPT_NAME(), SCRIPT_VERSION()))
	
	emit_defn(_arr_code, _len)
	
	emit_comment(sprintf("%s </definitions>", IR_COMMENT()))
}
# <user_messages>
function skip_end_set() {_B_skip_end = 1}
function skip_end_get() {return _B_skip_end}
function exit_skip_end() {
	skip_end_set()
	exit(0)
}

function print_version() {
print sprintf("%s %s", SCRIPT_NAME(), SCRIPT_VERSION())
	exit_skip_end()
}

function RDPG_IR() {return "rdpg_ir.awk"}
function print_help() {
print sprintf("--- %s %s ---", SCRIPT_NAME(), SCRIPT_VERSION())
print "Translates rdpg intermediate representation to awk"
print ""
print "Use:"
print sprintf("... | awk -f %s -f %s [opts...]", RDPG_IR(), SCRIPT_NAME())
print ""
print "Options:"
print "-vTokCallPrefix=<prefix> - adds a prefix to all tok_*() calls; e.g."
print "-vTokCallPrefix='foo_' results in foo_tok_*()"
print "-vHelp=1    - print this screen"
print "-vVersion=1 - print version"
	exit_skip_end()
}
# </user_messages>
# </output>
