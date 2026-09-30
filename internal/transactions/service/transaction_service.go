package service

import (
	"context"
	"errors"
	"fmt"
	"log"
	accsvc "moneef/internal/accounts/service"
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

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
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
	var transactionID uint
	err = db.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var (
			recID    uint
			recIDPtr *uint
		)
		accountID, err := accsvc.Resolve(tx, params.ProfileID, params.AccountID)
		if err != nil {
			return err
		}

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
				AccountID:             &accountID,
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

		id, err := CreateTransactionWithTx(tx, dto.CreateTransactionParams{
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
			AccountID:             &accountID,
		})
		if err != nil {
			log.Printf("❌ [SERVICE] Failed to create transaction: %v", err)
			return err
		}
		transactionID = id
		log.Printf("✅ [SERVICE] Transaction creation completed successfully")
		return nil
	})
	if err != nil {
		return err
	}
	engine.ResolveMerchantIconAsync(transactionID)
	return nil
}

func CreateTransactionWithTx(tx *gorm.DB, p dto.CreateTransactionParams) (uint, error) {
	if p.AccountID == nil { // recurring payments saved before accounts existed
		id, err := accsvc.Resolve(tx, p.ProfileID, nil)
		if err != nil {
			return 0, err
		}
		p.AccountID = &id
	}

	trx := &models.Transaction{
		UsdRate:              usdRate(tx, p.CurrencyCode),
		AccountID:            p.AccountID,
		ProfileID:            p.ProfileID,
		Name:                 p.Name,
		Type:                 p.Type,
		Date:                 p.Date,
		CurrencyCode:         p.CurrencyCode,
		Icon:                 p.Icon,
		Color:                p.Color,
		IconSource:           engine.IconSourceForInput(p.Icon),
		ColorSource:          engine.IconSourceForInput(p.Color),
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
		if p.TotalAmountToPay == nil || p.AmountPaidPreviously == nil {
			return 0, fmt.Errorf("total_amount_to_pay and amount_paid_previously are required for finite recurrence")
		}
		paidRemaining := p.TotalAmountToPay.Sub(*p.AmountPaidPreviously)
		if decimal.Decimal(paidRemaining).LessThan(TransactionTotalAmount) {
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
		AccountID:    p.AccountID,
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
			// Only a new currency takes a new rate; other edits keep the frozen one.
			var current string
			if err := tx.Model(&models.Transaction{}).Where("id = ? AND profile_id = ?", id, profileID).
				Pluck("currency_code", &current).Error; err != nil {
				return err
			}
			if current != req.CurrencyCode {
				updates["usd_rate"] = usdRate(tx, req.CurrencyCode)
			}
		}
		if req.TransactionType != "" {
			updates["type"] = req.TransactionType
		}
		if req.AccountID != nil {
			if _, err := accsvc.Resolve(tx, profileID, req.AccountID); err != nil {
				return err
			}
			updates["account_id"] = *req.AccountID
		}
		if req.MerchantName != nil {
			updates["merchant_name"] = *req.MerchantName
		}
		if req.Notes != nil {
			updates["notes"] = *req.Notes
		}
		if req.Icon != "" {
			updates["icon"] = req.Icon
			updates["icon_source"] = engine.IconSourceManual
		}
		if req.Color != "" {
			updates["color"] = req.Color
			updates["color_source"] = engine.IconSourceManual
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

// usdRate is today's settings rate for 1 USD in currency, or nil when there is none.
func usdRate(tx *gorm.DB, currency string) *decimal.Decimal {
	rate, err := utils.ConvertAmount(tx, decimal.NewFromInt(1), "USD", currency)
	if err != nil {
		return nil
	}
	return &rate
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

// CreateDueRecurrences books every occurrence of the profile's active
// templates dated at or before now and moves next_date past it. A finite plan
// books at most what is left to pay and stops once its end date passes or
// nothing is left. Returns how many transactions were created.
func CreateDueRecurrences(profileID uint, now time.Time) (int, error) {
	templates, err := repository.ListRecurrenceTemplates(profileID)
	if err != nil {
		return 0, err
	}
	var created []uint
	var errs []error
	for _, tpl := range templates {
		if !tpl.IsActive || tpl.NextDate.After(now) {
			continue
		}
		total := decimal.Zero
		for _, c := range tpl.TransactionCategory {
			total = total.Add(decimal.Decimal(*c.Amount))
		}
		finite := tpl.HasEndDate && tpl.AmountLeftToPay != nil
		var left decimal.Decimal
		if finite {
			left = decimal.Decimal(*tpl.AmountLeftToPay)
		}
		ended := func() bool {
			return (tpl.HasEndDate && tpl.EndDate != nil && tpl.NextDate.After(*tpl.EndDate)) ||
				(finite && !left.IsPositive())
		}
		var booked []uint
		err := db.DB.Transaction(func(tx *gorm.DB) error {
			for !ended() && !tpl.NextDate.After(now) {
				pay := total
				if finite {
					pay = decimal.Min(left, total)
				}
				// A short last payment is split by the categories' shares; the
				// last category takes the rounding remainder.
				amounts := make(map[uint]decimal.Decimal, len(tpl.TransactionCategory))
				rest := pay
				for i, c := range tpl.TransactionCategory {
					amt := decimal.Decimal(*c.Amount)
					if pay.LessThan(total) {
						if i < len(tpl.TransactionCategory)-1 {
							amt = amt.Mul(pay).DivRound(total, 4)
						} else {
							amt = rest
						}
						rest = rest.Sub(amt)
					}
					amounts[c.CategoryID] = amt
				}
				id, err := CreateTransactionWithTx(tx, dto.CreateTransactionParams{
					ProfileID: tpl.ProfileID, Name: tpl.Name, Type: tpl.Type, Date: tpl.NextDate,
					CurrencyCode: tpl.CurrencyCode, Icon: tpl.Icon, Color: tpl.Color,
					MerchantName: tpl.MerchantName, Notes: tpl.Notes,
					CategoriesTransaction: amounts, RecurrenceTemplateID: &tpl.ID, AccountID: tpl.AccountID,
				})
				if err != nil {
					return err
				}
				booked = append(booked, id)
				left = left.Sub(pay)
				// ponytail: steps from the stored date, so a schedule on the 29th-31st
				// clamps after a short month and stays there. Anchor on start_date if that matters.
				next := addFrequency(tpl.NextDate, tpl.Frequency)
				if !next.After(tpl.NextDate) {
					return fmt.Errorf("unsupported frequency %q", tpl.Frequency)
				}
				tpl.NextDate = next
			}
			updates := map[string]interface{}{"next_date": tpl.NextDate, "is_active": !ended()}
			if finite {
				updates["amount_left_to_pay"] = left
				updates["next_payment_amount"] = decimal.Max(decimal.Min(left, total), decimal.Zero)
			}
			return tx.Model(&models.RecurrenceTemplate{}).Where("id = ?", tpl.ID).Updates(updates).Error
		})
		if err != nil {
			errs = append(errs, fmt.Errorf("recurrence %d: %w", tpl.ID, err))
			continue
		}
		created = append(created, booked...)
	}
	for _, id := range created {
		engine.ResolveMerchantIconAsync(id)
	}
	if len(created) > 0 {
		log.Printf("🔄 [SERVICE] Booked %d due recurring transactions", len(created))
	}
	return len(created), errors.Join(errs...)
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
		return time.Date(targetYear, targetMonth, day, t.Hour(), t.Minute(), t.Second(), t.Nanosecond(), t.Location())
	case "yearly":
		y, m, d := t.Date()
		targetYear := y + 1
		day := min(d, daysInMonth(targetYear, m))
		return time.Date(targetYear, m, day, t.Hour(), t.Minute(), t.Second(), t.Nanosecond(), t.Location())
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

		convertedAmount, convErr := utils.ConvertMoney(db.DB, *tpl.NextPaymentAmount, tpl.CurrencyCode, baseCurrency)
		displayCurrency := baseCurrency
		if convErr != nil {
			convertedAmount = *tpl.NextPaymentAmount
			displayCurrency = tpl.CurrencyCode
		}
		for _, date := range dateSet {
			occurrences = append(occurrences, dto.RecurrenceOccurrence{
				ID:       tpl.ID,
				Name:     tpl.Name,
				Type:     tpl.Type,
				Amount:   convertedAmount,
				Currency: displayCurrency,
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
