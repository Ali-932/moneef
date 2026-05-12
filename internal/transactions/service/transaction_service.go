package service

import (
	"context"
	"fmt"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/transactions/dto"
	"moneef/internal/transactions/engine"
	"moneef/internal/transactions/repository"
	usersRepository "moneef/internal/users/repository"
	"moneef/pkg/types"
	"moneef/pkg/utils"
	"sort"
	"time"
)

func HandleTransactionCreation(params dto.TransactionCreationParams) error {
	log.Printf("🔧 [SERVICE] recived transaction '%s'Transaction details - Type: %s, Date: %s ",
		params.Name, params.Type, params.Date.Format("2006-01-02"))

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	userExist, err := usersRepository.ProfileByIdExist(params.ProfileID)
	if err != nil {
		log.Printf("❌ [SERVICE] Error while retriving user information %v", err)
		return err
	}
	if userExist == false {
		err = fmt.Errorf("❌ [SERVICE] This Profile Id does not exist in the database")
		log.Printf("❌ [SERVICE] This Profile Id does not exist in the database")
		return err
	}
	return db.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var (
			recID         uint
			recIDPtr      *uint
			transactionID uint
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

			p := dto.CreateTransactionRecurrentParams{
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

		transactionID, err := CreateTransactionWithTx(tx, dto.CreateTransactionParams{
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
		})
		if err != nil {
			log.Printf("❌ [SERVICE] Failed to create transaction: %v", err)
			return err
		}

		log.Printf("✅ [SERVICE] Transaction creation completed successfully")
		engine.ResolveMerchantIconAsync(transactionID)
		return nil
	})
}

func CreateTransactionWithTx(tx *gorm.DB, p dto.CreateTransactionParams) (uint, error) {

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

	Id, err := repository.CreateTransaction(tx, trx)
	if err != nil {
		log.Printf("❌ [SERVICE] Database persistence failed: %v", err)
		return 0, err
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
	err = repository.CreateTransactionCategoryBulk(tx, transactionCategory)
	if err != nil {
		return 0, err
	}

	return *Id, nil
}

func CreateTransactionRecurrentWithTx(tx *gorm.DB, p dto.CreateTransactionRecurrentParams) (uint, error) {
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

	id, err := repository.CreateTransactionRecurrent(tx, trxRecurrent)

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

	err = repository.CreateTransactionCategoryRecurrentBulk(tx, transactionCategories)
	if err != nil {
		log.Printf("❌ [SERVICE] Failed to create transaction-category associations: %v", err)
		return 0, err
	}
	log.Printf("✅ [SERVICE] Recurrence template persisted with ID: %d", id)
	return id, nil
}

func GetTransaction(id uint, profileID uint) (*models.Transaction, error) {
	return repository.GetTransactionByID(db.DB, id, profileID)
}

func ListTransactions(profileID uint, txType string, categoryID uint, dateFrom, dateTo, search, categoryName string, sort string) *gorm.DB {
	return repository.ListTransactionsQuery(db.DB, profileID, txType, categoryID, dateFrom, dateTo, search, categoryName, sort)
}

func UpdateTransaction(id uint, profileID uint, req dto.TransactionUpdateRequest, categoriesMap map[uint]decimal.Decimal) error {
	err := db.DB.Transaction(func(tx *gorm.DB) error {
		updates := make(map[string]interface{})
		if req.TransactionName != "" {
			updates["name"] = req.TransactionName
		}
		if req.CurrencyCode != "" {
			updates["currency_code"] = req.CurrencyCode
		}
		if req.TransactionType != "" {
			updates["type"] = req.TransactionType
		}
		if req.MerchantName != nil {
			updates["merchant_name"] = *req.MerchantName
		}
		if req.Notes != nil {
			updates["notes"] = *req.Notes
		}
		if !req.Date.IsZero() {
			updates["date"] = req.Date
		}

		if len(updates) > 0 {
			if err := repository.UpdateTransaction(tx, id, profileID, updates); err != nil {
				return err
			}
		}

		if len(categoriesMap) > 0 {
			var newCategories []*models.TransactionCategory
			for catID, catAmt := range categoriesMap {
				c := types.Money(catAmt)
				newCategories = append(newCategories, &models.TransactionCategory{
					CategoryID:    catID,
					Amount:        &c,
					TransactionID: id,
				})
			}
			if err := repository.ReplaceTransactionCategories(tx, id, newCategories); err != nil {
				return err
			}
		}

		return nil
	})
	if err != nil {
		return err
	}
	engine.ResolveMerchantIconAsync(id)
	return nil
}

func DeleteTransaction(id uint, profileID uint) error {
	return db.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("transaction_id = ?", id).Delete(&models.TransactionCategory{}).Error; err != nil {
			return err
		}
		return repository.DeleteTransaction(tx, id, profileID)
	})
}

func ListRecurrences(profileID uint) ([]models.RecurrenceTemplate, error) {
	return repository.ListRecurrenceTemplates(profileID)
}

func UpdateRecurrence(profileID, id uint, updates map[string]interface{}) error {
	return repository.UpdateRecurrenceTemplate(profileID, id, updates)
}

func DeleteRecurrence(profileID, id uint) error {
	return repository.DeleteRecurrenceTemplate(profileID, id)
}

func daysInMonth(y int, m time.Month) int {
	return time.Date(y, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
}

func addFrequency(t time.Time, freq string) time.Time {
	switch freq {
	case "daily":
		return t.AddDate(0, 0, 1)
	case "weekly":
		return t.AddDate(0, 0, 7)
	case "bi-weekly":
		return t.AddDate(0, 0, 14)
	case "monthly":
		y, m, _ := t.Date()
		targetYear, targetMonth := y, m+1
		if targetMonth > 12 {
			targetYear++
			targetMonth = 1
		}
		day := min(t.Day(), daysInMonth(targetYear, targetMonth))
		return time.Date(targetYear, targetMonth, day, 0, 0, 0, 0, time.UTC)
	case "yearly":
		y, m, d := t.Date()
		targetYear := y + 1
		day := min(d, daysInMonth(targetYear, m))
		return time.Date(targetYear, m, day, 0, 0, 0, 0, time.UTC)
	default:
		return t
	}
}

func subFrequency(t time.Time, freq string) time.Time {
	switch freq {
	case "daily":
		return t.AddDate(0, 0, -1)
	case "weekly":
		return t.AddDate(0, 0, -7)
	case "bi-weekly":
		return t.AddDate(0, 0, -14)
	case "monthly":
		y, m, _ := t.Date()
		targetYear, targetMonth := y, m-1
		if targetMonth < 1 {
			targetYear--
			targetMonth = 12
		}
		day := min(t.Day(), daysInMonth(targetYear, targetMonth))
		return time.Date(targetYear, targetMonth, day, 0, 0, 0, 0, time.UTC)
	case "yearly":
		y, m, d := t.Date()
		targetYear := y - 1
		day := min(d, daysInMonth(targetYear, m))
		return time.Date(targetYear, m, day, 0, 0, 0, 0, time.UTC)
	default:
		return t
	}
}

func GetRecurrenceTimeline(profileID uint) ([]dto.RecurrenceOccurrence, error) {
	now := time.Now().UTC()
	windowStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	windowEnd := windowStart.AddDate(0, 0, 30).Add(23*time.Hour + 59*time.Minute + 59*time.Second)

	// Fetch user's base currency
	var profile models.Profile
	baseCurrency := "USD"
	if err := db.DB.First(&profile, profileID).Error; err == nil {
		var settings models.UserSettings
		if err := db.DB.Where("user_id = ?", profile.UserID).First(&settings).Error; err == nil {
			baseCurrency = settings.CurrencyCode
		}
	}

	templates, err := repository.GetActiveRecurrenceTemplatesForProfile(profileID, windowStart)
	if err != nil {
		return nil, err
	}

	var occurrences []dto.RecurrenceOccurrence

	for _, tpl := range templates {
		if tpl.NextPaymentAmount == nil {
			continue
		}

		anchor := time.Date(tpl.NextDate.Year(), tpl.NextDate.Month(), tpl.NextDate.Day(), 0, 0, 0, 0, time.UTC)
		freq := tpl.Frequency

		dateSet := make(map[string]time.Time)

		projected := anchor
		steps := 0
		for !projected.Before(windowStart) && steps < 400 {
			if !projected.Before(windowStart) && !projected.After(windowEnd) {
				dateSet[projected.Format("2006-01-02")] = projected
			}
			projected = subFrequency(projected, freq)
			steps++
		}
		if steps >= 400 {
			log.Printf("⚠️ [SERVICE] Recurrence template %d exceeded 400 backward steps, skipping", tpl.ID)
			continue
		}

		projected = addFrequency(anchor, freq)
		steps = 0
		for !projected.After(windowEnd) && steps < 400 {
			if !projected.Before(windowStart) {
				dateSet[projected.Format("2006-01-02")] = projected
			}
			projected = addFrequency(projected, freq)
			steps++
		}
		if steps >= 400 {
			log.Printf("⚠️ [SERVICE] Recurrence template %d exceeded 400 forward steps, skipping", tpl.ID)
			continue
		}

		convertedAmount := utils.ConvertMoney(db.DB, *tpl.NextPaymentAmount, tpl.CurrencyCode, baseCurrency)
		for _, date := range dateSet {
			occurrences = append(occurrences, dto.RecurrenceOccurrence{
				ID:       tpl.ID,
				Name:     tpl.Name,
				Type:     tpl.Type,
				Amount:   convertedAmount,
				Currency: baseCurrency,
				Icon:     tpl.Icon,
				Color:    tpl.Color,
				Date:     date,
			})
		}
	}

	sort.Slice(occurrences, func(i, j int) bool {
		return occurrences[i].Date.Before(occurrences[j].Date)
	})

	return occurrences, nil
}
