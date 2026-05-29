#include "tree_sitter/parser.h"
#include "tree_sitter/alloc.h"
#include "tree_sitter/array.h"

#include <stdint.h>
#include <stdio.h>
#include <ctype.h>

enum TokenType {
    AUTO_TERMINATOR,
    BLOCK_COMMENT_CONTENT,
    INDENT_COMMENT_CONTENT,
    OPEN_BRACED_BLOCK,
    OPEN_INDENT_BLOCK,
    OPEN_INDENT_BLOCK_COLON,
    CLOSE_INDENT_BLOCK,
    INDENT,
    DEDENT,
    INCOMPLETE_STRING,
    BEST_GUESS_ATTR_START,
    ERROR_SENTINEL,
};

typedef struct {
    char indent_block_close;
    Array(uint16_t) indents;
} Scanner;

void * tree_sitter_verse_external_scanner_create() {
    Scanner *scanner = calloc(1, sizeof(Scanner));
    array_init(&scanner->indents);
    return scanner;
}

void tree_sitter_verse_external_scanner_destroy(void *payload) {
    Scanner *scanner = (Scanner *)payload;
    array_delete(&scanner->indents);
    free(scanner);
}

unsigned tree_sitter_verse_external_scanner_serialize(
    void *payload,
    char *buffer
) {
    Scanner *scanner = (Scanner *)payload;
    size_t length = 0;

    buffer[length++] = scanner->indent_block_close;
    for (size_t i = 0; i < scanner->indents.size && length < TREE_SITTER_SERIALIZATION_BUFFER_SIZE; ++i) {
        uint16_t indent_value = *array_get(&scanner->indents, i);
        buffer[length++] = (char)(indent_value & 0xFF);
        buffer[length++] = (char)((indent_value >> 8) & 0xFF);
    }

    return length;
}

void tree_sitter_verse_external_scanner_deserialize(
    void *payload,
    const char *buffer,
    unsigned length
) {
    Scanner *scanner = (Scanner *)payload;

    scanner->indent_block_close = 0;
    array_delete(&scanner->indents);

    if (length > 0) {
        size_t cursor = 0;

        scanner->indent_block_close = buffer[cursor++];

         for (; cursor + 1 < length; cursor += 2) {
             uint16_t indent_value = (unsigned char)buffer[cursor] | ((unsigned char)buffer[cursor + 1] << 8);
             array_push(&scanner->indents, indent_value);
         }
    }
}

static bool scan_auto_terminator(
    TSLexer *lexer,
    bool met_newline
) {
    if (lexer->eof(lexer)) {
        lexer->mark_end(lexer);
        return true;
    } else if (met_newline) {
        // Look ahead past indentation: if the next non-whitespace char is '.',
        // suppress AUTO_TERMINATOR to allow dot-continuation (e.g. multiline
        // field-access chains).
        while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
            lexer->advance(lexer, true);
        }
        if (lexer->lookahead == '.') {
            return false;
        }
        return true;
    }

    switch (lexer->lookahead) {
        case 0:
        case ')':
        case ']':
        case '}':
        case '\n':
            lexer->mark_end(lexer);
            lexer->advance(lexer, true);
            return true;
        case '\r':
            lexer->mark_end(lexer);
            lexer->advance(lexer, true); /* skip \r */
            if (lexer->lookahead == '\n') {
                lexer->advance(lexer, true); /* skip \n */
            }
            /* peek past indentation for dot-continuation */
            while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
                lexer->advance(lexer, true);
            }
            if (lexer->lookahead == '.') {
                return false;
            }
            return true;
        default:
            break;
    }

    // macro chaining
    size_t else_pos = 0;
    for (;;) {
        if (lexer->eof(lexer)) {
            break;
        }
        if (lexer->lookahead == ' ') {
            lexer->advance(lexer, true);
            continue;
        }
        if (else_pos < 4 && lexer->lookahead == "else"[else_pos]) {
            lexer->advance(lexer, true);
            else_pos += 1;
            continue;
        }
        if (isalnum(lexer->lookahead)) {
            if (else_pos < 4) {
                return false;
            }
            lexer->advance(lexer, true);
            continue;
        }
        if (lexer->lookahead == '{' || (lexer->lookahead == '(' && else_pos == 4)) {
            // note: '(' after meeting an 'else' terminates the else-preceding macro
            return true;
        }
        break;
    }
    return false;
}

static bool scan_block_comment_content(TSLexer *lexer) {
    uint16_t nest_level = 1;

    while (!lexer->eof(lexer)) {
        if (lexer->lookahead == '<') {
            lexer->advance(lexer, false);
            if (lexer->lookahead == '#') {
                nest_level += 1;
            }
        } else if (lexer->lookahead == '#') {
            lexer->advance(lexer, false);
            if (lexer->lookahead == '>') {
                nest_level -= 1;
            }
        }

        lexer->advance(lexer, false);
        if (nest_level == 0) {
            break;
        }
    }

    lexer->mark_end(lexer);
    return true;
}

static bool scan_indent_comment_content(
    TSLexer *lexer,
    Scanner *scanner
) {
    uint16_t outer_indent_len;
    if (scanner->indents.size > 0) {
        outer_indent_len = *array_back(&scanner->indents);
    } else {
        outer_indent_len = 0;
    }

    uint16_t indent_len = 0;
    bool met_newline = false;
    bool line_start = false;
    for (;;) {
        if (lexer->eof(lexer)) {
            if (!line_start) {
                lexer->mark_end(lexer);
            }
            break;
        }

        if (line_start) {
            if (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
                indent_len += 1;
                lexer->advance(lexer, true);
                continue;
            } else if (lexer->lookahead == '\n') {
                indent_len = 0;
                lexer->advance(lexer, true);
                continue;
            } else {
                line_start = false;
            }
        }
        if (lexer->lookahead == '\n') {
            lexer->mark_end(lexer);
            if (!met_newline) {
                met_newline = true;
            }
            line_start = true;
            indent_len = 0;
        } else if (!met_newline || indent_len > outer_indent_len) {
            lexer->advance(lexer, false);
        } else {
            break;
        }
    }

    return true;
}

bool tree_sitter_verse_external_scanner_scan(
    void *payload,
    TSLexer *lexer,
    const bool *valid_symbols
) {
    Scanner *scanner = (Scanner *)payload;
    bool error_recovery = valid_symbols[ERROR_SENTINEL];

    if (valid_symbols[INCOMPLETE_STRING] && !error_recovery) {
        lexer->mark_end(lexer);
        for (;;) {
            if (lexer->lookahead == ' ') {
                lexer->advance(lexer, true);
                continue;
            } else if (lexer->lookahead == '\n') {
                break;
            } else {
                return false;
            }
        }
        lexer->result_symbol = INCOMPLETE_STRING;
        return true;
    }

    if (valid_symbols[BLOCK_COMMENT_CONTENT] && !error_recovery) {
        lexer->result_symbol = BLOCK_COMMENT_CONTENT;
        return scan_block_comment_content(lexer);
    } else if (valid_symbols[INDENT_COMMENT_CONTENT] && !error_recovery) {
        lexer->result_symbol = INDENT_COMMENT_CONTENT;
        return scan_indent_comment_content(lexer, scanner);
    }

    if (valid_symbols[AUTO_TERMINATOR]
            && scanner->indent_block_close > 0
            && !valid_symbols[INDENT]
            && !valid_symbols[DEDENT]
    ) {
        scanner->indent_block_close -= 1;
        lexer->result_symbol = AUTO_TERMINATOR;
        return true;
    }

    lexer->mark_end(lexer);

    uint16_t prev_indent_len;
    if (scanner->indents.size > 0) {
        prev_indent_len = *array_back(&scanner->indents);
    } else {
        prev_indent_len = 0;
    }
    if (valid_symbols[DEDENT] && !error_recovery && prev_indent_len > 0) {
        array_pop(&scanner->indents);
        lexer->result_symbol = DEDENT;
        return true;
    }

    bool met_newline = false;
    bool compat_with_terminator = true;
    uint16_t indent_len = 0;
    bool check_other_lines = valid_symbols[OPEN_BRACED_BLOCK] || valid_symbols[INDENT];
    for (;;) {
        if (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
            indent_len += 1;
            lexer->advance(lexer, true);
        } else if (lexer->lookahead == '\r') {
            lexer->advance(lexer, true); /* skip bare \r; \n will follow in CRLF */
        } else if (lexer->lookahead == '\n') {
            indent_len = 0;
            lexer->advance(lexer, true);
            if (met_newline) {
                continue;
            }
            met_newline = true;

            if (valid_symbols[OPEN_INDENT_BLOCK] && !error_recovery) {
                lexer->result_symbol = OPEN_INDENT_BLOCK;
                return true;
            }
            if (valid_symbols[INDENT]
                    && valid_symbols[AUTO_TERMINATOR]
                    && !error_recovery) {
                lexer->mark_end(lexer);
                lexer->result_symbol = AUTO_TERMINATOR;
                return scan_auto_terminator(lexer, true);
            } else if (valid_symbols[INDENT]
                    && valid_symbols[CLOSE_INDENT_BLOCK]
                    && !error_recovery) {
                compat_with_terminator = false;
            } else {
                lexer->mark_end(lexer);
            }
            if (!check_other_lines) {
                break;
            }
        } else {
            break;
        }
    }

    if (valid_symbols[OPEN_INDENT_BLOCK_COLON]
            && !met_newline
            && lexer->lookahead == ':') {
        lexer->advance(lexer, false);
        for (;;) {
            if (lexer->lookahead == ' ') {
                lexer->advance(lexer, true);
                continue;
            } else if (lexer->lookahead == '\r' || lexer->lookahead == '\n') {
                if (lexer->lookahead == '\r') {
                    lexer->advance(lexer, true);
                }
                if (lexer->lookahead == '\n') {
                    lexer->advance(lexer, true);
                }
                lexer->mark_end(lexer);
                lexer->result_symbol = OPEN_INDENT_BLOCK_COLON;
                return true;
            } else {
                break;
            }
        }
        return false;
    }

    if (valid_symbols[INDENT] && !error_recovery) {
        if (indent_len > prev_indent_len) {
            array_push(&scanner->indents, indent_len);
            lexer->mark_end(lexer);
            lexer->result_symbol = INDENT;
            return true;
        } else if (valid_symbols[CLOSE_INDENT_BLOCK]) {
            scanner->indent_block_close += 1;
            lexer->result_symbol = CLOSE_INDENT_BLOCK;
            return true;
        }
    }

    if (valid_symbols[OPEN_BRACED_BLOCK] && lexer->lookahead == '{') {
        lexer->advance(lexer, false);
        lexer->mark_end(lexer);
        lexer->result_symbol = OPEN_BRACED_BLOCK;
        return true;
    } else if (valid_symbols[AUTO_TERMINATOR]
            && compat_with_terminator
            && scan_auto_terminator(lexer, met_newline)
            && !error_recovery) {
        lexer->result_symbol = AUTO_TERMINATOR;
        return true;
    }

    if (valid_symbols[BEST_GUESS_ATTR_START] && lexer->lookahead == '<') {
        // FIXME : find a proper way to avoid this hack
        lexer->mark_end(lexer);
        lexer->result_symbol = BEST_GUESS_ATTR_START;

        size_t cursor = 0;
        bool met_space = false;
        for (;;) {
            lexer->advance(lexer, false);
            cursor += 1;
            switch (lexer->lookahead) {
                case '#':
                    if (cursor == 1) {
                        return false;
                    }
                    break;
                case ' ':
                    met_space = true;
                    break;
                case '\n':
                case '\r':
                case ')':
                case ']':
                case '}':
                    return false;
                case '>':
                    if (cursor == 1) {
                        return false;
                    }
                    return true;
                case '(':
                case '[':
                case '{':
                    // Only treat as attribute start if no space was seen after '<'
                    // e.g. '<Foo(...)>' is an attribute, but '< Foo(...)' is comparison
                    if (met_space) {
                        return false;
                    }
                    return true;
            }
        }
    }

    return false;
}

