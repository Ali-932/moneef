package engine

import (
	"log"
	"moneef/internal/background"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/models"

	"gorm.io/gorm"
)

const (
	IconSourceAutomatic = "auto"
	IconSourceManual    = "manual"
)

// IconSourceForInput records whether the caller explicitly supplied a value.
// Icon and color are tracked separately so a custom color can coexist with an
// automatically matched merchant icon.
func IconSourceForInput(value string) string {
	if value != "" {
		return IconSourceManual
	}
	return IconSourceAutomatic
}

func ResolveMerchantIcon(transactionID uint) {
	var transaction models.Transaction
	if err := db.DB.Preload("TransactionCategory.Category", models.WithDeleted).First(&transaction, transactionID).Error; err != nil {
		log.Printf("[IconLookup] Transaction %d: %v", transactionID, err)
		return
	}
	if err := resolveTransactionIcon(db.DB, &transaction); err != nil {
		log.Printf("[IconLookup] Transaction %d: %v", transactionID, err)
	}
}

// RefreshStoredTransactionIcons upgrades legacy rows in bounded batches during
// mobile initialization. When the dictionary gained entries, re-evaluate all
// automatic icons too. Explicit choices and financial data remain untouched.
func RefreshStoredTransactionIcons(database *gorm.DB, includeAutomatic bool) error {
	query := database.Where("icon_source = '' OR color_source = ''")
	if includeAutomatic {
		query = query.Or("icon_source = ? OR color_source = ?", IconSourceAutomatic, IconSourceAutomatic)
	}
	var transactions []models.Transaction
	return query.Preload("TransactionCategory.Category", models.WithDeleted).FindInBatches(&transactions, 200, func(tx *gorm.DB, _ int) error {
		return database.Transaction(func(batch *gorm.DB) error {
			for i := range transactions {
				if err := resolveTransactionIcon(batch, &transactions[i]); err != nil {
					return err
				}
			}
			return nil
		})
	}).Error
}

func resolveTransactionIcon(database *gorm.DB, transaction *models.Transaction) error {
	iconSource, colorSource := transaction.IconSource, transaction.ColorSource
	// Old releases saved category fallbacks without recording their origin.
	// Only infer inheritance when both saved values match the same category;
	// preserve other nonempty legacy values as explicit choices.
	inherited := false
	for _, split := range transaction.TransactionCategory {
		if transaction.Icon == split.Category.Icon && transaction.Color == split.Category.Color {
			inherited = true
			break
		}
	}
	if iconSource == "" {
		iconSource = IconSourceForInput(transaction.Icon)
		if inherited {
			iconSource = IconSourceAutomatic
		}
	}
	if colorSource == "" {
		colorSource = IconSourceForInput(transaction.Color)
		if inherited {
			colorSource = IconSourceAutomatic
		}
	}

	icon, color := "", ""
	if iconSource == IconSourceAutomatic || colorSource == IconSourceAutomatic {
		fields := []string{}
		if transaction.MerchantName != nil {
			fields = append(fields, *transaction.MerchantName)
		}
		fields = append(fields, transaction.Name)
		if transaction.Notes != nil {
			fields = append(fields, *transaction.Notes)
		}
		found := false
		for _, field := range fields {
			icon, color, found = iconlookup.Lookup(field)
			if found {
				break
			}
		}
		if !found && len(transaction.TransactionCategory) > 0 {
			category := transaction.TransactionCategory[0].Category
			icon, color = category.Icon, category.Color
		}
	}

	updates := map[string]interface{}{}
	if iconSource != transaction.IconSource {
		updates["icon_source"] = iconSource
	}
	if colorSource != transaction.ColorSource {
		updates["color_source"] = colorSource
	}
	if iconSource == IconSourceAutomatic && icon != transaction.Icon {
		updates["icon"] = icon
	}
	if colorSource == IconSourceAutomatic && color != transaction.Color {
		updates["color"] = color
	}
	if len(updates) == 0 {
		return nil
	}
	// Enrichment does not constitute a user edit of the transaction.
	return database.Model(&models.Transaction{}).Where("id = ?", transaction.ID).UpdateColumns(updates).Error
}

func ResolveMerchantIconAsync(transactionID uint) {
	background.Run(func() { ResolveMerchantIcon(transactionID) })
}

func ResolveCategoryIcon(categoryID uint) {
	var category models.Category
	if err := db.DB.First(&category, categoryID).Error; err != nil {
		log.Printf("⚠️ [ENGINE] Category %d not found for icon resolution: %v", categoryID, err)
		return
	}

	if category.Icon != "" && category.Color != "" {
		return
	}

	updates := map[string]interface{}{}

	icon, color, found := iconlookup.Lookup(category.Name)
	if found {
		if category.Icon == "" {
			updates["icon"] = icon
		}
		if category.Color == "" {
			updates["color"] = color
		}
		log.Printf("✅ [ENGINE] Category %d matched keyword → icon=%s color=%s", categoryID, icon, color)
	} else {
		if category.Icon == "" {
			updates["icon"] = "mdi:folder"
		}
		if category.Color == "" {
			updates["color"] = "#6B5CE7"
		}
		log.Printf("✅ [ENGINE] Category %d used default icon/color", categoryID)
	}

	if len(updates) > 0 {
		if err := db.DB.Model(&models.Category{}).Where("id = ?", categoryID).Updates(updates).Error; err != nil {
			log.Printf("❌ [ENGINE] Failed to update category %d icon/color: %v", categoryID, err)
		}
	}
}

func ResolveCategoryIconAsync(categoryID uint) {
	background.Run(func() { ResolveCategoryIcon(categoryID) })
}
