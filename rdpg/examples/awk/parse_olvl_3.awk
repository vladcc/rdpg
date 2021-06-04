# <definitions>
# translated by rdpg-to-awk.awk 1.01
# generated by rdpg.awk 1.11
# optimized by rdpg-opt.awk 1.1 Olvl=3
function parse(    _arr) {
# rule parse
# defn statements
	tok_next()
	return statements()
}
function statements(    _arr) {
# rule statements
# defn statement -EOI-
# defn statement statements
	if (statement()) {
		if (tok_match(EOI())) {
			tok_next()
			return 1
		} else {
			return statements()
		}
	}
	return 0
}
function statement(    _arr) {
# rule statement
# defn expression_sync
	if (expression_sync()) {
		return 1
	} else {
		return sync(SEMI())
	}
}
function expression_sync(    _arr) {
# rule expression_sync
# defn expression SEMI
	if (expression()) {
		if (tok_match(SEMI())) {
			tok_next()
			return 1
		} else {
			_arr[1] = SEMI()
			tok_err_exp(_arr, 1)
		}
	}
	return 0
}
function expression(    _arr) {
# rule expression
# defn term expr_rest
	if (term()) {
		return expr_rest()
	}
	return 0
}
function expr_rest(    _arr) {
# rule expr_rest
# defn plus_minus_term expr_rest
	if (plus_minus_term()) {
		return expr_rest()
	}
	return 1
}
function plus_minus_term(    _arr) {
# rule plus_minus_term?
# defn PLUS term
# defn MINUS term
	if (tok_match(PLUS())) {
		tok_next()
		if (term()) {
			add()
			return 1
		}
	} else if (tok_match(MINUS())) {
		tok_next()
		if (term()) {
			subt()
			return 1
		}
	}
	return 0
}
function term(    _arr) {
# rule term
# defn factor term_tail
	if (factor()) {
		return term_tail()
	}
	return 0
}
function term_tail(    _arr) {
# rule term_tail
# defn div_mul_factor term_tail
	if (div_mul_factor()) {
		return term_tail()
	}
	return 1
}
function div_mul_factor(    _arr) {
# rule div_mul_factor?
# defn MUL factor
# defn DIV factor
	if (tok_match(MUL())) {
		tok_next()
		if (factor()) {
			mult()
			return 1
		}
	} else if (tok_match(DIV())) {
		tok_next()
		if (factor()) {
			divd()
			return 1
		}
	}
	return 0
}
function factor(    _arr) {
# rule factor
# defn base expon
	if (base()) {
		expon()
		return 1
	}
	return 0
}
function expon(    _arr) {
# rule expon?
# defn EXP factor
	if (tok_match(EXP())) {
		tok_next()
		if (factor()) {
			power()
			return 1
		}
	}
	return 0
}
function base(    _arr) {
# rule base
# defn single NUMBER
# defn NUMBER
# defn LPAR expression RPAR
	if (single()) {
		if (tok_match(NUMBER())) {
			push_val()
			tok_next()
			return 1
		} else {
			_arr[1] = NUMBER()
			tok_err_exp(_arr, 1)
		}
	} else if (tok_match(NUMBER())) {
		push_val()
		tok_next()
		return 1
	} else if (tok_match(LPAR())) {
		tok_next()
		if (expression()) {
			if (tok_match(RPAR())) {
				tok_next()
				return 1
			} else {
				_arr[1] = RPAR()
				tok_err_exp(_arr, 1)
			}
		}
	} else {
		_arr[1] = NUMBER()
		_arr[2] = LPAR()
		tok_err_exp(_arr, 2)
	}
	return 0
}
function single(    _arr) {
# rule single?
# defn MINUS
# defn PLUS
	if (tok_match(MINUS())) {
		neg()
		tok_next()
		return 1
	} else if (tok_match(PLUS())) {
		tok_next()
		return 1
	}
	return 0
}
# </definitions>
