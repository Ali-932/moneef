package db

import (
	"fmt"
	"gorm.io/gorm"
	"moneef/internal/models"
	"reflect"
)

func MigrateModels(database *gorm.DB) error {
	modelsToMigrate := []interface{}{
		&models.User{},
		&models.UserSettings{},
		&models.Profile{},
		&models.Category{},
		&models.Transaction{},
		&models.TransactionCategory{},
		&models.Pattern{},
		&models.Currency{},
		&models.RecurrenceTemplate{},
		&models.RecurrenceTemplateCategory{},
		&models.Currency{},
		&models.CurrencyExchangeRate{},
	}

	for _, model := range modelsToMigrate {
		if err := database.AutoMigrate(model); err != nil {
			modelName := reflect.TypeOf(model).Elem().Name()
			return fmt.Errorf("failed to migrate %s model: %w", modelName, err)
		}
	}

	return nil
}
