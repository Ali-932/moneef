/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"log"
	"math/rand"
	"moneef/internal/auth"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/internal/transactions/dto"
	"moneef/internal/transactions/service"
	"time"

	"github.com/shopspring/decimal"

	"github.com/spf13/cobra"
)

func SeedTransactions(cmd *cobra.Command, args []string) error {
	log.Printf("Starting transaction seeding...")
	database := db.DB

	// Get the first two users (alice and bob)
	var users []models.User
	//if err := database.Preload("Profile").Limit(2).Find(&users).Error; err != nil {
	//	return fmt.Errorf("failed to get users: %w", err)
	//}

	if err := database.Preload("Profile").Where("id = ?", 6).Limit(2).Find(&users).Error; err != nil {
		return fmt.Errorf("failed to get users: %w", err)
	}

	// Get all categories for mapping
	var categories []models.Category
	if err := database.Find(&categories).Error; err != nil {
		return fmt.Errorf("failed to get categories: %w", err)
	}

	categoryMap := make(map[string]uint)
	for _, cat := range categories {
		categoryMap[cat.Name] = cat.ID
	}

	log.Printf("Found %d users and %d categories", len(users), len(categories))

	// Generate tokens for both users
	tokens := make(map[uint]string)
	for _, user := range users {
		token, err := auth.GenerateJWT(user.Email)
		if err != nil {
			return fmt.Errorf("failed to generate token for %s: %w", user.Email, err)
		}
		tokens[user.Profile.ID] = token
		fmt.Printf("User: %s %s (Profile ID: %d)\n", user.Profile.FirstName, user.Profile.LastName, user.Profile.ID)
		fmt.Printf("Email: %s\n", user.Email)
		fmt.Printf("Token: %s\n\n", token)
	}

	// Seed transactions for each user
	for i, user := range users {
		if err := seedUserTransactions(user.Profile.ID, categoryMap, i+1); err != nil {
			return fmt.Errorf("failed to seed transactions for user %d: %w", user.Profile.ID, err)
		}
	}

	log.Printf("Transaction seeding completed successfully!")
	return nil
}

func seedUserTransactions(profileID uint, categoryMap map[string]uint, userNumber int) error {
	log.Printf("Seeding transactions for profile ID: %d", profileID)

	// Create realistic transaction scenarios
	scenarios := getRealisticScenarios(profileID, categoryMap, userNumber)

	for _, scenario := range scenarios {
		if err := service.HandleTransactionCreation(scenario); err != nil {
			log.Printf("Failed to create transaction %s: %v", scenario.Name, err)
			continue
		}
		log.Printf("Created transaction: %s", scenario.Name)
	}

	return nil
}

func getRealisticScenarios(profileID uint, categoryMap map[string]uint, userNumber int) []dto.TransactionCreationParams {
	rand.Seed(time.Now().UnixNano())
	now := time.Now()

	// Base scenarios for both users
	scenarios := []dto.TransactionCreationParams{}

	// Monthly Salary (Income)
	salaryAmount := decimal.NewFromInt(5000)
	if userNumber == 2 {
		salaryAmount = decimal.NewFromInt(4200) // Different salary for user 2
	}
	scenarios = append(scenarios, createMonthlyTransaction(
		profileID, "Monthly Salary", "income", categoryMap["Salary"],
		salaryAmount, "mdi:briefcase", "#00C9A7", now.AddDate(0, -3, 1), // Started 3 months ago
	))

	// Subscriptions (Recurring Expenses)
	subscriptions := []struct {
		name     string
		amount   decimal.Decimal
		category string
		icon     string
		color    string
	}{
		{"Netflix Subscription", decimal.NewFromFloat(15.99), "Entertainment", "mdi:movie", "#E50914"},
		{"Spotify Premium", decimal.NewFromFloat(9.99), "Entertainment", "mdi:spotify", "#1DB954"},
		{"AWS Hosting", decimal.NewFromFloat(25.50), "Business", "mdi:cloud", "#232F3E"},
	}

	for _, sub := range subscriptions {
		scenarios = append(scenarios, createMonthlyTransaction(
			profileID, sub.name, "expense", categoryMap[sub.category],
			sub.amount, sub.icon, sub.color, now.AddDate(0, -2, 15), // Started 2 months ago
		))
	}

	// Installment payments (Phone/Car)
	if userNumber == 1 {
		// iPhone installment - 24 months, started 6 months ago
		scenarios = append(scenarios, createInstallmentTransaction(
			profileID, "iPhone 15 Pro Installment", categoryMap["Shopping"],
			decimal.NewFromFloat(45.83), // $1100 / 24 months
			decimal.NewFromFloat(1100),
			decimal.NewFromFloat(275), // 6 months already paid
			now.AddDate(0, -6, 10),    // Started 6 months ago
			now.AddDate(0, 18, 10),    // Ends in 18 months
			"mdi:cellphone", "#007AFF",
		))
	} else {
		// Car loan installment - 60 months, started 1 year ago
		scenarios = append(scenarios, createInstallmentTransaction(
			profileID, "Car Loan Payment", categoryMap["Transport"],
			decimal.NewFromFloat(320),
			decimal.NewFromFloat(19200), // $320 * 60 months
			decimal.NewFromFloat(3840),  // 12 months already paid
			now.AddDate(0, -12, 5),      // Started 1 year ago
			now.AddDate(0, 48, 5),       // Ends in 48 months
			"mdi:car", "#4D96FF",
		))
	}

	// Regular transactions for the last 3 months
	regularTransactions := getRegularTransactions(profileID, categoryMap, userNumber)
	scenarios = append(scenarios, regularTransactions...)

	return scenarios
}

func createMonthlyTransaction(profileID uint, name, transactionType string, categoryID uint, amount decimal.Decimal, icon, color string, startDate time.Time) dto.TransactionCreationParams {
	isRecurrent := true
	frequency := "monthly"
	hasEndDate := false
	isActive := true

	return dto.TransactionCreationParams{
		ProfileID:    profileID,
		Name:         name,
		Type:         transactionType,
		Date:         startDate,
		CurrencyCode: "USD",
		Icon:         icon,
		Color:        color,
		CategoriesTransaction: map[uint]decimal.Decimal{
			categoryID: amount,
		},
		IsRecurrent: &isRecurrent,
		Frequency:   &frequency,
		HasEndDate:  &hasEndDate,
		IsActive:    &isActive,
	}
}

func createInstallmentTransaction(profileID uint, name string, categoryID uint, monthlyAmount, totalAmount, paidAmount decimal.Decimal, startDate, endDate time.Time, icon, color string) dto.TransactionCreationParams {
	isRecurrent := true
	frequency := "monthly"
	hasEndDate := true
	isActive := true

	return dto.TransactionCreationParams{
		ProfileID:    profileID,
		Name:         name,
		Type:         "expense",
		Date:         startDate,
		CurrencyCode: "USD",
		Icon:         icon,
		Color:        color,
		CategoriesTransaction: map[uint]decimal.Decimal{
			categoryID: monthlyAmount,
		},
		IsRecurrent:          &isRecurrent,
		Frequency:            &frequency,
		HasEndDate:           &hasEndDate,
		EndDate:              &endDate,
		IsActive:             &isActive,
		TotalAmountToPay:     &totalAmount,
		AmountPaidPreviously: &paidAmount,
	}
}

func getRegularTransactions(profileID uint, categoryMap map[string]uint, userNumber int) []dto.TransactionCreationParams {
	var transactions []dto.TransactionCreationParams
	now := time.Now()

	// Generate transactions for the last 3 months
	for month := 0; month < 3; month++ {
		baseDate := now.AddDate(0, -month, 0)

		// Groceries (weekly)
		for week := 0; week < 4; week++ {
			transactionDate := baseDate.AddDate(0, 0, -week*7-rand.Intn(7))
			amount := decimal.NewFromFloat(75 + rand.Float64()*50) // $75-125

			transactions = append(transactions, dto.TransactionCreationParams{
				ProfileID:    profileID,
				Name:         getRandomGroceryStore(),
				Type:         "expense",
				Date:         transactionDate,
				CurrencyCode: "USD",
				Icon:         "mdi:cart",
				Color:        "#FF6B6B",
				CategoriesTransaction: map[uint]decimal.Decimal{
					categoryMap["Food"]: amount,
				},
			})
		}

		// Gas/Transport (bi-weekly)
		for i := 0; i < 2; i++ {
			transactionDate := baseDate.AddDate(0, 0, -i*14-rand.Intn(7))
			amount := decimal.NewFromFloat(40 + rand.Float64()*30) // $40-70

			transactions = append(transactions, dto.TransactionCreationParams{
				ProfileID:    profileID,
				Name:         "Gas Station",
				Type:         "expense",
				Date:         transactionDate,
				CurrencyCode: "USD",
				Icon:         "mdi:gas-station",
				Color:        "#4D96FF",
				CategoriesTransaction: map[uint]decimal.Decimal{
					categoryMap["Transport"]: amount,
				},
			})
		}

		// Utilities (monthly)
		if month < 3 {
			// Electricity
			transactions = append(transactions, dto.TransactionCreationParams{
				ProfileID:    profileID,
				Name:         "Electric Bill",
				Type:         "expense",
				Date:         baseDate.AddDate(0, 0, -5),
				CurrencyCode: "USD",
				Icon:         "mdi:flash",
				Color:        "#FFD93D",
				CategoriesTransaction: map[uint]decimal.Decimal{
					categoryMap["Utilities"]: decimal.NewFromFloat(80 + rand.Float64()*40), // $80-120
				},
			})

			// Internet
			transactions = append(transactions, dto.TransactionCreationParams{
				ProfileID:    profileID,
				Name:         "Internet Bill",
				Type:         "expense",
				Date:         baseDate.AddDate(0, 0, -10),
				CurrencyCode: "USD",
				Icon:         "mdi:wifi",
				Color:        "#845EC2",
				CategoriesTransaction: map[uint]decimal.Decimal{
					categoryMap["Utilities"]: decimal.NewFromFloat(65 + rand.Float64()*25), // $65-90
				},
			})
		}

		// Random entertainment/dining
		for i := 0; i < rand.Intn(6)+2; i++ { // 2-7 entertainment transactions per month
			transactionDate := baseDate.AddDate(0, 0, -rand.Intn(28))

			entertainment := []struct {
				name     string
				category string
				amount   [2]float64 // min, max
				icon     string
				color    string
			}{
				{"Restaurant Dinner", "Food", [2]float64{25, 80}, "mdi:silverware-fork-knife", "#FF6B6B"},
				{"Coffee Shop", "Food", [2]float64{4, 12}, "mdi:coffee", "#8B4513"},
				{"Movie Theater", "Entertainment", [2]float64{12, 25}, "mdi:movie", "#845EC2"},
				{"Uber Ride", "Transport", [2]float64{8, 35}, "mdi:taxi", "#000000"},
				{"Amazon Purchase", "Shopping", [2]float64{15, 120}, "mdi:package-variant", "#FF9900"},
			}

			item := entertainment[rand.Intn(len(entertainment))]
			amount := decimal.NewFromFloat(item.amount[0] + rand.Float64()*(item.amount[1]-item.amount[0]))

			transactions = append(transactions, dto.TransactionCreationParams{
				ProfileID:    profileID,
				Name:         item.name,
				Type:         "expense",
				Date:         transactionDate,
				CurrencyCode: "USD",
				Icon:         item.icon,
				Color:        item.color,
				CategoriesTransaction: map[uint]decimal.Decimal{
					categoryMap[item.category]: amount,
				},
			})
		}
	}

	// Add some income diversity
	if userNumber == 1 {
		// Freelance work (irregular)
		for month := 0; month < 3; month++ {
			if rand.Float32() < 0.6 { // 60% chance each month
				transactionDate := now.AddDate(0, -month, -rand.Intn(28))
				amount := decimal.NewFromFloat(200 + rand.Float64()*800) // $200-1000

				transactions = append(transactions, dto.TransactionCreationParams{
					ProfileID:    profileID,
					Name:         "Freelance Project",
					Type:         "income",
					Date:         transactionDate,
					CurrencyCode: "USD",
					Icon:         "mdi:laptop",
					Color:        "#FF8C00",
					CategoriesTransaction: map[uint]decimal.Decimal{
						categoryMap["Side Income"]: amount,
					},
				})
			}
		}
	}

	return transactions
}

func getRandomGroceryStore() string {
	stores := []string{
		"Walmart Supercenter",
		"Target",
		"Kroger",
		"Safeway",
		"Whole Foods Market",
		"Trader Joe's",
		"Costco Wholesale",
	}
	return stores[rand.Intn(len(stores))]
}

var seedTransactionsCmd = &cobra.Command{
	Use:   "seed-transactions",
	Short: "Seeds the database with realistic transaction data for testing",
	Long: `This command creates realistic transaction data including:
- Monthly salaries (recurring income)
- Subscription services (Netflix, Spotify, etc.)
- Installment payments (phone, car loans)
- Regular expenses (groceries, gas, utilities)
- Entertainment and miscellaneous transactions

It creates data for the first 2 users in the database and generates JWT tokens for testing.`,
	RunE: SeedTransactions,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		_, err := db.Connect()
		return err
	},
}

func init() {
	rootCmd.AddCommand(seedTransactionsCmd)
}
