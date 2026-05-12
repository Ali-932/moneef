package utils

import (
	"fmt"
	"moneef/internal/analysis/dto"
	"sort"
	"time"
)

type Aggregation string

const (
	AggregationDaily   Aggregation = "daily"
	AggregationWeekly  Aggregation = "weekly"
	AggregationMonthly Aggregation = "monthly"
)

func DetermineAggregation(start, end time.Time) Aggregation {
	days := int(end.Sub(start).Hours() / 24)
	if days <= 31 {
		return AggregationDaily
	}
	if days <= 180 {
		return AggregationWeekly
	}
	return AggregationMonthly
}

func AggregateByPeriod(data []dto.AmountPerDay, agg Aggregation) []dto.AggregatedPeriod {
	if len(data) == 0 {
		return nil
	}

	switch agg {
	case AggregationWeekly:
		return aggregateWeekly(data)
	case AggregationMonthly:
		return aggregateMonthly(data)
	default:
		return aggregateDaily(data)
	}
}

func aggregateDaily(data []dto.AmountPerDay) []dto.AggregatedPeriod {
	result := make([]dto.AggregatedPeriod, 0, len(data))
	for _, d := range data {
		result = append(result, dto.AggregatedPeriod{
			Label:       d.Date.Format("Jan 2"),
			Amount:      fmt.Sprintf("%.2f", d.Amount.Float64()),
			PeriodStart: d.Date,
			PeriodEnd:   d.Date,
		})
	}
	return result
}

type bucket struct {
	sum   float64
	start time.Time
	end   time.Time
}

func aggregateWeekly(data []dto.AmountPerDay) []dto.AggregatedPeriod {
	buckets := make(map[string]bucket)

	for _, d := range data {
		weekStart := startOfWeek(d.Date)
		weekEnd := weekStart.AddDate(0, 0, 6)
		key := weekStart.Format("2006-01-02")
		existing, ok := buckets[key]
		if !ok {
			existing = bucket{start: weekStart, end: weekEnd}
		}
		existing.sum += d.Amount.Float64()
		buckets[key] = existing
	}

	sorted := sortBuckets(buckets)
	result := make([]dto.AggregatedPeriod, 0, len(sorted))
	for _, b := range sorted {
		result = append(result, dto.AggregatedPeriod{
			Label:       fmt.Sprintf("%s – %s", b.start.Format("Jan 2"), b.end.Format("Jan 2")),
			Amount:      fmt.Sprintf("%.2f", b.sum),
			PeriodStart: b.start,
			PeriodEnd:   b.end,
		})
	}
	return result
}

func aggregateMonthly(data []dto.AmountPerDay) []dto.AggregatedPeriod {
	buckets := make(map[string]bucket)

	for _, d := range data {
		monthStart := time.Date(d.Date.Year(), d.Date.Month(), 1, 0, 0, 0, 0, time.UTC)
		monthEnd := monthStart.AddDate(0, 1, -1)
		key := monthStart.Format("2006-01-02")
		existing, ok := buckets[key]
		if !ok {
			existing = bucket{start: monthStart, end: monthEnd}
		}
		existing.sum += d.Amount.Float64()
		buckets[key] = existing
	}

	sorted := sortBuckets(buckets)
	result := make([]dto.AggregatedPeriod, 0, len(sorted))
	for _, b := range sorted {
		result = append(result, dto.AggregatedPeriod{
			Label:       b.start.Format("Jan 2006"),
			Amount:      fmt.Sprintf("%.2f", b.sum),
			PeriodStart: b.start,
			PeriodEnd:   b.end,
		})
	}
	return result
}

func startOfWeek(d time.Time) time.Time {
	weekday := int(d.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	return d.AddDate(0, 0, -(weekday - 1)).Truncate(24 * time.Hour)
}

func sortBuckets(m map[string]bucket) []bucket {
	result := make([]bucket, 0, len(m))
	for _, v := range m {
		result = append(result, v)
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].start.Before(result[j].start)
	})
	return result
}
