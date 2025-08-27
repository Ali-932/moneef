package services

import (
	"github.com/shopspring/decimal"
	"moneef/internal/models"
	"moneef/internal/repository"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"time"
)

type TransactionCreationParams struct {
	ProfileID            uint
	Name                 string
	Type                 string
	Date                 time.Time
	Amount               decimal.Decimal
	CurrencyCode         string
	Icon                 string
	Color                string
	MerchantName         *string
	Notes                *string
	CategoryIDs          []uint
	RecurrenceTemplateID *uint
	IsRecurrent          *bool
	Frequency            *string
	AmountPaidPreviously *decimal.Decimal
	TotalAmountToPay     *decimal.Decimal
	EndDate              *time.Time
	HasEndDate           *bool
	IsActive             *bool
}

func HandleTransactionCreation(params TransactionCreationParams) error {
	var (
		recID    uint
		recIDPtr *uint
	)
	if params.IsRecurrent != nil && *params.IsRecurrent {
		freq := ""
		if params.Frequency != nil {
			freq = *params.Frequency
		}
		hasEnd := false
		if params.HasEndDate != nil {
			hasEnd = *params.HasEndDate
		}
		isActive := true
		if params.IsActive != nil {
			isActive = *params.IsActive
		}

		p := CreateTransactionRecurrentParams{
			ProfileID:            params.ProfileID,
			Name:                 params.Name,
			Amount:               params.Amount,
			CurrencyCode:         params.CurrencyCode,
			Type:                 params.Type,
			StartDate:            params.Date,
			Icon:                 params.Icon,
			Color:                params.Color,
			MerchantName:         params.MerchantName,
			Notes:                params.Notes,
			Frequency:            freq,
			HasEndDate:           hasEnd,
			EndDate:              params.EndDate,
			IsActive:             isActive,
			AmountPaidPreviously: params.AmountPaidPreviously,
			TotalAmountToPay:     params.TotalAmountToPay,
		}
		Id, err := CreateTransactionRecurrent(p)
		recID = Id
		recIDPtr = &recID
		if err != nil {
			return err
		}
	}
	if err := CreateTransaction(CreateTransactionParams{
		ProfileID:            params.ProfileID,
		Name:                 params.Name,
		Amount:               params.Amount,
		CurrencyCode:         params.CurrencyCode,
		Type:                 params.Type,
		Date:                 params.Date,
		Icon:                 params.Icon,
		Color:                params.Color,
		MerchantName:         params.MerchantName,
		Notes:                params.Notes,
		CategoryIDs:          params.CategoryIDs,
		RecurrenceTemplateID: recIDPtr,
	}); err != nil {
		return err
	}
	return nil
}

type CreateTransactionParams struct {
	ProfileID            uint
	Name                 string
	Amount               decimal.Decimal
	CurrencyCode         string
	Type                 string
	Date                 time.Time
	Icon                 string
	Color                string
	MerchantName         *string
	Notes                *string
	CategoryIDs          []uint
	RecurrenceTemplateID *uint
}

func CreateTransaction(p CreateTransactionParams) error {
	categories, err := repository.GetCategoriesByIDs(p.CategoryIDs)
	if err != nil {
		return err
	}

	amt := types.Money(p.Amount)
	trx := &models.Transaction{
		ProfileID:            p.ProfileID,
		Name:                 p.Name,
		Type:                 p.Type,
		Date:                 p.Date,
		Amount:               &amt,
		CurrencyCode:         p.CurrencyCode,
		Icon:                 p.Icon,
		Color:                p.Color,
		MerchantName:         p.MerchantName,
		Notes:                p.Notes,
		Category:             categories,
		RecurrenceTemplateID: p.RecurrenceTemplateID,
	}
	return repository.CreateTransaction(trx)
}

type CreateTransactionRecurrentParams struct {
	ProfileID            uint
	Name                 string
	Amount               decimal.Decimal
	CurrencyCode         string
	Type                 string
	StartDate            time.Time
	Icon                 string
	Color                string
	MerchantName         *string
	Notes                *string
	Frequency            string
	HasEndDate           bool
	EndDate              *time.Time
	IsActive             bool
	NextPaymentAmount    *decimal.Decimal
	AmountPaidPreviously *decimal.Decimal
	AmountLeftToPay      *decimal.Decimal
	TotalAmountToPay     *decimal.Decimal
}

func CreateTransactionRecurrent(p CreateTransactionRecurrentParams) (uint, error) {
	amt := types.Money(p.Amount)

	nextDate, err := utils.CalculateNextOccurrence(p.StartDate, p.Frequency)
	if err != nil {
		return 0, err
	}
	var nextPaymentAmount types.Money
	var AmountLeftToPay *types.Money
	if p.HasEndDate {
		paidRemaining := p.TotalAmountToPay.Sub(*p.AmountPaidPreviously)
		if paidRemaining.Cmp(p.Amount) < 0 {
			nextPaymentAmount = types.Money(paidRemaining)
		} else {
			nextPaymentAmount = amt
		}
		amountLeft := types.Money(paidRemaining)
		AmountLeftToPay = &amountLeft

	} else {
		nextPaymentAmount = amt
		AmountLeftToPay = nil
	}
	trxRecurrent := &models.RecurrenceTemplate{
		ProfileID:            p.ProfileID,
		Name:                 p.Name,
		Type:                 p.Type,
		Amount:               &amt,
		CurrencyCode:         p.CurrencyCode,
		Icon:                 p.Icon,
		Color:                p.Color,
		MerchantName:         p.MerchantName,
		Notes:                p.Notes,
		Frequency:            p.Frequency,
		NextDate:             nextDate,
		HasEndDate:           p.HasEndDate,
		IsActive:             p.IsActive,
		NextPaymentAmount:    &nextPaymentAmount,
		AmountLeftToPay:      AmountLeftToPay,
		TotalAmountToPay:     (*types.Money)(p.TotalAmountToPay),
		AmountPaidPreviously: (*types.Money)(p.AmountPaidPreviously),
		EndDate:              p.EndDate,
	}

	return repository.CreateTransactionRecurrent(trxRecurrent)
}
