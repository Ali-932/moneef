package service

import (
	"context"
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
		totalIncome               types.Money
		transactionCount          int
		biggestTransaction        dto.BiggestTransaction
		topMerchant               dto.TopMerchant
	)
	g, _ := errgroup.WithContext(context.Background())
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
	spendByCategorySortedLastPeriod := utils.GetCategoriesSlicedAndSorted(spendByCategoryLastPeriod, total)
	spendPerDaySorted := utils.FillMissingDates(spendPerDay, startDate, endDate)
	spendPerDaySortedLastPeriod := utils.FillMissingDates(spendPerDayLastPeriod, lastPeriodStart, lastPeriodEnd)

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
