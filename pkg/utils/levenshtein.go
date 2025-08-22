package utils

import (
	"strings"
	"unicode"
)

// Calculate similarity between two phrases (0.0 to 1.0)
func CalculatePhraseSimilarity(query, name string) float64 {
	// Simple approach: ratio of matching words
	queryWords := strings.Split(query, " ")
	nameWords := strings.Split(name, " ")

	matches := 0
	for _, qWord := range queryWords {
		for _, nWord := range nameWords {
			if AreTermsSimilar(qWord, CleanTerm(nWord)) {
				matches++
				break
			}
		}
	}

	// Return ratio of matched query words
	return float64(matches) / float64(len(queryWords))
}

// Check if two terms are similar (allowing 1 edit for short words, 2 for longer)
func AreTermsSimilar(term1, term2 string) bool {
	if term1 == term2 {
		return true
	}

	dist := levenshteinDistance(term1, term2)
	maxDist := 1
	if len(term1) > 5 || len(term2) > 5 {
		maxDist = 2
	}

	return dist <= maxDist
}

// Clean term by removing file extensions and special characters
func CleanTerm(term string) string {
	// Remove common file extensions
	term = strings.TrimSuffix(term, ".pdf")
	term = strings.TrimSuffix(term, ".jpg")
	term = strings.TrimSuffix(term, ".png")

	// Remove special characters but keep letters
	var cleaned strings.Builder
	for _, r := range term {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			cleaned.WriteRune(r)
		}
	}

	return cleaned.String()
}

func levenshteinDistance(s1, s2 string) int {
	if len(s1) == 0 {
		return len(s2)
	}
	if len(s2) == 0 {
		return len(s1)
	}

	// Create matrix
	matrix := make([][]int, len(s1)+1)
	for i := range matrix {
		matrix[i] = make([]int, len(s2)+1)
	}

	// Initialize first column and row
	for i := 0; i <= len(s1); i++ {
		matrix[i][0] = i
	}
	for j := 0; j <= len(s2); j++ {
		matrix[0][j] = j
	}

	// Fill matrix
	for i := 1; i <= len(s1); i++ {
		for j := 1; j <= len(s2); j++ {
			cost := 0
			if s1[i-1] != s2[j-1] {
				cost = 1
			}
			matrix[i][j] = min(
				matrix[i-1][j]+1,      // deletion
				matrix[i][j-1]+1,      // insertion
				matrix[i-1][j-1]+cost, // substitution
			)
		}
	}

	return matrix[len(s1)][len(s2)]
}
