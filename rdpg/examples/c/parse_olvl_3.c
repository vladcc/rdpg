#include "lex.c"
typedef struct usr_state usr_state;
typedef struct prs_state prs_state;
// <declarations>
#include <stdbool.h>
static bool parse(prs_state * prs, usr_state * usr);
static bool statements(prs_state * prs, usr_state * usr);
static bool statement(prs_state * prs, usr_state * usr);
static bool expression_sync(prs_state * prs, usr_state * usr);
static bool expression(prs_state * prs, usr_state * usr);
static bool expr_rest(prs_state * prs, usr_state * usr);
static bool plus_minus_term(prs_state * prs, usr_state * usr);
static bool term(prs_state * prs, usr_state * usr);
static bool term_tail(prs_state * prs, usr_state * usr);
static bool div_mul_factor(prs_state * prs, usr_state * usr);
static bool factor(prs_state * prs, usr_state * usr);
static bool expon(prs_state * prs, usr_state * usr);
static bool base(prs_state * prs, usr_state * usr);
static bool single(prs_state * prs, usr_state * usr);
// </declarations>

#include "main.c"

// <definitions>
// translated by rdpg-to-c.awk 1.01
// generated by rdpg.awk 1.11
// optimized by rdpg-opt.awk 1.1 Olvl=3
static bool parse(prs_state * prs, usr_state * usr)
{
// rule parse
// defn statements
	tok_next(prs);
	return statements(prs, usr);
}
static bool statements(prs_state * prs, usr_state * usr)
{
// rule statements
// defn statement -EOI-
// defn statement statements
	if (statement(prs, usr))
	{
		if (tok_match(prs, EOI))
		{
			tok_next(prs);
			return true;
		}
		else 
			return statements(prs, usr);
	}
	return false;
}
static bool statement(prs_state * prs, usr_state * usr)
{
// rule statement
// defn expression_sync
	if (expression_sync(prs, usr))
		return true;
	else 
		return sync(prs, usr, SEMI);
}
static bool expression_sync(prs_state * prs, usr_state * usr)
{
// rule expression_sync
// defn expression SEMI
	if (expression(prs, usr))
	{
		if (tok_match(prs, SEMI))
		{
			tok_next(prs);
			return true;
		}
		else 
			tok_err_exp(prs, 1, SEMI);
	}
	return false;
}
static bool expression(prs_state * prs, usr_state * usr)
{
// rule expression
// defn term expr_rest
	if (term(prs, usr))
		return expr_rest(prs, usr);
	return false;
}
static bool expr_rest(prs_state * prs, usr_state * usr)
{
// rule expr_rest
// defn plus_minus_term expr_rest
	if (plus_minus_term(prs, usr))
		return expr_rest(prs, usr);
	return true;
}
static bool plus_minus_term(prs_state * prs, usr_state * usr)
{
// rule plus_minus_term?
// defn PLUS term
// defn MINUS term
	if (tok_match(prs, PLUS))
	{
		tok_next(prs);
		if (term(prs, usr))
		{
			add(prs, usr);
			return true;
		}
	}
	else if (tok_match(prs, MINUS))
	{
		tok_next(prs);
		if (term(prs, usr))
		{
			subt(prs, usr);
			return true;
		}
	}
	return false;
}
static bool term(prs_state * prs, usr_state * usr)
{
// rule term
// defn factor term_tail
	if (factor(prs, usr))
		return term_tail(prs, usr);
	return false;
}
static bool term_tail(prs_state * prs, usr_state * usr)
{
// rule term_tail
// defn div_mul_factor term_tail
	if (div_mul_factor(prs, usr))
		return term_tail(prs, usr);
	return true;
}
static bool div_mul_factor(prs_state * prs, usr_state * usr)
{
// rule div_mul_factor?
// defn MUL factor
// defn DIV factor
	if (tok_match(prs, MUL))
	{
		tok_next(prs);
		if (factor(prs, usr))
		{
			mult(prs, usr);
			return true;
		}
	}
	else if (tok_match(prs, DIV))
	{
		tok_next(prs);
		if (factor(prs, usr))
		{
			divd(prs, usr);
			return true;
		}
	}
	return false;
}
static bool factor(prs_state * prs, usr_state * usr)
{
// rule factor
// defn base expon
	if (base(prs, usr))
	{
		expon(prs, usr);
		return true;
	}
	return false;
}
static bool expon(prs_state * prs, usr_state * usr)
{
// rule expon?
// defn EXP factor
	if (tok_match(prs, EXP))
	{
		tok_next(prs);
		if (factor(prs, usr))
		{
			power(prs, usr);
			return true;
		}
	}
	return false;
}
static bool base(prs_state * prs, usr_state * usr)
{
// rule base
// defn single NUMBER
// defn NUMBER
// defn LPAR expression RPAR
	if (single(prs, usr))
	{
		if (tok_match(prs, NUMBER))
		{
			push_val(prs, usr);
			tok_next(prs);
			return true;
		}
		else 
			tok_err_exp(prs, 1, NUMBER);
	}
	else if (tok_match(prs, NUMBER))
	{
		push_val(prs, usr);
		tok_next(prs);
		return true;
	}
	else if (tok_match(prs, LPAR))
	{
		tok_next(prs);
		if (expression(prs, usr))
		{
			if (tok_match(prs, RPAR))
			{
				tok_next(prs);
				return true;
			}
			else 
				tok_err_exp(prs, 1, RPAR);
		}
	}
	else 
		tok_err_exp(prs, 2, NUMBER, LPAR);
	return false;
}
static bool single(prs_state * prs, usr_state * usr)
{
// rule single?
// defn MINUS
// defn PLUS
	if (tok_match(prs, MINUS))
	{
		neg(prs, usr);
		tok_next(prs);
		return true;
	}
	else if (tok_match(prs, PLUS))
	{
		tok_next(prs);
		return true;
	}
	return false;
}
// </definitions>
