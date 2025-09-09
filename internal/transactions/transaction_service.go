package transactions

import (
	"context"
	"fmt"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"log"
	"moneef/internal/auth"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"time"
)

type TransactionCreationParams struct {
	ProfileID             uint
	Name                  string
	Type                  string
	Date                  time.Time
	CurrencyCode          string
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	RecurrenceTemplateID  *uint
	IsRecurrent           *bool
	Frequency             *string
	AmountPaidPreviously  *decimal.Decimal
	TotalAmountToPay      *decimal.Decimal
	EndDate               *time.Time
	HasEndDate            *bool
	IsActive              *bool
}

func HandleTransactionCreation(params TransactionCreationParams) error {
	log.Printf("🔧 [SERVICE] recived transaction '%s'Transaction details - Type: %s, Date: %s ",
		params.Name, params.Type, params.Date.Format("2006-01-02"))

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	userExist, err := auth.ProfileByIdExist(params.ProfileID)
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
				ProfileID:             params.ProfileID,
				Name:                  params.Name,
				CurrencyCode:          params.CurrencyCode,
				Type:                  params.Type,
				StartDate:             params.Date,
				Icon:                  params.Icon,
				Color:                 params.Color,
				MerchantName:          params.MerchantName,
				Notes:                 params.Notes,
				CategoriesTransaction: params.CategoriesTransaction,
				Frequency:             freq,
				HasEndDate:            hasEnd,
				EndDate:               params.EndDate,
				IsActive:              isActive,
				AmountPaidPreviously:  params.AmountPaidPreviously,
				TotalAmountToPay:      params.TotalAmountToPay,
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

		if err := CreateTransactionWithTx(tx, CreateTransactionParams{
			ProfileID:             params.ProfileID,
			Name:                  params.Name,
			CurrencyCode:          params.CurrencyCode,
			Type:                  params.Type,
			Date:                  params.Date,
			Icon:                  params.Icon,
			Color:                 params.Color,
			MerchantName:          params.MerchantName,
			Notes:                 params.Notes,
			CategoriesTransaction: params.CategoriesTransaction,
			RecurrenceTemplateID:  recIDPtr,
		}); err != nil {
			log.Printf("❌ [SERVICE] Failed to create transaction: %v", err)
			return err
		}

		log.Printf("✅ [SERVICE] Transaction creation completed successfully")
		return nil
	})
}

type CreateTransactionParams struct {
	ProfileID             uint
	Name                  string
	CurrencyCode          string
	Type                  string
	Date                  time.Time
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	RecurrenceTemplateID  *uint
}

func CreateTransactionWithTx(tx *gorm.DB, p CreateTransactionParams) error {

	trx := &models.Transaction{
		ProfileID:            p.ProfileID,
		Name:                 p.Name,
		Type:                 p.Type,
		Date:                 p.Date,
		CurrencyCode:         p.CurrencyCode,
		Icon:                 p.Icon,
		Color:                p.Color,
		MerchantName:         p.MerchantName,
		Notes:                p.Notes,
		RecurrenceTemplateID: p.RecurrenceTemplateID,
	}

	Id, err := CreateTransaction(tx, trx)
	if err != nil {
		log.Printf("❌ [SERVICE] Database persistence failed: %v", err)
		return err
	}
	log.Printf("✅ [SERVICE] Transaction persisted successfully")
	transactionCategory := make([]*models.TransactionCategory, 0, len(p.CategoriesTransaction))
	for catID, catAmt := range p.CategoriesTransaction {
		c := types.Money(catAmt)
		transactionCategory = append(transactionCategory, &models.TransactionCategory{
			CategoryID:    catID,
			Amount:        &c,
			TransactionID: *Id,
		})
	}
	err = CreateTransactionCategoryBulk(tx, transactionCategory)
	if err != nil {
		return err
	}

	return nil
}

type CreateTransactionRecurrentParams struct {
	ProfileID             uint
	Name                  string
	CurrencyCode          string
	Type                  string
	StartDate             time.Time
	Icon                  string
	Color                 string
	MerchantName          *string
	Notes                 *string
	CategoriesTransaction map[uint]decimal.Decimal
	Frequency             string
	HasEndDate            bool
	EndDate               *time.Time
	IsActive              bool
	NextPaymentAmount     *decimal.Decimal
	AmountPaidPreviously  *decimal.Decimal
	AmountLeftToPay       *decimal.Decimal
	TotalAmountToPay      *decimal.Decimal
}

func CreateTransactionRecurrentWithTx(tx *gorm.DB, p CreateTransactionRecurrentParams) (uint, error) {
	TransactionTotalAmount := decimal.NewFromInt(0)
	for _, amt := range p.CategoriesTransaction {
		TransactionTotalAmount = TransactionTotalAmount.Add(amt)
	}
	TransactionTotalAmountMoney := types.Money(TransactionTotalAmount)
	log.Printf("💰 [SERVICE] Total amount for next payment: %s", TransactionTotalAmountMoney.String())

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
		if paidRemaining.Cmp(TransactionTotalAmount) < 0 {
			nextPaymentAmount = types.Money(paidRemaining)
		} else {
			nextPaymentAmount = TransactionTotalAmountMoney
		}
		amountLeft := types.Money(paidRemaining)
		amountLeft = amountLeft.MathOperation(TransactionTotalAmountMoney, decimal.Decimal.Sub)
		AmountLeftToPay = &amountLeft
		log.Printf("💰 [SERVICE] Amount left to pay: %s", AmountLeftToPay.String())
	} else {
		log.Println("♾️ [SERVICE] Processing infinite recurrence")
		nextPaymentAmount = TransactionTotalAmountMoney
		AmountLeftToPay = nil
	}

	trxRecurrent := &models.RecurrenceTemplate{
		ProfileID:    p.ProfileID,
		Name:         p.Name,
		Type:         p.Type,
		CurrencyCode: p.CurrencyCode,
		Icon:         p.Icon,
		Color:        p.Color,
		MerchantName: p.MerchantName,
		Notes:        p.Notes,
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

	id, err := CreateTransactionRecurrent(tx, trxRecurrent)

	if err != nil {
		log.Printf("❌ [SERVICE] Failed to persist recurrence template: %v", err)
		return 0, err
	}
	transactionCategories := make([]*models.RecurrenceTemplateCategory, 0, len(p.CategoriesTransaction))
	for catID, catAmt := range p.CategoriesTransaction {
		c := types.Money(catAmt)
		transactionCategories = append(transactionCategories, &models.RecurrenceTemplateCategory{
			CategoryID:           catID,
			Amount:               &c,
			RecurrenceTemplateID: id,
		})
	}

	err = CreateTransactionCategoryRecurrentBulk(tx, transactionCategories)
	if err != nil {
		log.Printf("❌ [SERVICE] Failed to create transaction-category associations: %v", err)
		return 0, err
	}
	log.Printf("✅ [SERVICE] Recurrence template persisted with ID: %d", id)
	return id, nil
}
