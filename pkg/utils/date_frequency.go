package utils

import (
	"errors"
	"strings"
	"time"
)

func CalculateNextOccurrence(from time.Time, frequency string) (time.Time, error) {
	freq := strings.TrimSpace(strings.ToLower(frequency))
	switch freq {
	case "daily":
		return from.AddDate(0, 0, 1), nil
	case "weekly":
		return from.AddDate(0, 0, 7), nil
	case "bi-weekly", "biweekly":
		return from.AddDate(0, 0, 14), nil
	case "monthly":
		return from.AddDate(0, 1, 0), nil
	case "yearly":
		return from.AddDate(1, 0, 0), nil
	default:
		return time.Time{}, errors.New("unsupported frequency: " + frequency)
	}
}
