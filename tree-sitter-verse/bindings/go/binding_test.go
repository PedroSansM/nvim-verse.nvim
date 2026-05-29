package tree_sitter_verse_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_verse "github.com/unoqwy/tree-sitter-verse/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_verse.Language())
	if language == nil {
		t.Errorf("Error loading Verse grammar")
	}
}
