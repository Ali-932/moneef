package services

import (
	"context"
	"fmt"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"log"
	"moneef/internal/db"
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
	log.Printf("🔧 [SERVICE] recived transaction '%s'Transaction details - Type: %s, Amount: %s %s, Date: %s ",
		params.Name, params.Type, params.Amount.String(), params.CurrencyCode, params.Date.Format("2006-01-02"))

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	userExist, err := repository.ProfileByIdExist(params.ProfileID)
	if err != nil {
		log.Printf("❌ [SERVICE] Error while retriving user information %v", err)
		return err
	}
	fmt.Printf("%v", userExist)
	if userExist == false {
		err = fmt.Errorf("❌ [SERVICE] This Profile Id does not exist in the database")
		log.Printf("❌ [SERVICE] This Profile Id does not exist in the database")
		return err
	}
	return db.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var (
			recID    uint
			recIDPtr *uint
		)

		if params.IsRecurrent != nil && *params.IsRecurrent {
			log.Println("🔄 [SERVICE] Processing recurrent transaction setup")
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

			log.Printf("🔄 [SERVICE] Recurrence config - Frequency: %s, HasEndDate: %t, IsActive: %t",
				freq, hasEnd, isActive)

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
				CategoryIDs:          params.CategoryIDs,
				Frequency:            freq,
				HasEndDate:           hasEnd,
				EndDate:              params.EndDate,
				IsActive:             isActive,
				AmountPaidPreviously: params.AmountPaidPreviously,
				TotalAmountToPay:     params.TotalAmountToPay,
			}
			Id, err := CreateTransactionRecurrentWithTx(tx, p)
			recID = Id
			recIDPtr = &recID
			if err != nil {
				log.Printf("❌ [SERVICE] Failed to create recurrence template: %v", err)
				return err
			}
			log.Printf("✅ [SERVICE] Created recurrence template with ID: %d", recID)
		}

		log.Printf("💾 [SERVICE] Creating transaction record with %d categories", len(params.CategoryIDs))
		if err := CreateTransactionWithTx(tx, CreateTransactionParams{
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
			log.Printf("❌ [SERVICE] Failed to create transaction: %v", err)
			return err
		}

		log.Printf("✅ [SERVICE] Transaction creation completed successfully")
		return nil
	})
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

func CreateTransactionWithTx(tx *gorm.DB, p CreateTransactionParams) error {
	categories, err := repository.GetCategoriesByIDs(tx, p.CategoryIDs)
	if err != nil {
		log.Printf("❌ [SERVICE] Failed to fetch categories %v: %v", p.CategoryIDs, err)
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

	if err := repository.CreateTransaction(tx, trx); err != nil {
		log.Printf("❌ [SERVICE] Database persistence failed: %v", err)
		return err
	}
	log.Printf("✅ [SERVICE] Transaction persisted successfully")
	return nil
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
	CategoryIDs          []uint
	Frequency            string
	HasEndDate           bool
	EndDate              *time.Time
	IsActive             bool
	NextPaymentAmount    *decimal.Decimal
	AmountPaidPreviously *decimal.Decimal
	AmountLeftToPay      *decimal.Decimal
	TotalAmountToPay     *decimal.Decimal
}

func CreateTransactionRecurrentWithTx(tx *gorm.DB, p CreateTransactionRecurrentParams) (uint, error) {
	amt := types.Money(p.Amount)

	categories, err := repository.GetCategoriesByIDs(tx, p.CategoryIDs)
	if err != nil {
		return 0, err
	}

	nextDate, err := utils.CalculateNextOccurrence(p.StartDate, p.Frequency)
	if err != nil {
		log.Printf("❌ [SERVICE] Failed to calculate next occurrence: %v", err)
		return 0, err
	}

	var nextPaymentAmount types.Money
	var AmountLeftToPay *types.Money
	if p.HasEndDate {
		log.Println("💰 [SERVICE] Processing finite recurrence with end date")
		paidRemaining := p.TotalAmountToPay.Sub(*p.AmountPaidPreviously)
		if paidRemaining.Cmp(p.Amount) < 0 {
			nextPaymentAmount = types.Money(paidRemaining)
		} else {
			nextPaymentAmount = amt
		}
		amountLeft := types.Money(paidRemaining)
		amountLeft = amountLeft.MathOperation(types.Money(p.Amount), decimal.Decimal.Sub)
		AmountLeftToPay = &amountLeft
		log.Printf("💰 [SERVICE] Amount left to pay: %s", AmountLeftToPay.String())
	} else {
		log.Println("♾️ [SERVICE] Processing infinite recurrence")
		nextPaymentAmount = amt
		AmountLeftToPay = nil
	}
	trxRecurrent := &models.RecurrenceTemplate{
		ProfileID:    p.ProfileID,
		Name:         p.Name,
		Type:         p.Type,
		Amount:       &amt,
		CurrencyCode: p.CurrencyCode,
		Icon:         p.Icon,
		Color:        p.Color,
		MerchantName: p.MerchantName,
		Notes:        p.Notes,
		Category:     categories,
		Frequency:    p.Frequency,
		NextDate:     nextDate,
		HasEndDate:   p.HasEndDate,
		IsActive:     p.IsActive,

		NextPaymentAmount:    &nextPaymentAmount,
		AmountLeftToPay:      AmountLeftToPay,
		TotalAmountToPay:     (*types.Money)(p.TotalAmountToPay),
		AmountPaidPreviously: (*types.Money)(p.AmountPaidPreviously),
		EndDate:              p.EndDate,
		StartDate:            &p.StartDate,
	}

	id, err := repository.CreateTransactionRecurrent(tx, trxRecurrent)

	if err != nil {
		log.Printf("❌ [SERVICE] Failed to persist recurrence template: %v", err)
		return 0, err
	}
	log.Printf("✅ [SERVICE] Recurrence template persisted with ID: %d", id)
	return id, nil
}
