package service

import (
	"github.com/shopspring/decimal"
	"golang.org/x/sync/errgroup"
	"moneef/internal/analysis/dto"
	"moneef/internal/analysis/repository"
	"moneef/internal/analysis/utils"
	"moneef/internal/db"
	"moneef/pkg/types"
	"sync"
	"time"
)

func GetAllAnalysisChartsService(profileId uint, startDate, endDate time.Time, currency string) (*dto.AnalysisCharts, error) {
	// Daily buckets follow the caller's zone (the range's UTC offset). SQLite
	// compares dates as text, so the queries themselves need UTC bounds.
	// ponytail: one fixed offset for the whole range; a DST change inside it
	// shifts that side by an hour. Send an IANA zone name if that matters.
	loc := startDate.Location()
	lastPeriodStart, lastPeriodEnd := previousPeriod(startDate, endDate)
	startDate, endDate = startDate.UTC(), endDate.UTC()
	lastPeriodStart, lastPeriodEnd = lastPeriodStart.UTC(), lastPeriodEnd.UTC()

	var mu sync.Mutex

	var (
		spendByCategory           []dto.CategorySummary
		spendByCategoryLastPeriod []dto.CategorySummary
		spendPerDay               []dto.AmountPerDay
		spendPerDayLastPeriod     []dto.AmountPerDay
		total                     types.Money
		nextRecurringTransactions []dto.NextRecurringTransactions
		totalIncome               types.Money
		transactionCount          int
		biggestTransaction        dto.BiggestTransaction
		topMerchant               dto.TopMerchant
	)
	g := new(errgroup.Group)
	g.Go(func() error {
		result, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		spendByCategory = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, lastPeriodStart, lastPeriodEnd, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		spendByCategoryLastPeriod = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionTotalExpense(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		total = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsAmountPerDay(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		spendPerDay = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsAmountPerDay(db.DB, profileId, lastPeriodStart, lastPeriodEnd, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		spendPerDayLastPeriod = result
		mu.Unlock()
		return nil
	})
	g.Go(func() error {
		result, err := repository.GetNextRecurringTransactions(db.DB, profileId, time.Now(), currency)
		if err != nil {
			return err
		}
		mu.Lock()
		nextRecurringTransactions = result
		mu.Unlock()
		return nil

	})

	g.Go(func() error {
		result, err := repository.GetTotalIncome(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		totalIncome = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionCount(db.DB, profileId, startDate, endDate)
		if err != nil {
			return err
		}
		mu.Lock()
		transactionCount = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetBiggestTransaction(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		biggestTransaction = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTopMerchant(db.DB, profileId, startDate, endDate, currency)
		if err != nil {
			return err
		}
		mu.Lock()
		topMerchant = result
		mu.Unlock()
		return nil
	})

	if err := g.Wait(); err != nil {
		return nil, err
	}
	spendByCategorySorted := utils.GetCategoriesSlicedAndSorted(spendByCategory, total)

	totalLastPeriod := types.MoneyZero()
	for _, cat := range spendByCategoryLastPeriod {
		totalLastPeriod = totalLastPeriod.Add(cat.TotalAmount)
	}
	spendByCategorySortedLastPeriod := utils.GetCategoriesSlicedAndSorted(spendByCategoryLastPeriod, totalLastPeriod)
	spendPerDaySorted := utils.FillMissingDates(spendPerDay, startDate.In(loc), endDate.In(loc))
	spendPerDaySortedLastPeriod := utils.FillMissingDates(spendPerDayLastPeriod, lastPeriodStart.In(loc), lastPeriodEnd.In(loc))

	var savingsRate types.Money
	if !decimal.Decimal(totalIncome).IsZero() {
		savingsRate = totalIncome.Sub(total).Div(totalIncome).Mul(types.MoneyFromInt(100))
	}

	var avgTransaction types.Money
	if transactionCount > 0 {
		avgTransaction = total.Div(types.MoneyFromInt(int64(transactionCount)))
	}

	res := dto.AnalysisCharts{
		Categories:                spendByCategorySorted,
		CategoriesLastPeriod:      spendByCategorySortedLastPeriod,
		SpentPerDay:               spendPerDaySorted,
		SpentPerDayLastPeriod:     spendPerDaySortedLastPeriod,
		NextRecurringTransactions: nextRecurringTransactions,
		Total:                     total,
		QuickStats: dto.QuickStats{
			SavingsRate:        savingsRate,
			BiggestTransaction: biggestTransaction,
			TransactionCount:   transactionCount,
			TopMerchant:        topMerchant,
			AvgTransaction:     avgTransaction,
		},
	}

	return &res, nil
}

// previousPeriod is what a range is compared with: the same days of last month
// when the range starts on the 1st and stays in one month (this month so far,
// last month), otherwise the same length right before it. Times are local.
func previousPeriod(start, end time.Time) (time.Time, time.Time) {
	if start.Day() == 1 && start.Year() == end.Year() && start.Month() == end.Month() {
		prevStart := start.AddDate(0, -1, 0)
		lastDay := time.Date(start.Year(), start.Month(), 0, 0, 0, 0, 0, start.Location()).Day()
		prevEnd := time.Date(prevStart.Year(), prevStart.Month(), min(end.Day(), lastDay),
			end.Hour(), end.Minute(), end.Second(), end.Nanosecond(), end.Location())
		return prevStart, prevEnd
	}
	return start.Add(-end.Sub(start)), start.Add(-time.Nanosecond)
}
