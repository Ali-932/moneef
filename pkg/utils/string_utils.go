package utils

import (
	"strings"
	"unicode"
)

func NormalizeString(s string) string {
	var result strings.Builder
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || r == ' ' {
			result.WriteRune(r)
		}
	}
	s = result.String()
	s = strings.Join(strings.Fields(s), " ")
	return s
}
