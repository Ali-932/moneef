package service

import (
	"testing"
	"time"
)

func TestPreviousPeriod(t *testing.T) {
	loc := time.FixedZone("UTC+3", 3*3600)
	day := func(y int, m time.Month, d int) time.Time { return time.Date(y, m, d, 0, 0, 0, 0, loc) }
	endOf := func(y int, m time.Month, d int) time.Time { return day(y, m, d).Add(24*time.Hour - time.Nanosecond) }
	for _, c := range []struct {
		name               string
		start, end         time.Time
		wantStart, wantEnd time.Time
	}{
		{"month so far", day(2026, 9, 1), endOf(2026, 9, 5), day(2026, 8, 1), endOf(2026, 8, 5)},
		{"whole month", day(2026, 8, 1), endOf(2026, 8, 31), day(2026, 7, 1), endOf(2026, 7, 31)},
		{"end capped to a short month", day(2026, 3, 1), endOf(2026, 3, 31), day(2026, 2, 1), endOf(2026, 2, 28)},
		{"across the new year", day(2026, 1, 1), endOf(2026, 1, 20), day(2025, 12, 1), endOf(2025, 12, 20)},
		{"other ranges: same length right before", day(2026, 9, 10), endOf(2026, 9, 19), day(2026, 8, 31), day(2026, 9, 10).Add(-time.Nanosecond)},
	} {
		gotStart, gotEnd := previousPeriod(c.start, c.end)
		// To the second: the same-length rule is off from midnight by a nanosecond.
		sec := func(t time.Time) time.Time { return t.Truncate(time.Second) }
		if !sec(gotStart).Equal(sec(c.wantStart)) || !sec(gotEnd).Equal(sec(c.wantEnd)) {
			t.Errorf("%s: got %s – %s, want %s – %s", c.name, gotStart, gotEnd, c.wantStart, c.wantEnd)
		}
	}
}
