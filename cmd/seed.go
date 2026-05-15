/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/utils"

	"github.com/spf13/cobra"
	"gorm.io/gorm"
)

func Seed(cmd *cobra.Command, args []string) error {
	log.Printf("Starting database seeding...")
	database := db.DB
	if err := seedCategories(database); err != nil {
		return fmt.Errorf("seeding categories: %w", err)
	}
	if err := seedCurrencies(database); err != nil {
		return fmt.Errorf("seeding currencies: %w", err)
	}
	if err := seedUsersAndProfiles(database, cmd); err != nil {
		return fmt.Errorf("seeding users and profiles: %w", err)
	}
	log.Printf("Database seeding completed successfully!")
	return nil
}

func seedUsersAndProfiles(database *gorm.DB, cmd *cobra.Command) error {
	log.Printf("Seeding users and profiles...")

	type userSeed struct {
		Email     string
		Password  string
		FirstName string
		LastName  string
	}

	userPassword, _ := cmd.Flags().GetString("password")
	if userPassword == "" {
		b := make([]byte, 16)
		rand.New(rand.NewSource(time.Now().UnixNano())).Read(b)
		userPassword = fmt.Sprintf("%x", b)
		log.Printf("Generated password: %s", userPassword)
	}

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
		}
		if err := database.Create(&user).Error; err != nil {
			return fmt.Errorf("creating user %s: %w", u.Email, err)
		}

		log.Printf("Created user: %s", u.Email)

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
			Language:              "en",
			IsNotificationEnabled: true,
			IsDarkMode:            rand.New(rand.NewSource(time.Now().UnixNano())).Intn(2) == 0,
		}
		if err := database.Create(&settings).Error; err != nil {
			return fmt.Errorf("creating user settings for %s: %w", u.Email, err)
		}
	}
	return nil
}

func seedCategories(database *gorm.DB) error {
	log.Printf("Seeding categories...")
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
		{Name: "Food", Type: tExpense, Icon: "mdi:food", Color: "#FF6B6B"},
		{Name: "Transport", Type: tExpense, Icon: "mdi:car", Color: "#4D96FF"},
		{Name: "Utilities", Type: tExpense, Icon: "mdi:flash", Color: "#FFD93D"},
		{Name: "Entertainment", Type: tExpense, Icon: "mdi:movie", Color: "#845EC2"},
		{Name: "Shopping", Type: tExpense, Icon: "mdi:shopping", Color: "#FF9671"},
		{Name: "Healthcare", Type: tExpense, Icon: "mdi:hospital-box", Color: "#00C9A7"},
		{Name: "Housing", Type: tExpense, Icon: "mdi:home", Color: "#8B4513"},
		{Name: "Personal Care", Type: tExpense, Icon: "mdi:spa", Color: "#FF69B4"},
		{Name: "Education", Type: tExpense, Icon: "mdi:school", Color: "#20B2AA"},
		{Name: "Insurance", Type: tExpense, Icon: "mdi:shield-check", Color: "#6495ED"},
		{Name: "Travel", Type: tExpense, Icon: "mdi:airplane", Color: "#32CD32"},
		{Name: "Business", Type: tExpense, Icon: "mdi:briefcase", Color: "#708090"},
		{Name: "Savings", Type: tExpense, Icon: "mdi:piggy-bank", Color: "#228B22"},
		{Name: "Debt", Type: tExpense, Icon: "mdi:credit-card", Color: "#DC143C"},
		{Name: "Gifts", Type: tExpense, Icon: "mdi:gift", Color: "#DA70D6"},

		// Income Categories
		{Name: "Salary", Type: tIncome, Icon: "mdi:wallet", Color: "#00C9A7"},
		{Name: "Business", Type: tIncome, Icon: "mdi:briefcase", Color: "#2BB673"},
		{Name: "Investments", Type: tIncome, Icon: "mdi:trending-up", Color: "#228B22"},
		{Name: "Benefits", Type: tIncome, Icon: "mdi:bank", Color: "#4682B4"},
		{Name: "Side Income", Type: tIncome, Icon: "mdi:hammer-wrench", Color: "#FF8C00"},
		{Name: "Gifts", Type: tIncome, Icon: "mdi:gift", Color: "#C34A36"},
	}

	for _, d := range defaults {
		var existing models.Category
		err := database.Where("name = ? AND profile_id IS NULL", d.Name).First(&existing).Error
		if err == nil {
			// Update existing category with new icon/color
			existing.Icon = d.Icon
			existing.Color = d.Color
			if err := database.Save(&existing).Error; err != nil {
				return err
			}
			continue
		}
		if err != gorm.ErrRecordNotFound {
			return err
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
	log.Printf("Seeding currencies...")

	for _, d := range config.Currencies {
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

var seedCmd = &cobra.Command{
	Use:   "seed",
	Short: "This seeds the database with initial data",
	Long:  ``,
	RunE:  Seed,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		_, err := db.Connect()
		return err
	},
}

func init() {
	seedCmd.Flags().String("password", "", "Password for seeded users (default: auto-generated)")
	rootCmd.AddCommand(seedCmd)
}
