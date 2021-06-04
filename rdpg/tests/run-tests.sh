#!/bin/bash

readonly G_AWK="awk"
readonly G_TEST_GEN="./test_generate.txt"
readonly G_RDPG_IR="../rdpg_ir.awk"
readonly G_RDPG="../rdpg.awk"
readonly G_TEST_RES="./test_results.txt"
readonly G_RDPG_OPT="../rdpg-opt.awk"
readonly G_EXAMPLE="../examples/infix_calc_grammar.txt"

function test_all
{
	version_checks
	test_bug_fixes
	test_rdpg
	test_rdpg_opt
	test_end_to_end	"$@"
}

# <version_checks>
function version_checks
{
	local L_TO_C="../rdpg-to-c.awk"
	local L_TO_AWK="../rdpg-to-awk.awk"
	
	diff_ "<(awk -f $G_RDPG -vVersion=1)" "<(echo 'rdpg.awk 1.11')"
	diff_ "<(awk -f $G_RDPG_OPT -vVersion=1)" "<(echo 'rdpg-opt.awk 1.1')"
	diff_ "<(awk -f $L_TO_C -vVersion=1)" "<(echo 'rdpg-to-c.awk 1.01')"
	diff_ "<(awk -f $L_TO_AWK -vVersion=1)" "<(echo 'rdpg-to-awk.awk 1.01')"
}
# </version_checks>

# <test_bug_fixes>
function test_bug_fixes
{
	opt_olvl_3_inf_loop_fix
	pft_add_bug_fix
}
function opt_olvl_3_inf_loop_fix
{
	local L_RUN=\
"$G_AWK -f $G_RDPG_IR -f $G_RDPG ./test_rdpg/test_rdpg_opt_olvl3_inf_loop.txt"\
" | $G_AWK -f $G_RDPG_IR -f $G_RDPG_OPT -vOlvl=3"

	diff_ "<($L_RUN)" "./test_rdpg/accept_rdpg_opt_olvl3_inf_loop.txt"
}
function pft_add_bug_fix
{
	local L_RUN="$G_AWK -f $G_RDPG_IR -f $G_RDPG"
	
	diff_ "<($L_RUN ./test_rdpg/test_pft_add_bug_fix.txt)" \
		"./test_rdpg/accept_pft_add_bug_fix.txt"
}
# </test_bug_fixes>

# <test_end_to_end>
function test_end_to_end
{
	bt_eval "bash ../examples/run.sh $@"
	bt_assert_success
}
# </test_end_to_end>

# <test_rdpg_opt>
function run_rdpg_opt
{
	local L_FILE="$1"
	shift
	
	local L_AUX="$@"
	local L_RUN="$G_AWK -f $G_RDPG_IR -f $G_RDPG_OPT $L_AUX"
	run_rdpg "$L_FILE" | bt_eval "$L_RUN"
}

function test_rdpg_opt
{
	test_rdpg_opt_olvl_0
	test_rdpg_opt_olvl_1
	test_rdpg_opt_olvl_2
	test_rdpg_opt_olvl_3
	test_rdpg_opt_olvl_4
	test_rdpg_opt_olvl_5
}

function test_rdpg_opt_olvl_5
{
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=5 -vInlineLength=1" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_5.txt"
	
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=5" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_5_default_inline_len.txt"
	
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=5 -vInlineLength=29" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_5_inline_len_29.txt"
}

function test_rdpg_opt_olvl_4
{
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=4" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_4.txt"
}

function test_rdpg_opt_olvl_3
{
	# Remove unreachable code is probably not necessary because of redundant
	# else removal, so no positive test, unfortunately.
	# This test confirms it doesn't break olvl 2.
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=3" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_3.txt"
}

function test_rdpg_opt_olvl_2
{
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=2" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_2.txt"
}

function test_rdpg_opt_olvl_1
{
	run_rdpg_opt "$G_TEST_GEN" "-vOlvl=1" " > $G_TEST_RES"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_1.txt"
}

function test_rdpg_opt_olvl_0
{
	run_rdpg_opt "$G_TEST_GEN" " > $G_TEST_RES" "2>&1"
	bt_assert_success
	diff_result "./test_rdpg_opt/accept_olvl_0.txt"
}
# </test_rdpg_opt>

# <test_rdpg>
function run_rdpg
{
	local L_AUX="$@"
	local L_RUN="$G_AWK -f $G_RDPG_IR -f $G_RDPG $L_AUX"
	eval "$L_RUN"
}

function test_rdpg
{
	test_rdpg_strict_undefn_rule
	test_rdpg_example
	test_rdpg_left_recursion_direct
	test_rdpg_left_recursion_indirect
	test_rdpg_generate
}

function test_rdpg_example
{
	diff_ <(run_rdpg "-vExample=1") "$G_EXAMPLE"
}

function test_rdpg_generate
{
	local L_ACCEPT_GEN="./test_rdpg/accept_generate.txt"
	
	run_rdpg "$G_TEST_GEN > $G_TEST_RES"
	bt_assert_success
	diff_result "$L_ACCEPT_GEN"
}

function test_rdpg_left_recursion_indirect
{
	local L_FILE="./test_rdpg/test_left_recursion_indirect.txt"
	local L_OUT=""
	
	L_OUT="$(run_rdpg "$L_FILE" 2>&1)"
	bt_assert_failure
	
	local L_MSG="left recursion in file './test_rdpg/test_left_recursion_indirect.txt' from line 5: foo -> bar -> baz -> foo
left recursion in file './test_rdpg/test_left_recursion_indirect.txt' from line 9: bar -> baz -> foo -> bar
left recursion in file './test_rdpg/test_left_recursion_indirect.txt' from line 13: baz -> foo -> bar -> baz
rdpg.awk: error: left recursion detected"
	
	diff_ "<(echo \"$L_OUT\")" "<(echo \"$L_MSG\")"
}

function test_rdpg_left_recursion_direct
{
	local L_FILE="./test_rdpg/test_left_recursion_direct.txt"
	local L_OUT=""
	
	L_OUT="$(run_rdpg "$L_FILE" 2>&1)"
	bt_assert_failure
	
	local L_MSG="left recursion in file './test_rdpg/test_left_recursion_direct.txt' from line 1: foo -> foo
rdpg.awk: error: left recursion detected"
	
	diff_ "<(echo \"$L_OUT\")" "<(echo \"$L_MSG\")"
}

function test_rdpg_strict_undefn_rule
{
	local L_FILE="./test_rdpg/test_strict_undefn_rule.txt"
	local L_OUT=""
	
	L_OUT="$(run_rdpg "-vStrict=1 $L_FILE" 2>&1)"
	bt_assert_failure
	
	local L_MSG="file './test_rdpg/test_strict_undefn_rule.txt', line 5, rule 'bar' calls a non-defined rule 'baz'
rdpg.awk: error: undefined rules detected"
	
	diff_ "<(echo \"$L_OUT\")" "<(echo \"$L_MSG\")"
}
# </test_rdpg>

function diff_result
{
	diff_ "$G_TEST_RES" "$@" && rm "$G_TEST_RES"
}

function diff_
{
	bt_diff "$@"
	bt_assert_success
}

function main
{
	source "$(dirname $(realpath $0))/bashtest.sh"
	
	if [ "$#" -gt 0 ]; then
		bt_set_verbose
	fi
	
	bt_enter
	
	test_all "$@"
	
	bt_exit_success
}

main "$@"
