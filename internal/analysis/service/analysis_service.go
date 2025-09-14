package service

import (
	"context"
	"golang.org/x/sync/errgroup"
	"moneef/internal/analysis/dto"
	"moneef/internal/analysis/repository"
	"moneef/internal/analysis/utils"
	"moneef/internal/db"
	"moneef/pkg/types"
	"sync"
	"time"
)

func GetAllAnalysisChartsService(profileId uint, startDate, endDate time.Time) (*dto.AnalysisCharts, error) {
	period := endDate.Sub(startDate)
	lastPeriodEnd := startDate
	lastPeriodStart := startDate.Add(-period)

	var mu sync.Mutex

	var (
		spendByCategory           []dto.CategorySummary
		spendByCategoryLastPeriod []dto.CategorySummary
		spendPerDay               []dto.AmountPerDay
		spendPerDayLastPeriod     []dto.AmountPerDay
		total                     types.Money
		nextRecurringTransactions []dto.NextRecurringTransactions
	)
	g, _ := errgroup.WithContext(context.Background())
	g.Go(func() error {
		result, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, startDate, endDate, "USD")
		if err != nil {
			return err
		}
		mu.Lock()
		spendByCategory = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsGroupedByCategory(db.DB, profileId, lastPeriodStart, lastPeriodEnd, "USD")
		if err != nil {
			return err
		}
		mu.Lock()
		spendByCategoryLastPeriod = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionTotalExpense(db.DB, profileId, startDate, endDate, "USD")
		if err != nil {
			return err
		}
		mu.Lock()
		total = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsAmountPerDay(db.DB, profileId, startDate, endDate, "USD")
		if err != nil {
			return err
		}
		mu.Lock()
		spendPerDay = result
		mu.Unlock()
		return nil
	})

	g.Go(func() error {
		result, err := repository.GetTransactionsAmountPerDay(db.DB, profileId, lastPeriodStart, lastPeriodEnd, "USD")
		if err != nil {
			return err
		}
		mu.Lock()
		spendPerDayLastPeriod = result
		mu.Unlock()
		return nil
	})
	g.Go(func() error {
		result, err := repository.GetNextRecurringTransactions(db.DB, profileId, time.Now())
		if err != nil {
			return err
		}
		mu.Lock()
		nextRecurringTransactions = result
		mu.Unlock()
		return nil

	})
	if err := g.Wait(); err != nil {
		return nil, err
	}
	spendByCategorySorted := utils.GetCategoriesSlicedAndSorted(spendByCategory, total)
	spendByCategorySortedLastPeriod := utils.GetCategoriesSlicedAndSorted(spendByCategoryLastPeriod, total)
	spendPerDaySorted := utils.FillMissingDates(spendPerDay, startDate, endDate)
	spendPerDaySortedLastPeriod := utils.FillMissingDates(spendPerDayLastPeriod, lastPeriodStart, lastPeriodEnd)
	res := dto.AnalysisCharts{
		Categories:                spendByCategorySorted,
		CategoriesLastPeriod:      spendByCategorySortedLastPeriod,
		SpentPerDay:               spendPerDaySorted,
		SpentPerDayLastPeriod:     spendPerDaySortedLastPeriod,
		NextRecurringTransactions: nextRecurringTransactions,
		Total:                     total,
	}

	return &res, nil
}
