package db

import (
	"fmt"
	"math/rand"
	"time"

	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/pkg/utils"
)

// Seed inserts essential/default data into the database.
// It is safe to call multiple times; it will not duplicate records.
func Seed(database *gorm.DB) error {
	if err := seedCategories(database); err != nil {
		return fmt.Errorf("seeding categories: %w", err)
	}
	if err := seedCurrencies(database); err != nil {
		return fmt.Errorf("seeding currencies: %w", err)
	}
	if err := seedUsersAndProfiles(database); err != nil {
		return fmt.Errorf("seeding users and profiles: %w", err)
	}
	return nil
}

func seedUsersAndProfiles(database *gorm.DB) error {
	rand.Seed(time.Now().UnixNano())

	type userSeed struct {
		Email     string
		Password  string
		FirstName string
		LastName  string
	}
	const userPassword string = "Password123!"
	users := []userSeed{
		{Email: "alice@example.com", Password: userPassword, FirstName: "Alice", LastName: "Johnson"},
		{Email: "bob@example.com", Password: userPassword, FirstName: "Bob", LastName: "Smith"},
		{Email: "carol@example.com", Password: userPassword, FirstName: "Carol", LastName: "Williams"},
		{Email: "dave@example.com", Password: userPassword, FirstName: "Dave", LastName: "Brown"},
		{Email: "eve@example.com", Password: userPassword, FirstName: "Eve", LastName: "Davis"},
	}

	for _, u := range users {
		var existing int64
		if err := database.Model(&models.User{}).Where("email = ?", u.Email).Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			continue
		}

		hashed, err := utils.HashPassword(u.Password)
		if err != nil {
			return fmt.Errorf("hashing password for %s: %w", u.Email, err)
		}

		user := models.User{
			Email:    u.Email,
			Password: string(hashed),
			IsStaff:  "false",
		}
		if err := database.Create(&user).Error; err != nil {
			return fmt.Errorf("creating user %s: %w", u.Email, err)
		}

		profile := models.Profile{
			FirstName: u.FirstName,
			LastName:  u.LastName,
			UserID:    user.ID,
		}
		if err := database.Create(&profile).Error; err != nil {
			return fmt.Errorf("creating profile for %s: %w", u.Email, err)
		}

		settings := models.UserSettings{
			UserID:                user.ID,
			Locale:                "en-US",
			IsNotificationEnabled: true,
			IsDarkMode:            rand.Intn(2) == 0,
		}
		if err := database.Create(&settings).Error; err != nil {
			return fmt.Errorf("creating user settings for %s: %w", u.Email, err)
		}
	}
	return nil
}

func seedCategories(database *gorm.DB) error {
	tExpense := "expense"
	tIncome := "income"
	type defaultCategory struct {
		Name  string
		Type  string
		Icon  string
		Color string
	}

	defaults := []defaultCategory{
		// Expense Categories
		{Name: "Food", Type: tExpense, Icon: "restaurant", Color: "#FF6B6B"},
		{Name: "Transport", Type: tExpense, Icon: "directions_car", Color: "#4D96FF"},
		{Name: "Utilities", Type: tExpense, Icon: "flash_on", Color: "#FFD93D"},
		{Name: "Entertainment", Type: tExpense, Icon: "movie", Color: "#845EC2"},
		{Name: "Shopping", Type: tExpense, Icon: "shopping_bag", Color: "#FF9671"},
		{Name: "Healthcare", Type: tExpense, Icon: "local_hospital", Color: "#00C9A7"},
		{Name: "Housing", Type: tExpense, Icon: "home", Color: "#8B4513"},
		{Name: "Personal Care", Type: tExpense, Icon: "spa", Color: "#FF69B4"},
		{Name: "Education", Type: tExpense, Icon: "school", Color: "#20B2AA"},
		{Name: "Insurance", Type: tExpense, Icon: "security", Color: "#6495ED"},
		{Name: "Travel", Type: tExpense, Icon: "flight", Color: "#32CD32"},
		{Name: "Business", Type: tExpense, Icon: "business_center", Color: "#708090"},
		{Name: "Savings", Type: tExpense, Icon: "savings", Color: "#228B22"},
		{Name: "Debt", Type: tExpense, Icon: "credit_card", Color: "#DC143C"},
		{Name: "Gifts", Type: tExpense, Icon: "featured_seasonal_and_gifts", Color: "#DA70D6"},

		// Income Categories
		{Name: "Salary", Type: tIncome, Icon: "work", Color: "#00C9A7"},
		{Name: "Business", Type: tIncome, Icon: "business_center", Color: "#2BB673"},
		{Name: "Investments", Type: tIncome, Icon: "trending_up", Color: "#228B22"},
		{Name: "Benefits", Type: tIncome, Icon: "account_balance", Color: "#4682B4"},
		{Name: "Side Income", Type: tIncome, Icon: "handyman", Color: "#FF8C00"},
		{Name: "Gifts", Type: tIncome, Icon: "featured_seasonal_and_gifts", Color: "#C34A36"},
	}

	for _, d := range defaults {
		var count int64
		// Check by name and global scope (ProfileID IS NULL)
		if err := database.Model(&models.Category{}).
			Where("name = ? AND profile_id IS NULL", d.Name).
			Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			continue
		}

		cat := models.Category{
			ProfileID: nil,
			Type:      &d.Type,
			Name:      d.Name,
			Icon:      d.Icon,
			Color:     d.Color,
		}
		if err := database.Create(&cat).Error; err != nil {
			return err
		}
	}
	return nil
}

func seedCurrencies(database *gorm.DB) error {
	type defaultCurrencies struct {
		Code   string
		Symbol string
		Name   string
	}

	defaults := []defaultCurrencies{
		// Major Global Currencies
		{Code: "USD", Symbol: "$", Name: "US Dollar"},
		{Code: "EUR", Symbol: "€", Name: "Euro"},
		{Code: "GBP", Symbol: "£", Name: "British Pound Sterling"},
		{Code: "JPY", Symbol: "¥", Name: "Japanese Yen"},
		{Code: "CNY", Symbol: "¥", Name: "Chinese Yuan"},
		{Code: "CAD", Symbol: "C$", Name: "Canadian Dollar"},
		{Code: "AUD", Symbol: "A$", Name: "Australian Dollar"},
		{Code: "CHF", Symbol: "CHF", Name: "Swiss Franc"},
		{Code: "SEK", Symbol: "kr", Name: "Swedish Krona"},
		{Code: "NOK", Symbol: "kr", Name: "Norwegian Krone"},
		{Code: "DKK", Symbol: "kr", Name: "Danish Krone"},
		{Code: "INR", Symbol: "₹", Name: "Indian Rupee"},
		{Code: "KRW", Symbol: "₩", Name: "South Korean Won"},
		{Code: "SGD", Symbol: "S$", Name: "Singapore Dollar"},
		{Code: "HKD", Symbol: "HK$", Name: "Hong Kong Dollar"},
		{Code: "NZD", Symbol: "NZ$", Name: "New Zealand Dollar"},
		{Code: "MXN", Symbol: "$", Name: "Mexican Peso"},
		{Code: "BRL", Symbol: "R$", Name: "Brazilian Real"},
		{Code: "RUB", Symbol: "₽", Name: "Russian Ruble"},
		{Code: "ZAR", Symbol: "R", Name: "South African Rand"},

		// Middle Eastern Currencies
		{Code: "IQD", Symbol: "ع.د", Name: "Iraqi Dinar"},
		{Code: "SAR", Symbol: "﷼", Name: "Saudi Riyal"},
		{Code: "AED", Symbol: "د.إ", Name: "UAE Dirham"},
		{Code: "QAR", Symbol: "﷼", Name: "Qatari Riyal"},
		{Code: "KWD", Symbol: "د.ك", Name: "Kuwaiti Dinar"},
		{Code: "BHD", Symbol: ".د.ب", Name: "Bahraini Dinar"},
		{Code: "OMR", Symbol: "﷼", Name: "Omani Rial"},
		{Code: "JOD", Symbol: "د.ا", Name: "Jordanian Dinar"},
		{Code: "LBP", Symbol: "ل.ل", Name: "Lebanese Pound"},
		{Code: "EGP", Symbol: "£", Name: "Egyptian Pound"},
		{Code: "ILS", Symbol: "₪", Name: "Israeli New Shekel"},
		{Code: "IRR", Symbol: "﷼", Name: "Iranian Rial"},
		{Code: "TRY", Symbol: "₺", Name: "Turkish Lira"},
	}

	for _, d := range defaults {
		var count int64
		if err := database.Model(&models.Currency{}).
			Where("code = ?", d.Code).
			Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			continue
		}

		cur := models.Currency{
			Code:   d.Code,
			Symbol: d.Symbol,
			Name:   d.Name,
		}
		if err := database.Create(&cur).Error; err != nil {
			return err
		}
	}
	return nil
}
