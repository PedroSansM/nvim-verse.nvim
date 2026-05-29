/**
 * @file Verse (Epic Games's new language) grammar for tree-sitter
 * @license MIT
 * vim: fmr=#region,#endregion
 *
 * Improvements over the original:
 *   - is_declaration: "Entity is: block" is syntactic sugar for "Entity := block"
 *   - set_expression: compound operators +=, -=, *=, /=
 *   - Richer highlights in queries/highlights.scm
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

/**
  * Precedence table.
  * @type {Object.<string, number>}
  */
const PREC = {
  named_unary: 10,
  range: 10,
  thin_arrow: 10,
  fat_arrow: 10,
  to: 10,
  of: 10,
  at: 10,
  query: 9,
  opt: 9,
  not: 8,
  sign: 8,
  mult: 7,
  add: 6,
  eq: 4,
  cmp: 4,
  and: 3,
  or: 2,
  decl: 1,
  where: -1,
};

const CONTENT_PREC = {
  string: 2,
  indent_comment: 1,
  comment: 0,
};

module.exports = grammar({
  name: "verse",

  externals: $ => [
    $._auto_terminator,
    $._block_comment_content,
    $._indent_comment_content,
    '{',
    $._open_indent_block,
    "macro:",
    $._close_indent_block,
    $._indent,
    $._dedent,
    $._incomplete_string,
    $._best_guess_attr_start,
    $._error_sentinel,
    $._string_content,
    $._string_start,
  ],

  conflicts: $ => [
    [$._stdexpr],
    [$._stdexpr, $._argument_list_paren],
    [$.unit, $._argument_list_paren],
    [$.macro_call],
  ],

  extras: $ => [/\s+/, $.line_comment, $.block_comment, $.indent_comment],

  rules: {
    source_file: $ => repeat($._complete_expr),

    //#region Comments
    line_comment: _ => prec(CONTENT_PREC.comment, token(seq('#', /.*/))),
    block_comment: $ => prec(CONTENT_PREC.comment, seq(
      '<#',
      $._block_comment_content,
    )),
    indent_comment: $ => prec(CONTENT_PREC.indent_comment, seq(
      '<#>', // TODO : limit to line start
      $._indent_comment_content,
    )),
    //#endregion

    _complete_expr: $ => seq(
      $._expr,
      choice(';', $._auto_terminator)
    ),

    //#region Expression Kinds
    _expr: $ =>
      prec.left(choice(
        $._stdexpr,
        $._non_attributable_expr,
      )),
    // in Verse, *everything* is an expression
    // you can write mad stuff like ```verse
    // (((class_name))<internal>):=((class)<(final)>(){})
    // ```
    // so, among other considerations, parenthesized expressions
    // are kept transparent to keep workable trees
    _stdexpr: $ =>
      prec.right(seq(
        optional(field('pre_attributes', $.at_attributes)),
        choice(
          seq('(', $._expr, ')'),
          $._standalone_expr,
        ),
        optional(field('attributes', $.attributes)),
    )),
    // the official parser deals with ```verse
    // if. (0 < 1 > 0)
    // ``` by reading 0<1> and unknown trailing "0"
    attributes: $ =>
      prec.right(seq(
        $._best_guess_attr_start,
        repeat1(prec.left(PREC.cmp, seq(
          '<', $._expr, '>',
        ))),
      )),
    at_attributes: $ =>
      prec.right(seq(
        repeat1(prec.left(seq(
          '@', $._expr,
        ))),
        optional($._auto_terminator),
      )),

    comma_separated_group: $ =>
      prec.right(seq(
        $._expr,
        repeat1(prec.left(seq(
          alias(/\s*[,]/, ","),
          $._expr,
        ))),
      )),

    unit: _ => seq("(", ")"),
    _standalone_expr: $ => choice(
      $.unit,
      $.identifier,
      $.path_literal,
      $.logic_literal,
      $.integer,
      $.float,
      $.string,
      $.char,

      $.macro_call,

      $.function_call,
      $.field_expression,
      $.postfix_expression,

      $.map_container,
      $.array_container,
    ),
    _non_attributable_expr: $ => choice(
      $.comma_separated_group,

      $.declaration,
      $.is_declaration,
      $.function_declaration,

      $.set_expression,

      $.return_expression,
      $.continue_expression,
      $.break_expression,
      $.yield_expression,

      $.unary_expression,
      $.binary_expression,

      $.thin_arrow_expression,
      $.range_expression,
      $.fat_arrow_expression,
      $.of_expression,
      $.at_expression,
      $.to_expression,
      $.where_expression,
    ),
    //#endregion

    qualifier: $ => seq(
      '(',
      $._expr,
      ':)',
    ),
    identifier: $ => seq(
      optional($.qualifier),
      /[A-Za-z_][A-Za-z0-9_]*/
    ),
    path_literal: _ => /[/][A-Za-z0-9_][A-Za-z0-9_\-.]*(@[A-Za-z0-9_][A-Za-z0-9_\-.]*)?(\/[A-Za-z0-9_][A-Za-z0-9_\-.]*)*/,
    logic_literal: _ => choice('true', 'false'),

    //#region Numbers
    integer: $ => choice(
      /0x[0-9A-Fa-f]+/,
      seq(
        /[0-9]+/,
        optional($.number_suffix),
      ),
    ),
    float: $ => {
      const digits = /[0-9]+/;
      const exponent = seq(/[eE][\+-]?/, digits);

      return seq(
        token(choice(
          seq(digits, '.', digits, optional(exponent)),
          seq(digits, exponent),
        )),
        optional($.number_suffix),
      );
    },
    number_suffix: _ => token.immediate(/[A-Za-z_][A-Za-z0-9_]*/),
    //#endregion

    //#region Strings
    string: $ => seq(
      '"',
      repeat(choice(
        $.string_fragment,
        $.string_template,
      )),
      choice(
        token.immediate('"'),
        $._incomplete_string
      ),
    ),
    escape_sequence: _ => token.immediate(/\\./),
    string_fragment: $ => prec.right(repeat1(choice(
      token.immediate(prec(CONTENT_PREC.string, /[^"{\\\n]+/)),
      token.immediate(prec(CONTENT_PREC.string, /\n[ \t]*/)),
      $.escape_sequence,
    ))),
    string_template: $ => seq(
      token.immediate('{'),
      optional($._expr),
      '}',
    ),
    char: _ => /'[^\']*'/,
    //#endregion

    map_container: $ =>
      prec.left(seq(
        '[',
        field('key', $._stdexpr),
        ']',
        field('value', $._stdexpr),
      )),
    array_container: $ =>
      prec.left(seq(
        '[', ']',
        field('value', $._stdexpr),
      )),

    // var<access_specifier> is valid Verse syntax, e.g. var<private> or var<public>
    var_keyword: $ => seq('var', optional($.attributes)),
    declaration: $ =>
      prec.left(seq(
        optional($.at_attributes),
        optional($.var_keyword),
        field('lhs', $._stdexpr),
        choice(
          seq(
            seq(':', field('type_hint', $._expr)),
            seq(
              '=',
              field('rhs', $._inline_body),
            ),
          ),
          seq(
            ':',
            field('type_hint', $._expr),
          ),
          seq(
            ':=',
            field('rhs', $._inline_body),
          ),
        ),
      )),

    // "is:" is syntactic sugar for ":= block", used in archetype initialization.
    // e.g.:  Entity is:
    //            FieldA := value
    //
    // is equivalent to:
    //
    //        Entity :=
    //            SomeType:
    //                FieldA := value
    //
    // The "macro:" external token handles the colon + newline transition into
    // an indented block, just like it does in macro_call.
    is_declaration: $ =>
      prec.left(seq(
        field('lhs', $._stdexpr),
        alias('is', $.is_keyword),
        field('rhs', alias($.macro_block, $.block)),
      )),

    set_expression: $ => 
      prec.left(10, seq(
        'set',
        field('lhs', $._stdexpr),
        field('operator', choice('=', '+=', '-=', '*=', '/=')),
        field('rhs', $._inline_body),
      )),
    return_expression: $ => named_unary($, 'return'),
    continue_expression: $ => named_unary($, 'continue'),
    break_expression: $ => named_unary($, 'break'),
    yield_expression: $ => named_unary($, 'yield'),

    function_call: $ =>
      prec.left(seq(
        field('function', $._stdexpr),
        field('arguments', $.argument_list),
      )),
    function_declaration: $ =>
      prec.left(1, seq(
        field('name', $._stdexpr),
        field('parameters', $._argument_list_paren),
        optional(field('effects', $.attributes)),
        ':',
        field('ret_type', $._expr),
        optional(seq(
          choice('=', ':='),
          $._inline_body,
        )),
      )),

    argument_list: $ => choice(
      $._argument_list_paren,
      $._argument_list_square,
    ),
    _argument_list_paren: $ => createArgumentList($, '(', ')'),
    _argument_list_square: $ => createArgumentList($, '[', ']'),

    //#region Blocks
    else_keyword: _ => 'else',
    macro_call: $ =>
      prec.left(1, seq(
        choice(
          seq(
            $.else_keyword,
            optional(field('macro', $._stdexpr)),
          ),
          field('macro', $._stdexpr),
        ),
        optional(field('arguments', $.argument_list)),
        alias($.macro_block, $.block),
      )),

    macro_block: $ =>
      prec.right(choice(
        seq(
          '{',
          repeat($._complete_expr),
          '}',
        ),
        seq(
          "macro:",
          repeat(seq(
            $._indent,
            $._complete_expr,
            $._dedent,
          )),
          $._close_indent_block,
        ),
        seq(
          '. ',
          $._expr,
        ),
      )),

    _inline_body: $ =>
      prec.left(10, choice(
        $.block,
        $._expr,
      )),
    block: $ => choice(
      seq(
        '{',
        repeat($._complete_expr),
        '}',
      ),
      seq(
        $._open_indent_block,
        repeat(seq(
          $._indent,
          $._complete_expr,
          $._dedent,
        )),
        $._close_indent_block,
      ),
    ),
    //#endregion

    //#region Functions
    named_argument: $ =>
      prec.left(PREC.decl, seq(
        '?',
        field('name', $.identifier),
        ':=',
        $._expr,
      )),

    //#endregion

    //#region Operators
    field_expression: $ =>
      prec.left(PREC.decl, seq(
        field('target', $._stdexpr),
        '.',
        field('field', $._stdexpr),
      )),

    binary_expression: $ => {
      /** @type [string, number][] */
      const binary_table = [
        ['*'  , PREC.mult]
      , ['/'  , PREC.mult]
      , ['+'  , PREC.add ]
      , ['-'  , PREC.add ]
      , ['='  , PREC.eq  ]
      , ['<>' , PREC.eq  ]
      , ['<'  , PREC.cmp ]
      , ['>'  , PREC.cmp ]
      , ['<=' , PREC.cmp ]
      , ['>=' , PREC.cmp ]
      , ['and', PREC.and ]
      , ['or' , PREC.or  ]
      ];
      return choice(...binary_table.map(
        ([op, pval]) => prec.left(pval, seq(
          field('lhs', $._expr),
          field('operator', op),
          field('rhs', $._expr) 
         )),
      ));
    },

    thin_arrow_expression: $ =>
      binary_rule($, "->", PREC.thin_arrow),
    range_expression: $ =>
      binary_rule($, "..", PREC.range),
    fat_arrow_expression: $ =>
      binary_rule($, "=>", PREC.fat_arrow, "left", $._inline_body),
    of_expression: $ =>
      // Supports both "f of expr" and "f of:\n  block" (colon + indent block form)
      prec.right(PREC.of, seq(
        field('lhs', $._expr),
        'of',
        field('rhs', choice(
          alias($.macro_block, $.block),
          $._expr,
        )),
      )),
    at_expression: $ =>
      prec.left(PREC.at, seq(
        field('lhs', $._expr),
        'at',
        field('rhs', $._expr),
      )),
    to_expression: $ =>
      binary_rule($, "to", PREC.to),
    where_expression: $ =>
      binary_rule($, "where", PREC.where),

    unary_expression: $ => {
      /** @type [string, number][] */
      const prefix_table = [
        ['?'  , PREC.opt ]
      , ['not', PREC.not ]
      , ['+'  , PREC.sign]
      , ['-'  , PREC.sign]
      , [':', PREC.query]
      ];
      /** @type [string, number][] */
      const suffix_table = [
        ['?', PREC.query],
      ];
      return choice(...
        prefix_table.map(
          ([op, pval]) => prec.left(pval, seq(
            field('operator', op),
            field('operand', $._expr),
           )))
        .concat(suffix_table.map(
          ([op, pval]) => prec.left(pval, seq(
            field('operand', $._expr),
            field('operator', op),
           ))))
      );
    },

    // Suffix '?' (failure-propagation / optional-unwrap).
    // Lives in _standalone_expr so the result is a _stdexpr and can be used
    // as the target of field_expression, e.g. MaybeNode?.Field.
    postfix_expression: $ =>
      prec.left(PREC.query, seq(
        field('operand', $._stdexpr),
        field('operator', '?'),
      )),
    //#endregion
  }
});

/**
  * Creates an argument list variant with a start and end.
  * @param {GrammarSymbols<any>} $
  * @param {string} start
  * @param {string} end
  * @returns {SeqRule}
  */
function createArgumentList($, start, end) {
  return seq(
    start,
    choice(
      separated1(
        ",",
        choice(
          $._expr,
          $.named_argument
        ),
        optional(","),
      ),
      repeat($._complete_expr),
    ),
    end,
  );
}

/**
  * Creates a rule for array-like elements with a separator.
  * @param {RuleOrLiteral} separator
  * @param {RuleOrLiteral} rule
  * @param {RuleOrLiteral?} trail
  * @returns {SeqRule}
  */
function separated1(separator, rule, trail) {
  const rules = [rule, repeat(prec.left(1, seq(separator, rule)))];
  if (trail) {
    rules.push(trail);
  }
  return seq(...rules);
}

/**
  * Creates a named unary expression rule.
  * @param {GrammarSymbols<any>} $
  * @param {string} keyword
  * @return {Rule}
  */
function named_unary($, keyword) {
  return prec.left(PREC.named_unary, seq(
    keyword,
    optional($._expr),
  ));
}

/**
  * Creates a non-named binary expression rule.
  * @param {GrammarSymbols<any>} $
  * @param {string} op
  * @param {number} pval Precedence
  * @param {"left"|"right"} dir Precedence direction
  * @param {Rule|undefined} rhs Right hand side rule override
  * @return {Rule}
  */
function binary_rule($, op, pval, dir="left", rhs=undefined) {
  const rule = seq(
    field('lhs', $._expr),
    op,
    field('rhs', rhs !== undefined ? rhs : $._expr),
  );
  if (dir == "left") {
    return prec.left(pval, rule);
  } else if (dir == "right") {
    return prec.right(pval, rule);
  } else {
    throw new Error("dir must be 'left' or 'right'");
  }
}


